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
import '../../../onboarding_widgets.dart';

class AddVenuePhotoListViewScreen extends StatefulWidget {
  final List<XFile> images;
  final http.Client? client;
  final Future<String>? activityIdFuture;
  final Future<void>? uploadFuture;
  final ValueChanged<List<XFile>>? onPhotosChanged;
  const AddVenuePhotoListViewScreen({super.key, required this.images, this.onPhotosChanged, this.client, this.activityIdFuture, this.uploadFuture});

  @override
  State<AddVenuePhotoListViewScreen> createState() => _State();
}

class _State extends State<AddVenuePhotoListViewScreen> {
  late List<XFile> _images;
  int? _coverIndex = 0; // by default first image is cover
  String activityName = "Activity";
  bool _isUploading = false;
  late final Future<_ActivitySetup> _setup;


  @override
  void initState() {
    super.initState();
    getData();
    _images = List.from(widget.images); // copy images
    _setup = _setupFuture();
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
    setState(() {
      //_coverIndex = index;
      _coverIndex = 0; // new cover will always be at top

      // Remove selected image from current position
      final selectedImage = _images.removeAt(index);

      // Insert selected image at first position
      _images.insert(0, selectedImage);

      // Update cover index
      _coverIndex = 0;
    });
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));
  }

  void deletePhoto(int index) {
    setState(() {
      _images.removeAt(index);

      if (_coverIndex == index) {
        _coverIndex = _images.isNotEmpty ? 0 : null;
      } else if (_coverIndex != null && index < _coverIndex!) {
        _coverIndex = _coverIndex! - 1;
      }
    });
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));

    if (_images.isEmpty)
    {
      CommonUtilities.callVenueImagesClear = "yes";
      Navigator.pop(context);
    }
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

                                  getText(),

                                  getSubText(),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Container(
                                margin: EdgeInsets.fromLTRB(5, 0, 5, 0),
                                child: _images.isEmpty
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

                                              // "Set as Cover Photo" button
                                             /* if (_coverIndex != index)
                                                TextButton(
                                                  onPressed: () => _setAsCover(index),
                                                  child: const Text(
                                                    "Set as Cover Photo",
                                                    style: TextStyle(color: Colors.purple),
                                                  ),
                                                )
                                              else
                                                const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text(
                                                    "Currently Cover Photo",
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),*/
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

                                        // Delete button
                                        /*Positioned(
                                          top: 15,
                                          right: 15,
                                          child: InkWell(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              padding: const EdgeInsets.all(6),
                                              child: Image.asset('assets/ic_three_dot.png')
                                            ),
                                          ),
                                        ),*/

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
                                              final setup = await _setup;
                                              await widget.uploadFuture!;
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
    final activityId = await widget.activityIdFuture!;
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


