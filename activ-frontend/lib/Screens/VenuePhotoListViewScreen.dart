import 'dart:convert';
import 'dart:typed_data';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import 'CategoryQuestionsScreen.dart';
import 'CommonCode.dart';
import '../Style/app_colors.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import '../api_calling/progress_bar/progress_bar.dart';

class VenuePhotoListViewScreen extends StatefulWidget {
  static List<Uint8List> cachedImageBytes = [];

  final List<XFile> images;
  final List<Uint8List> imageBytes;
  final Map<String, dynamic> currentCategory;
  final List<Map<String, dynamic>> remainingCategories;
  final int categoryIndex;
  final int totalCategories;
  final List<Map<String, dynamic>> accumulatedTimings;

  const VenuePhotoListViewScreen({
    super.key,
    required this.images,
    required this.imageBytes,
    this.currentCategory = const {},
    this.remainingCategories = const [],
    this.categoryIndex = 1,
    this.totalCategories = 1,
    this.accumulatedTimings = const [],
  });

  @override
  State<VenuePhotoListViewScreen> createState() => _State();
}

class _State extends State<VenuePhotoListViewScreen> {
  late List<XFile> _images;
  late List<Uint8List> _imageBytes;
  int? _coverIndex = 0; // by default first image is cover
  int currentStep = 7;
  final int totalSteps = 10;

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

      _images.insert(0, selectedImage);
      _imageBytes.insert(0, selectedBytes);

      _coverIndex = 0;
    });
  }

  void deletePhoto(int index) {
    setState(() {
      _images.removeAt(index);
      _imageBytes.removeAt(index);

      if (_coverIndex == index) {
        _coverIndex = _images.isNotEmpty ? 0 : null;
      } else if (_coverIndex != null && index < _coverIndex!) {
        _coverIndex = _coverIndex! - 1;
      }
    });

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
                  fontFamily: 'FontMedium',
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
                fontFamily: 'FontMedium',
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
                                  getActivIcon(),

                                  getStepBar(progress),

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
                                                child: Image.memory(
                                                  _imageBytes[index],
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
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
                                                    fontFamily: 'FontSemiBold',
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
                                            if (_images.isEmpty) return;

                                            ProgressBar().showLoader(context);
                                            try {
                                              final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));
                                              final venueId = checkString(await SharedPreference.readStr("venue_id"));

                                              if (venueId.isEmpty) {
                                                if (mounted) Navigator.of(context).pop();
                                                if (mounted) CommonUtilities.createSnackBar(context, "Venue not found. Please try again.");
                                                return;
                                              }

                                              // Use current category for service name
                                              final String serviceName = (widget.currentCategory['title']?.toString() ?? '').isNotEmpty
                                                  ? widget.currentCategory['title'].toString()
                                                  : 'Activity';

                                              final formData = FormData();
                                              formData.fields.add(MapEntry('serviceName', serviceName));
                                              for (int i = 0; i < _images.length; i++) {
                                                final fileName = _images[i].name.isNotEmpty ? _images[i].name : "image_$i.jpg";
                                                formData.files.add(MapEntry(
                                                  'images',
                                                  MultipartFile.fromBytes(_imageBytes[i], filename: fileName),
                                                ));
                                              }

                                              final dio = Dio();
                                              final response = await dio.post(
                                                "$UPLOAD_SERVICE_IMAGES_URL/$venueId/services/images",
                                                data: formData,
                                                options: Options(
                                                  headers: {'Authorization': 'Bearer $jwtToken'},
                                                  validateStatus: (_) => true,
                                                ),
                                              );

                                              if (!mounted) return;
                                              Navigator.of(context).pop(); // close loader

                                              if (response.statusCode == 201) {
                                                if (widget.categoryIndex == 1) {
                                                  VenuePhotoListViewScreen.cachedImageBytes = List.from(_imageBytes);
                                                } else {
                                                  VenuePhotoListViewScreen.cachedImageBytes = [
                                                    ...VenuePhotoListViewScreen.cachedImageBytes,
                                                    ..._imageBytes,
                                                  ];
                                                }
                                                if (!mounted) return;
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
                                              } else {
                                                final msg = (response.data is Map) ? response.data['message']?.toString() : null;
                                                CommonUtilities.createSnackBar(context, msg ?? "Image upload failed.");
                                              }
                                            } catch (e) {
                                              CommonUtilities.showLog("❌ Image upload failed: $e");
                                              if (mounted) {
                                                Navigator.of(context).pop();
                                                CommonUtilities.createSnackBar(context, "Image upload failed. Please try again.");
                                              }
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

  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.only(top: 10),
        child: SvgPicture.asset("assets/activ_tm.svg",)
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
    return Container(
      margin: EdgeInsets.only(top: 25),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Add some photos of your venue",
        style: TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'FontSemiBold',
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
        "These images will be shown on the Activ venue listing page",
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'FontRegular',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}


