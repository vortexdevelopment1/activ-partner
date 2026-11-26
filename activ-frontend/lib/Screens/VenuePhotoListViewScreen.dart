import 'dart:async';
import 'dart:typed_data';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'CategoryQuestionsScreen.dart';
import 'CommonCode.dart';
import '../Style/app_colors.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'onboarding_widgets.dart';
import '../Utills/session_photo_draft.dart';
import '../Utills/venue_photo_duplicates.dart';

class VenuePhotoListViewScreen extends StatefulWidget {
  static List<Uint8List> cachedImageBytes = [];
  static final Map<String, List<Uint8List>> cachedImagesByCategory = {};
  static final Map<String, int> cachedCoverIndexByCategory = {};
  static WidgetBuilder? returnToReviewBuilder;

  static void cacheSelection(Map<String, dynamic> category,
      List<Uint8List> bytes, int coverIndex) {
    final categoryId = category['id']?.toString() ?? '';
    cachedImagesByCategory[categoryId] = List<Uint8List>.from(bytes);
    cachedCoverIndexByCategory[categoryId] =
        bytes.isEmpty ? 0 : coverIndex.clamp(0, bytes.length - 1);
    cachedImageBytes = [
      for (final photos in cachedImagesByCategory.values) ...photos,
    ];
  }

  final List<XFile> images;
  final List<Uint8List> imageBytes;
  final Map<String, dynamic> currentCategory;
  final List<Map<String, dynamic>> remainingCategories;
  final int categoryIndex;
  final int totalCategories;
  final List<Map<String, dynamic>> accumulatedTimings;
  final int initialCoverIndex;
  final bool replaceOnlyCurrentCategory;
  final void Function(List<XFile>, List<Uint8List>, int)? onPhotosChanged;

  const VenuePhotoListViewScreen({
    super.key,
    required this.images,
    required this.imageBytes,
    this.currentCategory = const {},
    this.remainingCategories = const [],
    this.categoryIndex = 1,
    this.totalCategories = 1,
    this.accumulatedTimings = const [],
    this.initialCoverIndex = 0,
    this.replaceOnlyCurrentCategory = false,
    this.onPhotosChanged,
  });

  @override
  State<VenuePhotoListViewScreen> createState() => _State();
}

class _State extends State<VenuePhotoListViewScreen> {
  late List<XFile> _images;
  late List<Uint8List> _imageBytes;
  late List<String> _imageIds;
  final ImagePicker _picker = ImagePicker();
  int? _coverIndex = 0; // by default first image is cover
  int currentStep = onboardingPhotosStep;
  final int totalSteps = totalSetup;

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

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
    _imageBytes = List.from(widget.imageBytes);
    _imageIds = List.generate(_images.length, (i) => 'venue_img_${i}_${_images[i].path}');
    _coverIndex = _imageBytes.isEmpty
        ? null
        : widget.initialCoverIndex.clamp(0, _imageBytes.length - 1);
  }

  Future<void> _uploadImages(String jwtToken, String venueId) async {
    final serviceName = (widget.currentCategory['name']?.toString() ?? '').isNotEmpty
        ? widget.currentCategory['name'].toString()
        : (widget.currentCategory['title']?.toString() ?? 'Activity');
    final categoryId = widget.currentCategory['id']?.toString() ?? '';
    final formData = FormData()
      ..fields.add(MapEntry('serviceName', serviceName))
      ..fields.add(const MapEntry('replaceImages', 'true'));
    if (categoryId.isNotEmpty) {
      formData.fields.add(MapEntry('categoryId', categoryId));
    }
    for (int i = 0; i < _images.length; i++) {
      final fileName = _images[i].name.isNotEmpty ? _images[i].name : 'image_$i.jpg';
      formData.files.add(MapEntry(
        'images',
        MultipartFile.fromBytes(_imageBytes[i], filename: fileName),
      ));
    }

    final response = await Dio().post(
      '$UPLOAD_SERVICE_IMAGES_URL/$venueId/services/images',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $jwtToken'},
        validateStatus: (_) => true,
      ),
    );

    if (response.statusCode != 201) {
      final message = response.data is Map
          ? response.data['message']?.toString()
          : null;
      throw Exception(message ?? 'Image upload failed.');
    }

    if (widget.categoryIndex == 1 && !widget.replaceOnlyCurrentCategory) {
      VenuePhotoListViewScreen.cachedImagesByCategory.clear();
      VenuePhotoListViewScreen.cachedCoverIndexByCategory.clear();
    }
    VenuePhotoListViewScreen.cacheSelection(
        widget.currentCategory, _imageBytes, _coverIndex ?? 0);
  }


/*void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_coverIndex == index) {
        // if cover photo deleted → make first one as cover
        _coverIndex = 0;
      } else if (index < _coverIndex) {
        // shift cover index if deleted image is before cover
        _coverIndex -= 1;
      }
    });
  }*/


  void setAsCover(int index) {
    setState(() {
      _coverIndex = 0;

      final selectedImage = _images.removeAt(index);
      final selectedBytes = _imageBytes.removeAt(index);
      final selectedId = _imageIds.removeAt(index);

      _images.insert(0, selectedImage);
      _imageBytes.insert(0, selectedBytes);
      _imageIds.insert(0, selectedId);

      _coverIndex = 0;
    });
    _notifyPhotosChanged();
  }

  void _notifyPhotosChanged() {
    VenuePhotoListViewScreen.cacheSelection(
        widget.currentCategory, _imageBytes, _coverIndex ?? 0);
    SessionPhotoDraft.save(widget.currentCategory, _imageBytes, _coverIndex ?? 0);
    widget.onPhotosChanged?.call(
      List<XFile>.unmodifiable(_images),
      List<Uint8List>.unmodifiable(_imageBytes),
      _coverIndex ?? 0,
    );
  }

  void deletePhoto(int index) {
    setState(() {
      _images.removeAt(index);
      _imageBytes.removeAt(index);
      _imageIds.removeAt(index);

      if (_coverIndex == index) {
        _coverIndex = _images.isNotEmpty ? 0 : null;
      } else if (_coverIndex != null && index < _coverIndex!) {
        _coverIndex = _coverIndex! - 1;
      }
    });
    _notifyPhotosChanged();

    if (_images.isEmpty)
    {
      CommonUtilities.callVenueImagesClear = "yes";
      VenuePhotoListViewScreen.returnToReviewBuilder = null;
      Navigator.pop(context);
    }
  }

  Future<void> _addPhotos(Iterable<XFile> picked) async {
    final addedFiles = <XFile>[];
    final addedBytes = <Uint8List>[];
    var duplicateFound = false;
    for (final image in picked) {
      if (_images.length + addedFiles.length >= 12) {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Maximum 12 images allowed.');
        break;
      }
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        CommonUtilities.createSnackBar(
            context, 'Each image must be less than 5 MB.');
        continue;
      }
      if (await containsVenuePhoto(
        bytes,
        selectedPhotos: [..._images, ...addedFiles],
        processedPhotos: [..._imageBytes, ...addedBytes],
      )) {
        duplicateFound = true;
        continue;
      }
      addedFiles.add(image);
      addedBytes.add(bytes);
    }
    if (!mounted) return;
    if (addedFiles.isNotEmpty) {
      setState(() {
        final stamp = DateTime.now().microsecondsSinceEpoch;
        _images.addAll(addedFiles);
        _imageBytes.addAll(addedBytes);
        _imageIds.addAll(List.generate(
            addedFiles.length, (index) => 'added_${stamp}_$index'));
        _coverIndex ??= 0;
      });
      _notifyPhotosChanged();
    }
    if (duplicateFound && mounted) {
      await showDuplicateVenuePhotoDialog(context);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_images.length >= 12) {
      CommonUtilities.createSnackBar(context, 'Maximum 12 images allowed.');
      return;
    }
    await _addPhotos(await _picker.pickMultiImage());
  }

  Future<void> _pickFromCamera() async {
    if (_images.length >= 12) {
      CommonUtilities.createSnackBar(context, 'Maximum 12 images allowed.');
      return;
    }
    final image = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 40);
    if (image != null) await _addPhotos([image]);
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _images.removeAt(oldIndex);
      final bytes = _imageBytes.removeAt(oldIndex);
      final id = _imageIds.removeAt(oldIndex);
      _images.insert(newIndex, item);
      _imageBytes.insert(newIndex, bytes);
      _imageIds.insert(newIndex, id);
      _coverIndex = _images.isNotEmpty ? 0 : null;
    });
    _notifyPhotosChanged();
  }


  void _showCustomMenu(BuildContext context, Offset position, int index) async {
    final screenWidth = MediaQuery.of(context).size.width;
    const rightMargin = 20;
    const topMargin = 17;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, // x position
        position.dy + topMargin,
        screenWidth - position.dx - rightMargin,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        if (_coverIndex != index)
          PopupMenuItem<String>(
            value: 'cover',
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
              child: Text(
                "Set as cover photo",
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'Satoshi',
                  color: AppColors.darkBlack,
                ),
              ),
            ),
          ),

        if (_coverIndex != index)const PopupMenuDivider(height: 0.5),
        PopupMenuItem(
          value: 'delete',
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
            child: Text(
              "Delete photo",
              style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'Satoshi',
                color: AppColors.darkBlack,
              ),
            ),
          ),
        ),
      ],
    );

    if (selected == 'cover') {
      setAsCover(index);
    } else if (selected == 'delete') {
      deletePhoto(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = currentStep / totalSteps;
    return Container(
      child: Stack(
        children: [
          /*To Set Top Header Color*/
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 100,
              color: AppColors.yellowTop,
            ),
          ),
          /*To Set Bottom Header Color*/
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              color: AppColors.white,
            ),
          ),
          SafeArea(
            top: true,
            bottom: true,
            left: false,
            right: false,
            child: Scaffold(
              body: Container(
                decoration: context.getYellowGradient,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;

                    bool isMobile = width < 600;
                    bool isTablet = width >= 600 && width < 1100;

                    double containerWidth =
                    isMobile ? width * 1 : (isTablet ? 500 : 600);

                    return Container(
                      //width: containerWidth,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                              child: Column(
                                children: [
                                  const OnboardingHeader(),

                                  getStepBar(progress),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            getText(),
                                            getSubText(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 25),
                                        child: Material(
                                          color: AppColors.white,
                                          shape: const CircleBorder(),
                                          elevation: 2,
                                          child: IconButton(
                                            key: const ValueKey(
                                                'add-venue-photos'),
                                            tooltip: 'Add photos',
                                            onPressed: _showPickOptions,
                                            icon: const Icon(Icons.add,
                                                color: AppColors.purple,
                                                size: 26),
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 46, height: 46),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                                child: _images.isEmpty
                                    ? const Center(child: Text("No images uploaded"))
                                    : ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  padding: EdgeInsets.zero,
                                  itemCount: _images.length,
                                  onReorder: onReorder,
                                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                    return Material(
                                      elevation: 6,
                                      color: Colors.transparent,
                                      shadowColor: Colors.black26,
                                      borderRadius: BorderRadius.circular(12),
                                      child: child,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    return ReorderableDelayedDragStartListener(
                                      key: ValueKey(_imageIds[index]),
                                      index: index,
                                      child: Stack(
                                        children: [
                                          Card(
                                            margin: const EdgeInsets.all(10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Column(
                                              children: [

                                                AspectRatio(
                                                  aspectRatio: 16/9,
                                                  child: Image.memory(
                                                    _imageBytes[index],
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Cover Photo label
                                          if (_coverIndex == index)
                                            Positioned(
                                              top: 20,
                                              left: 20,
                                              child: Container(
                                                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.darkGray,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppColors.white, width: 1),
                                                ),
                                                child: const Text(
                                                  "Cover Photo",
                                                  style: TextStyle(
                                                      fontSize: AppSize.size_14,
                                                      fontFamily: 'Satoshi',
                                                      color: AppColors.white,
                                                      height: 1
                                                  ),
                                                ),
                                              ),
                                            ),

                                          Positioned(
                                            right: 15,
                                            top: 15,
                                            child: GestureDetector(
                                              onTapDown: (TapDownDetails details) {
                                                _showCustomMenu(context, details.globalPosition, index);
                                              },
                                              child: Container(
                                                  width: 50,
                                                  height: 50,
                                                  padding: const EdgeInsets.all(6),
                                                  child: Image.asset('assets/ic_three_dot.png')
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
                                              onTap: ()
                                              {
                                                VenuePhotoListViewScreen.returnToReviewBuilder = null;
                                                Navigator.pop(context);
                                              },
                                              child: getBackButton(context, "Back", "venuePhoto"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                          onTap: () async {
                                            if (_images.length < 4 || _images.length > 12) {
                                              CommonUtilities.createSnackBar(context,
                                                  'Please upload a minimum of 4 and a maximum of 12 images.');
                                              return;
                                            }
                                            if (_imageBytes.length != _images.length ||
                                                _imageBytes.any((bytes) => bytes.length > 5 * 1024 * 1024)) {
                                              CommonUtilities.createSnackBar(context,
                                                  'Each photo must be 5 MB or smaller. Please select your photos again.');
                                              return;
                                            }

                                            final values = await Future.wait<String?>([
                                              SharedPreference.readStr("jwt_token"),
                                              SharedPreference.readStr("venue_id"),
                                            ]);
                                            final jwtToken = checkString(values[0]);
                                            final venueId = checkString(values[1]);
                                            if (venueId.isEmpty) {
                                              CommonUtilities.createSnackBar(context, "Venue not found. Please try again.");
                                              return;
                                            }

                                            // Start the upload, but do not make navigation wait for the
                                            // multipart request to finish.
                                            unawaited(_uploadImages(jwtToken, venueId).catchError((error) {
                                              CommonUtilities.showLog("❌ Image upload failed: $error");
                                            }));

                                            final reviewBuilder = VenuePhotoListViewScreen.returnToReviewBuilder;
                                            if (reviewBuilder != null) {
                                              VenuePhotoListViewScreen.returnToReviewBuilder = null;
                                              CommonUtilities.NavigateWithPushReplacment(
                                                context,
                                                reviewBuilder(context),
                                              );
                                            } else {
                                              CommonUtilities.NavigateWithPush(
                                                context,
                                                CategoryQuestionsScreen(
                                                  venueId: venueId,
                                                  currentCategory: widget.currentCategory,
                                                  remainingCategories: widget.remainingCategories,
                                                  categoryIndex: widget.categoryIndex,
                                                  totalCategories: widget.totalCategories,
                                                  accumulatedTimings: widget.accumulatedTimings,
                                                ),
                                              );
                                            }
                                          },
                                          child: _images.isNotEmpty
                                              ? getButtonBlack(context, "Next", "venuePhoto")
                                              : getButtonGray(context, "Next", "venuePhoto"),
                                        )

                                        /*InkWell(
                                            onTap: ()
                                            async {
                                              // Extract image paths
                                              List<String> imagePaths = _images.map((e) => e.path).toList();

                                              // Wrap with key
                                              *//*Map<String, dynamic> finalJson = {
                                                "venue_images": imagePaths
                                              };

                                              // Convert to String
                                              String jsonString = jsonEncode(finalJson);

                                              SharedPreference.addStringToSF("venue_images", checkString(jsonString));
                                              String venueImages = checkString(await SharedPreference.readStr("venue_images"));
                                              print("Saved Venue Images => $venueImages");*//*

                                              userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));

                                              await saveVenueImagesToFirestore(
                                                userMobileNumber, // "85-2852-8888"
                                                _images,
                                              );

                                             // CommonUtilities.NavigateWithPush(context, VenueTimingScreen());
                                            },
                                            child: _images.isNotEmpty ? getButtonBlack(context, "Next", "venuePhoto") :
                                            getButtonGray(context, "Next", "venuePhoto")
                                        )*/,
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
              ),
            ),
          )
        ],
      ),
    );
  }


  Widget getStepBar(double progress)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getText()
  {
    final rawTitle =
        (widget.currentCategory['title'] ?? widget.currentCategory['name'])
                ?.toString()
                .trim() ??
            '';
    final heading =
        rawTitle.isNotEmpty ? rawTitle : "Review Your Venue Photos";
    return Container(
      margin: EdgeInsets.only(top: 25),
      alignment: Alignment.centerLeft,
      child: Text(
        heading,
        style: const TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
            height: 1.2
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getSubText()
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 3, 0, 10),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Upload this activity's images",
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'Satoshi',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}


