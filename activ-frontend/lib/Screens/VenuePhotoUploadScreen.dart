import 'dart:convert';
import 'dart:typed_data';

import 'package:activ_app/Utills/common_utilities.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Style/app_size.dart';
import '../Utills/venue_photo_duplicates.dart';
import '../Utills/session_photo_draft.dart';
import 'VenuePhotoListViewScreen.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'StringExtensions.dart';
import 'CommonCode.dart';
import 'onboarding_widgets.dart';

class VenuePhotoUploadScreen extends StatefulWidget {
  final Map<String, dynamic> currentCategory;
  final List<Map<String, dynamic>> remainingCategories;
  final int categoryIndex;
  final int totalCategories;
  final List<Map<String, dynamic>> accumulatedTimings;
  final ImagePicker? imagePicker;
  final List<Uint8List> initialImageBytes;
  final int initialCoverIndex;
  final bool replaceOnlyCurrentCategory;
  final Future<String?>? venueReady;

  const VenuePhotoUploadScreen({
    super.key,
    this.currentCategory = const {},
    this.remainingCategories = const [],
    this.categoryIndex = 1,
    this.totalCategories = 1,
    this.accumulatedTimings = const [],
    this.imagePicker,
    this.initialImageBytes = const [],
    this.initialCoverIndex = 0,
    this.replaceOnlyCurrentCategory = false,
    this.venueReady,
  });

  @override
  State<VenuePhotoUploadScreen> createState() => _VenuePhotoUploadScreenState();
}

class _VenuePhotoUploadScreenState extends State<VenuePhotoUploadScreen> {
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _imageBytes = [];
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();
  String? _photoError;
  int _coverIndex = 0;

  void _showPhotoError(String message) {
    if (!mounted) return;
    setState(() => _photoError = message);
  }

  int currentStep = onboardingPhotosStep;
  final int totalSteps = totalSetup;

  @override
  void initState() {
    super.initState();
    _coverIndex = widget.initialCoverIndex;
    if (widget.initialImageBytes.isNotEmpty) {
      _imageBytes.addAll(widget.initialImageBytes);
      _selectedImages.addAll(List.generate(
        widget.initialImageBytes.length,
        (index) => XFile.fromData(
          widget.initialImageBytes[index],
          name: 'existing_photo_${index + 1}.jpg',
          mimeType: 'image/jpeg',
        ),
      ));
      _coverIndex = _coverIndex.clamp(0, _imageBytes.length - 1);
      _isButtonEnabled =
          _selectedImages.length >= 4 && _selectedImages.length <= 12;
    }
    _restoreSessionPhotos();
    if (widget.initialImageBytes.isEmpty &&
        SessionPhotoDraft.read(widget.currentCategory) == null) {
      _restoreExistingPhotos();
    }
    SessionPhotoDraft.changes.addListener(_restoreSessionPhotos);
  }

  Future<void> _restoreExistingPhotos() async {
    final venueId = checkString(await SharedPreference.readStr('venue_id'));
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    if (venueId.isEmpty || token.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/venues/$venueId/activities/full'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final rawServices = decoded is Map ? decoded['data'] : null;
      final services = rawServices is List
          ? rawServices
          : rawServices is Map
              ? rawServices['items']
              : null;
      if (services is! List) return;

      final categoryId = widget.currentCategory['id']?.toString() ?? '';
      final categoryName =
          (widget.currentCategory['title'] ?? widget.currentCategory['name'])
              ?.toString()
              .toLowerCase();
      final service = services
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .firstWhere(
            (value) =>
                value['categoryId']?.toString() == categoryId ||
                value['name']?.toString().toLowerCase() == categoryName,
            orElse: () => <String, dynamic>{},
          );
      final urls = (service['imageUrls'] as List? ?? [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();
      if (urls.isEmpty || !mounted) return;

      final downloaded = <({String url, Uint8List bytes})>[];
      for (final url in urls) {
        final imageResponse = await http.get(Uri.parse(url));
        if (imageResponse.statusCode == 200 &&
            imageResponse.bodyBytes.isNotEmpty) {
          downloaded.add(
              (url: url, bytes: Uint8List.fromList(imageResponse.bodyBytes)));
        }
      }
      if (downloaded.isEmpty || !mounted) return;

      final coverUrl = service['coverImageUrl']?.toString();
      var coverIndex = downloaded.indexWhere((item) => item.url == coverUrl);
      if (coverIndex < 0) coverIndex = 0;
      final bytes = downloaded.map((item) => item.bytes).toList();
      setState(() {
        _imageBytes
          ..clear()
          ..addAll(bytes);
        _selectedImages
          ..clear()
          ..addAll([
            for (var index = 0; index < bytes.length; index++)
              XFile.fromData(bytes[index],
                  name: 'existing_photo_${index + 1}.jpg',
                  mimeType: 'image/jpeg'),
          ]);
        _coverIndex = coverIndex;
        _isButtonEnabled =
            _selectedImages.length >= 4 && _selectedImages.length <= 12;
      });
      SessionPhotoDraft.save(widget.currentCategory, _imageBytes, _coverIndex);
      if (categoryId.isNotEmpty) {
        VenuePhotoListViewScreen.cachedImagesByCategory[categoryId] =
            List.from(_imageBytes);
        VenuePhotoListViewScreen.cachedCoverIndexByCategory[categoryId] =
            _coverIndex;
      }
    } catch (error) {
      CommonUtilities.showLog(
          'Existing activity photos restore failed: $error');
    }
  }

  void _restoreSessionPhotos() {
    final draft = SessionPhotoDraft.read(widget.currentCategory);
    if (!mounted || draft == null) return;
    setState(() {
      _imageBytes
        ..clear()
        ..addAll(draft.bytes);
      _selectedImages
        ..clear()
        ..addAll([
          for (var i = 0; i < draft.bytes.length; i++)
            XFile.fromData(draft.bytes[i],
                name: 'venue_photo_$i.jpg', mimeType: 'image/jpeg'),
        ]);
      _coverIndex = draft.bytes.isEmpty
          ? 0
          : draft.cover.clamp(0, draft.bytes.length - 1);
      _isButtonEnabled =
          _selectedImages.length >= 4 && _selectedImages.length <= 12;
    });
  }

  @override
  void dispose() {
    SessionPhotoDraft.changes.removeListener(_restoreSessionPhotos);
    super.dispose();
  }

  void nextStep() {
    if (currentStep < totalSteps) {
      setState(() {
        currentStep++;
      });
    }
  }

  void prevStep() {
    if (currentStep > 1) {
      setState(() {
        currentStep--;
      });
    }
  }

  /* Future<void> _pickImages() async {
    if (_selectedImages.length >= 4) {
      */ /*ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can upload maximum 4 images.")),
      );*/ /*
      CommonUtilities.createSnackBar(context, "You can upload maximum 4 images.");
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      if (_selectedImages.length + images.length > 4) {
        CommonUtilities.createSnackBar(context, "Maximum 4 images allowed.");
        return;
      }

      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }*/

  // File Size Validation (5 MB se jyada na ho)
  Future<bool> _isValidFileSize(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      const maxSizeInBytes = 5 * 1024 * 1024; // 5 MB
      return bytes.length <= maxSizeInBytes;
    } catch (_) {
      return true; // allow if size cannot be determined
    }
  }

  Future<XFile?> _cropImage(String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      compressQuality: 40,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: "Crop Image",
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          statusBarColor: Colors.black,
          initAspectRatio: CropAspectRatioPreset.original,
          showCropGrid: true,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: "Crop Image",
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (cropped != null) {
      final xfile = XFile(cropped.path);
      final isValid = await _isValidFileSize(xfile);
      if (!isValid) {
        CommonUtilities.createSnackBar(
            context, "Each image must be less than 5 MB.");
        return null;
      }
      return xfile;
    }
    return null;
  }

  bool _isButtonEnabled = false; // by default false

  Future<void> _continue() async {
    if (!_isButtonEnabled) return;
    if (widget.venueReady != null) {
      try {
        final venueId = await widget.venueReady!;
        if (venueId == null || venueId.isEmpty) {
          throw Exception('Venue was not saved.');
        }
      } catch (_) {
        if (mounted) {
          CommonUtilities.createSnackBar(
              context, 'Could not save venue. Please try again.');
        }
        return;
      }
    }
    SessionPhotoDraft.save(widget.currentCategory, _imageBytes, _coverIndex);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VenuePhotoListViewScreen(
                  images: _selectedImages,
                  imageBytes: _imageBytes,
                  currentCategory: widget.currentCategory,
                  remainingCategories: widget.remainingCategories,
                  categoryIndex: widget.categoryIndex,
                  totalCategories: widget.totalCategories,
                  accumulatedTimings: widget.accumulatedTimings,
                  initialCoverIndex: _coverIndex,
                  replaceOnlyCurrentCategory: widget.replaceOnlyCurrentCategory,
                  onPhotosChanged: _syncReviewedPhotos,
                ))).then((_) {
      if (mounted) refresh();
    });
  }

  void _syncReviewedPhotos(
      List<XFile> images, List<Uint8List> bytes, int coverIndex) {
    if (!mounted) return;
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(images);
      _imageBytes
        ..clear()
        ..addAll(bytes);
      _coverIndex = coverIndex;
      _isButtonEnabled = images.length >= 4 && images.length <= 12;
    });
  }

// Update function to check button status
  void _updateButtonStatus() {
    if (!mounted) return;
    setState(() {
      _isButtonEnabled =
          _selectedImages.length >= 4 && _selectedImages.length <= 12;
    });
    SessionPhotoDraft.save(widget.currentCategory, _imageBytes, _coverIndex);
  }

  Future<void> _pickImages1() async {
    if (_selectedImages.length >= 12) {
      CommonUtilities.createSnackBar(
          context, "You can upload maximum 12 images.");
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      if (_selectedImages.length + images.length > 12) {
        CommonUtilities.createSnackBar(context, "Maximum 12 images allowed.");
        return;
      }

      for (var img in images) {
        final cropped = await _cropImage(img.path);
        if (cropped != null) {
          setState(() {
            _selectedImages.add(cropped);
          });
        }
      }
    }

    _updateButtonStatus(); // ✅ update button state
  }

  Future<void> _pickFromCamera1() async {
    if (_selectedImages.length >= 12) {
      CommonUtilities.createSnackBar(context, "Maximum 12 images allowed.");
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final cropped = await _cropImage(image.path);
      if (cropped != null) {
        setState(() {
          _selectedImages.add(cropped);
        });
      }
    }

    _updateButtonStatus(); // ✅ update button state
  }

  Future<void> _pickImages() async {
    if (mounted) setState(() => _photoError = null);
    if (_selectedImages.length >= 12) {
      _showPhotoError("You can upload maximum 12 images.");
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      var duplicateFound = false;
      for (var img in images) {
        duplicateFound = await _addSelectedPhoto(img) || duplicateFound;
      }
      _updateButtonStatus();
      if (duplicateFound && mounted)
        await showDuplicateVenuePhotoDialog(context);
    }

    _updateButtonStatus(); // ✅ update button state
  }

  Future<void> _pickFromCamera() async {
    if (mounted) setState(() => _photoError = null);
    if (_selectedImages.length >= 12) {
      _showPhotoError("Maximum 12 images allowed.");
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final duplicateFound = await _addSelectedPhoto(image);
      _updateButtonStatus();
      if (duplicateFound && mounted)
        await showDuplicateVenuePhotoDialog(context);
    }

    _updateButtonStatus(); // ✅ update button state
  }

  // Returns true only when the photo was rejected as a duplicate.
  Future<bool> _addSelectedPhoto(XFile image) async {
    try {
      if (await image.length() > 5 * 1024 * 1024) {
        _showPhotoError(
            'Each photo must be 5 MB or smaller. Oversized photos were not added.');
        return false;
      }
      final raw = await image.readAsBytes();
      if (raw.length > 5 * 1024 * 1024) {
        _showPhotoError(
            'Each photo must be 5 MB or smaller. Oversized photos were not added.');
        return false;
      }
      if (await containsVenuePhoto(raw,
          selectedPhotos: _selectedImages, processedPhotos: _imageBytes)) {
        return true;
      }
      if (!mounted) return false;
      if (_selectedImages.length >= 12) {
        _showPhotoError('Maximum 12 images allowed.');
        return false;
      }
      final compressed = await FlutterImageCompress.compressWithList(
        raw,
        quality: 60,
        minWidth: 1280,
        minHeight: 720,
      );
      if (!mounted) return false;
      if (matchesVenuePhoto(compressed, _imageBytes)) return true;
      setState(() {
        _selectedImages.add(image);
        _imageBytes.add(compressed);
      });
      SessionPhotoDraft.save(widget.currentCategory, _imageBytes, _coverIndex);
    } catch (_) {
      _showPhotoError('Unable to add this photo. Please try another image.');
    }
    return false;
  }

// Show Bottom Popup
  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double imageWidth = 120;
    final double imageHeight = 120;

    return OnboardingScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            //width: containerWidth,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        getStepBar(currentStep / totalSteps),
                        getText(),
                        getSubText(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (_photoError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(_photoError!,
                                    style: const TextStyle(
                                        color: AppColors.darkRed,
                                        fontSize: 14)),
                              ),
                            ),

                          // Upload Box
                          Container(
                              margin: const EdgeInsets.fromLTRB(0, 28, 0, 0),
                              child: DottedBorder(
                                color: AppColors.purple,
                                strokeWidth: 1,
                                dashPattern: [4, 4],
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  constraints:
                                      const BoxConstraints(minHeight: 270),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        height: 52,
                                        child: Image.asset('assets/ic_pan.png'),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            0, 12, 0, 0),
                                        child: const Text(
                                          "Drag and drop",
                                          style: TextStyle(
                                              fontSize: AppSize.size_16,
                                              fontFamily: 'Satoshi',
                                              color: AppColors.darkBlack,
                                              height: 1),
                                        ),
                                      ),
                                      // Sub Text
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            0, 8, 0, 0),
                                        child: const Text(
                                          "or browse for photos",
                                          style: TextStyle(
                                              fontSize: AppSize.size_14,
                                              fontFamily: 'Satoshi',
                                              color: AppColors.black1,
                                              height: 1),
                                        ),
                                      ),
                                      // Browser Button to Pick Images
                                      InkWell(
                                        onTap: () {
                                          _showPickOptions();
                                          //_pickImages();
                                        },
                                        child: Container(
                                            width: 160,
                                            height: 38,
                                            margin: const EdgeInsets.fromLTRB(
                                                0, 15, 0, 5),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                topRight: Radius.circular(12),
                                                bottomLeft: Radius.circular(12),
                                                bottomRight:
                                                    Radius.circular(12),
                                              ),
                                              border: Border.all(
                                                  color: AppColors.purple,
                                                  width: 1),
                                              color: AppColors.white,
                                            ),
                                            child: Container(
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  "Browse",
                                                  style: TextStyle(
                                                      fontSize: AppSize.size_16,
                                                      fontFamily: 'Satoshi',
                                                      color: AppColors.purple,
                                                      height: 1),
                                                ))),
                                      ),

                                      Container(
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.fromLTRB(
                                            0, 8, 0, 0),
                                        child: const Text(
                                          "Please upload a minimum of 4 clear wide-angle photos in PNG or JPG formats up-to 5 MB",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: AppSize.size_14,
                                              fontFamily: 'Satoshi',
                                              color: AppColors.black1,
                                              height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),

                          Visibility(
                            visible: _selectedImages.isNotEmpty,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                              child: const Text(
                                "Please scroll to view all selected images.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: AppSize.size_12,
                                    fontFamily: 'Satoshi',
                                    color: AppColors.darkBlack,
                                    height: 1),
                              ),
                            ),
                          ),

                          if (_selectedImages.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.fromLTRB(0, 10, 0, 15),
                              height: imageHeight,
                              child: SizedBox(
                                width: imageWidth * 2.5,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.only(
                                          right: 8), // spacing between images
                                      width:
                                          imageWidth, // ✅ fixed width for each image
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.memory(
                                              _imageBytes[index],
                                              fit: BoxFit.cover,
                                              width: imageWidth,
                                              height: imageHeight,
                                            ),
                                          ),
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _selectedImages
                                                      .removeAt(index);
                                                  _imageBytes.removeAt(index);
                                                  if (_coverIndex == index) {
                                                    _coverIndex = 0;
                                                  } else if (index <
                                                      _coverIndex) {
                                                    _coverIndex -= 1;
                                                  }
                                                });
                                                _updateButtonStatus();
                                              },
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: const Icon(Icons.close,
                                                    size: 18,
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Top Progress

                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        bottomBarShadow(),
                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          15, 12, 8, 14),
                                      child: OnboardingButton(
                                          label: 'Back',
                                          outlined: true,
                                          fontSize: 18,
                                          borderRadius: 12,
                                          onPressed: () =>
                                              Navigator.pop(context)),
                                    ))),
                            Expanded(
                              flex: 7,
                              child: InkWell(
                                onTap: _isButtonEnabled ? _continue : null,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 12, 15, 14),
                                  child: OnboardingButton(
                                      label: 'Next',
                                      borderRadius: 12,
                                      disabledBackgroundColor:
                                          AppColors.darkGray,
                                      disabledForegroundColor:
                                          AppColors.lightGray,
                                      onPressed:
                                          _isButtonEnabled ? _continue : null),
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget getStepBar(double progress) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getText() {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Add some photos of your venue',
        style: TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
            height: 1.2),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getSubText() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: const Text(
        'These images will be shown on the Activ venue listing page',
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'Satoshi',
            color: AppColors.black1,
            height: 1.4),
        textAlign: TextAlign.left,
      ),
    );
  }

  void refresh() {
    if (CommonUtilities.callVenueImagesClear == "yes") {
      CommonUtilities.callVenueImagesClear = "";
      _selectedImages.clear();
      _imageBytes.clear();
      _isButtonEnabled = false;
      setState(() {});
    } else {}
  }
}

/*class NextScreen extends StatefulWidget {
  final List<XFile> images;
  const NextScreen({super.key, required this.images});

  @override
  State<NextScreen> createState() => _NextScreenState();
}

class _NextScreenState extends State<NextScreen> {
  late List<XFile> _images;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images); // copy list
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Uploaded Images")),
      body: _images.isEmpty
          ? const Center(child: Text("No images uploaded"))
          : ListView.builder(
        itemCount: _images.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Card(
                margin: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(_images[index].path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                ),
              ),

              // Cover Photo text only on first image
              if (index == 0)
                Positioned(
                  top: 15,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Cover Photo",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

              // Delete button on all images
              Positioned(
                top: 15,
                right: 20,
                child: InkWell(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}*/
