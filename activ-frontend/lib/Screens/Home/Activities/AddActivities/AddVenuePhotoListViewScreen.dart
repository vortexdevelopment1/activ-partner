import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../../api_calling/api_constant.dart';
import '../../../../api_calling/activity_photo_upload.dart';
import '../../../CommonCode.dart';
import 'AddSelectedVenueFormScreen.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../../Utills/activity_image_draft_store.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import '../../../../Utills/venue_photo_duplicates.dart';
import '../../../onboarding_widgets.dart';

class AddVenuePhotoListViewScreen extends StatefulWidget {
  final List<XFile> images;
  final http.Client? client;
  final Future<String>? activityIdFuture;
  final String? activityId;
  final Future<void>? uploadFuture;
  final ValueChanged<List<XFile>>? onPhotosChanged;
  final ImagePicker? imagePicker;
  const AddVenuePhotoListViewScreen({super.key, required this.images, this.onPhotosChanged, this.client, this.activityIdFuture, this.activityId, this.uploadFuture, this.imagePicker});

  @override
  State<AddVenuePhotoListViewScreen> createState() => _State();
}

class _State extends State<AddVenuePhotoListViewScreen> {
  late List<XFile> _images;
  late List<String> _imageIds;
  int? _coverIndex = 0; // by default first image is cover
  String activityName = "Activity";
  bool _isUploading = false;
  bool _photosChanged = false;
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();


  @override
  void initState() {
    super.initState();
    getData();
    _images = List.from(widget.images); // copy images
    _imageIds = List.generate(_images.length, (i) => 'img_${i}_${_images[i].path}');
    _restorePersistedImages();
    _recordCheckpoint();
  }

  Future<void> _recordCheckpoint() async {
    final id = widget.activityId ?? await widget.activityIdFuture;
    if (id != null && id.isNotEmpty && !ActivityFlowCheckpoint.restoring) {
      await ActivityFlowCheckpoint.save(activityId: id, step: 'photoReview');
    }
  }

  Future<void> _restorePersistedImages() async {
    final id = widget.activityId ?? await widget.activityIdFuture;
    if (id == null || id.isEmpty) return;
    final saved = await ActivityImageDraftStore.read(id);
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _images = saved;
        _imageIds = List.generate(_images.length, (i) => 'restored_${i}_${_images[i].path}');
      });
    }
  }

  Future<void> _persistImages() async {
    final id = widget.activityId ?? await widget.activityIdFuture;
    if (id != null && id.isNotEmpty) {
      await ActivityImageDraftStore.save(id, _images);
    }
  }

  getData() async
  {
    final raw = checkString(await SharedPreference.readStr("operate_value"));
    if (raw.isNotEmpty) {
      try {
        activityName = checkString(jsonDecode(raw)["title"]);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void setAsCover(int index) {
    if (_isUploading) return;
    setState(() {
      //_coverIndex = index;
      _coverIndex = 0; // new cover will always be at top

      // Remove selected image from current position
      final selectedImage = _images.removeAt(index);
      final selectedId = _imageIds.removeAt(index);

      // Insert selected image at first position
      _images.insert(0, selectedImage);
      _imageIds.insert(0, selectedId);

      // Update cover index
      _coverIndex = 0;
      _photosChanged = true;
    });
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));
    _persistImages();
  }

  void deletePhoto(int index) {
    if (_isUploading) return;
    setState(() {
      _images.removeAt(index);
      _imageIds.removeAt(index);
      _photosChanged = true;

      if (_coverIndex == index) {
        _coverIndex = _images.isNotEmpty ? 0 : null;
      } else if (_coverIndex != null && index < _coverIndex!) {
        _coverIndex = _coverIndex! - 1;
      }
    });
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));
    _persistImages();

    if (_images.isEmpty)
    {
      CommonUtilities.callVenueImagesClear = "yes";
      Navigator.pop(context);
    }
  }

  void onReorder(int oldIndex, int newIndex) {
    if (_isUploading) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _images.removeAt(oldIndex);
      final id = _imageIds.removeAt(oldIndex);
      _images.insert(newIndex, item);
      _imageIds.insert(newIndex, id);
      _coverIndex = _images.isNotEmpty ? 0 : null;
      _photosChanged = true;
    });
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));
    _persistImages();
  }

  Future<void> _addPhotos(Iterable<XFile> picked) async {
    if (_isUploading) return;
    final additions = <XFile>[];
    var duplicateFound = false;
    for (final image in picked) {
      if (_images.length + additions.length >= 12) {
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
      if (await containsVenuePhoto(bytes,
          selectedPhotos: [..._images, ...additions])) {
        duplicateFound = true;
        continue;
      }
      additions.add(image);
    }
    if (!mounted) return;
    if (additions.isNotEmpty) {
      setState(() {
        _images.addAll(additions);
        _imageIds.addAll(List.generate(additions.length,
            (index) => 'added_${DateTime.now().microsecondsSinceEpoch}_$index'));
        _photosChanged = true;
      });
      widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));
      await _persistImages();
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
    if (_isUploading) return;
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

                                  getStepBarCount(3 / 6, 3, 6),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            getText(),
                                            getSubText(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Material(
                                          color: AppColors.white,
                                          shape: const CircleBorder(),
                                          elevation: 2,
                                          child: IconButton(
                                            key: const ValueKey('add-activity-photos'),
                                            tooltip: 'Add photos',
                                            onPressed: _isUploading ? null : _showPickOptions,
                                            icon: const Icon(Icons.add,
                                                color: AppColors.purple, size: 26),
                                            constraints: const BoxConstraints.tightFor(
                                                width: 46, height: 46),
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Long press a photo to reorder. The first photo is the cover.',
                                      style: TextStyle(fontFamily: 'Satoshi', fontSize: 13, color: AppColors.black1),
                                    ),
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
                                    return KeyedSubtree(
                                      key: ValueKey(_imageIds[index]),
                                      child: Stack(
                                        children: [
                                          ReorderableDelayedDragStartListener(
                                            index: index,
                                            enabled: !_isUploading,
                                            child: Card(
                                              margin: const EdgeInsets.all(10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Column(
                                                children: [

                                                  AspectRatio(
                                                    aspectRatio: 16/9,
                                                    child: kIsWeb
                                                        ? Image.network(
                                                            _images[index].path,
                                                            fit: BoxFit.cover,
                                                            width: double.infinity,
                                                            height: 200,
                                                          )
                                                        : Image.file(
                                                            File(_images[index].path),
                                                            fit: BoxFit.cover,
                                                            width: double.infinity,
                                                            height: 200,
                                                          ),
                                                  ),
                                                ],
                                              ),
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
                                                Navigator.pop(context);
                                              },
                                              child: getBackButton(context, "Back", "venuePhoto"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                          onTap: () async {
                                            if (_isUploading) return;
                                            if (_images.length < 4 || _images.length > 12) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Please select between 4 and 12 images.')),
                                              );
                                              return;
                                            }

                                            setState(() => _isUploading = true);

                                            try {
                                              final setup = await _setupFuture();
                                              if (widget.uploadFuture != null) {
                                                await widget.uploadFuture!;
                                              }
                                              if (_photosChanged) {
                                                await _replaceUploadedImages(setup.id);
                                              }
                                              if (!context.mounted) return;
                                              CommonUtilities.NavigateWithPush(
                                                context,
                                                AddSelectedVenueFormScreen(
                                                  activityId: setup.id,
                                                  initialActivity: setup.activity,
                                                  initialQuestions: setup.questions,
                                                  client: widget.client,
                                                ),
                                              );
                                            } catch (error) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(error.toString())),
                                              );
                                            } finally {
                                              if (mounted) setState(() => _isUploading = false);
                                            }
                                          },
                                          child: _images.length >= 4 && _images.length <= 12 && !_isUploading
                                              ? getButtonBlack(context, "Next", "venuePhoto")
                                              : getButtonGray(context, "Next", "venuePhoto"),
                                        )
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

  Future<_ActivitySetup> _setupFuture() async {
    final activityId = widget.activityId ?? await widget.activityIdFuture;
    if (activityId == null || activityId.isEmpty) {
      throw const ActivitySetupException('This activity is missing its ID. Reopen it from Activities.');
    }
    final api = ActivitySetupApi(client: widget.client);
    try {
      final results = await Future.wait<dynamic>([
        api.activity(activityId),
        api.questions(activityId),
      ]);
      return _ActivitySetup(
        id: activityId,
        activity: results[0] as Map<String, dynamic>,
        questions: results[1] as List<Map<String, dynamic>>,
      );
    } finally {
      api.dispose();
    }
  }

  Future<void> _replaceUploadedImages(String activityId) async {
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    final client = widget.client ?? http.Client();
    try {
      await ActivityPhotoUploader(client: client, baseUrl: BASE_URL)
          .uploadImages(
        token: token,
        serviceId: activityId,
        images: List<XFile>.of(_images),
      );
      _photosChanged = false;
    } finally {
      if (widget.client == null) client.close();
    }
  }

  Future<String> _uploadActivityImagesToBackend(List<XFile> images) async {
    final venueId = checkString(await SharedPreference.readStr('venue_id'));
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    final raw = checkString(await SharedPreference.readStr('operate_value'));
    Map<String, dynamic> category = {};
    try {
      category = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      throw const ActivityUploadException('Please select an activity again.');
    }
    final client = widget.client ?? http.Client();
    try {
      return await ActivityPhotoUploader(client: client, baseUrl: BASE_URL).upload(
        token: token, venueId: venueId, category: category, images: List.of(images),
      );
    } finally {
      if (widget.client == null) client.close();
    }
  }

  Future<String> _prepareActivity() async {
    final venueId = checkString(await SharedPreference.readStr('venue_id'));
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    final raw = checkString(await SharedPreference.readStr('operate_value'));
    Map<String, dynamic> category = {};
    try {
      category = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      throw const ActivityUploadException('Please select an activity again.');
    }
    final client = widget.client ?? http.Client();
    final uploader = ActivityPhotoUploader(client: client, baseUrl: BASE_URL);
    final serviceId = await uploader.createActivity(
      token: token,
      venueId: venueId,
      category: category,
    );
    if (widget.client == null) client.close();
    return serviceId;
  }

  Future<void> _uploadImagesInBackground(
      String serviceId, List<XFile> images) async {
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    final client = widget.client ?? http.Client();
    try {
      await ActivityPhotoUploader(client: client, baseUrl: BASE_URL).uploadImages(
        token: token,
        serviceId: serviceId,
        images: List.of(images),
      );
    } catch (error) {
      CommonUtilities.showLog('Background image upload failed: $error');
    } finally {
      if (widget.client == null) client.close();
    }
  }

  Widget getText()
  {
    return Container(
      margin: EdgeInsets.only(top: 5),
      alignment: Alignment.centerLeft,
      child: Text(
        activityName,
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
      margin: EdgeInsets.fromLTRB(0, 10, 0, 10),
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

class _ActivitySetup {
  const _ActivitySetup({required this.id, required this.activity, required this.questions});
  final String id;
  final Map<String, dynamic> activity;
  final List<Map<String, dynamic>> questions;
}


