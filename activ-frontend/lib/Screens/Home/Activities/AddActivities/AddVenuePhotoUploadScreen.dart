import 'dart:io';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../CommonCode.dart';
import 'AddVenuePhotoListViewScreen.dart';

class AddVenuePhotoUploadScreen extends StatefulWidget {
  const AddVenuePhotoUploadScreen({super.key});

  @override
  State<AddVenuePhotoUploadScreen> createState() => _State();
}

class _State extends State<AddVenuePhotoUploadScreen> {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // File Size Validation (5 MB se jyada na ho)
  Future<bool> _isValidFileSize(String path) async {
    final file = File(path);
    final sizeInBytes = await file.length();
    final sizeInMB = (sizeInBytes / (1024 * 1024)).toStringAsFixed(2);

    const maxSizeInBytes = 5 * 1024 * 1024; // 5 MB
 //   CommonUtilities.createSnackBar(context, "Image Size : " +sizeInMB.toString());
    return sizeInBytes <= maxSizeInBytes;
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
      final isValid = await _isValidFileSize(cropped.path);
      if (!isValid) {
        CommonUtilities.createSnackBar(context, "Each image must be less than 5 MB.");
        return null;
      }
      return XFile(cropped.path);
    }
    return null;
  }

  bool _isButtonEnabled = false; // by default false

// Update function to check button status
  void _updateButtonStatus() {
    setState(() {
      _isButtonEnabled = _selectedImages.length >= 4 && _selectedImages.length <= 12;
    });
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 12) {
      CommonUtilities.createSnackBar(context, "You can upload maximum 12 images.");
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      if (_selectedImages.length + images.length > 12) {
        CommonUtilities.createSnackBar(context, "Maximum 12 images allowed.");
        return;
      }

      for (var img in images) {
        final isValid = await _isValidFileSize(img.path);

        if (!isValid) {
          CommonUtilities.createSnackBar(
            context,
            "Each image must be less than 5 MB.",
          );
          continue;
        }

        setState(() {
          _selectedImages.add(img);
        });
      }
    }

    _updateButtonStatus(); // ✅ update button state
  }

  Future<void> _pickFromCamera() async {
    if (_selectedImages.length >= 12) {
      CommonUtilities.createSnackBar(context, "Maximum 12 images allowed.");
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 40);
    if (image != null) {
      final isValid = await _isValidFileSize(image.path);

      if (!isValid) {
        CommonUtilities.createSnackBar(
          context,
          "Each image must be less than 5 MB.",
        );
        return;
      }

      setState(() {
        _selectedImages.add(image);
      });
    }

    _updateButtonStatus(); // ✅ update button state
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
  Widget build(BuildContext context)
  {
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
              backgroundColor: const Color(0xFFEFF5D6),
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
                        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    getActivIcon(),

                                    getText(),

                                    getSubText(),

                                    // Upload Box
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 25, 0, 0),
                                      child: DottedBorder(
                                        color: AppColors.purple,
                                        strokeWidth: 1.5,
                                        dashPattern: [6, 4],
                                        borderType: BorderType.RRect,
                                        radius: const Radius.circular(12),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 74,
                                                height: 58,
                                                child: Image.asset('assets/ic_pan.png'),
                                              ),
                                              Container(
                                                margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                                                child: const Text(
                                                  "Drag and drop",
                                                  style: TextStyle(
                                                      fontSize: AppSize.size_16,
                                                      fontFamily: 'FontSemiBold',
                                                      color: AppColors.darkBlack,
                                                      height: 1
                                                  ),
                                                ),
                                              ),
                                              // Sub Text
                                              Container(
                                                margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                                                child: const Text(
                                                  "or browse for photos",
                                                  style: TextStyle(
                                                      fontSize: AppSize.size_14,
                                                      fontFamily: 'FontRegular',
                                                      color: AppColors.black1,
                                                      height: 1
                                                  ),
                                                ),
                                              ),
                                              // Browser Button to Pick Images
                                              InkWell(
                                                onTap: ()
                                                {
                                                  _showPickOptions();
                                                  //_pickImages();
                                                },
                                                child: Container(
                                                    height: 45,
                                                    margin: const EdgeInsets.fromLTRB(65, 15, 65, 5),
                                                    decoration: BoxDecoration(
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(12),
                                                        topRight: Radius.circular(12),
                                                        bottomLeft: Radius.circular(12),
                                                        bottomRight: Radius.circular(12),
                                                      ),
                                                      border: Border.all(color: AppColors.purple, width: 1),
                                                      color: AppColors.white,
                                                    ),
                                                    child: Container(
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                          "Browse",
                                                          style: TextStyle(
                                                              fontSize: AppSize.size_16,
                                                              fontFamily: 'FontSemiBold',
                                                              color: AppColors.purple,
                                                              height: 1
                                                          ),
                                                        )
                                                    )
                                                ),
                                              ),

                                              Container(
                                                alignment: Alignment.center,
                                                margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                                                child: const Text(
                                                  "Please upload a minimum of 4 clear wide-angle photos in PNG or JPG formats up-to 5 MB",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: AppSize.size_14,
                                                      fontFamily: 'FontRegular',
                                                      color: AppColors.black1,
                                                      height: 1.4
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )

                                    ),

                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 20, 0, 15),
                                      height: 120,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _selectedImages.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            margin: const EdgeInsets.only(right: 8), // spacing between images
                                            width: 120, // ✅ fixed width for each image
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.file(
                                                    File(_selectedImages[index].path),
                                                    fit: BoxFit.cover,
                                                    width: 120,
                                                    height: 120,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 5,
                                                  right: 5,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedImages.removeAt(index);
                                                      });
                                                    },
                                                    child: Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding: const EdgeInsets.all(4),
                                                      child: const Icon(Icons.close,
                                                          size: 18, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
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
                                              onTap: ()
                                              {
                                                Navigator.pop(context);
                                              },
                                              child: getBackButton(context, "Back", "venuePhoto"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                          onTap: () {
                                            if (_selectedImages.length >= 4 && _selectedImages.length <= 12) {
                                              // ✅ Valid case: navigate
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AddVenuePhotoListViewScreen(images: _selectedImages),
                                                ),
                                              ).then((value) {
                                                refresh();
                                              });
                                            } else {
                                              // ❌ Invalid case: show message
                                              CommonUtilities.createSnackBar(
                                                context,
                                                "Please upload a minimum of 4 and a maximum of 12 images.",
                                              );
                                            }
                                          },
                                          child: (_selectedImages.length >= 4 && _selectedImages.length <= 12)
                                              ? getButtonBlack(context, "Next", "venuePhoto") // ✅ Active button
                                              : getButtonGray(context, "Next", "venuePhoto"), // ❌ Disabled button
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
        child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain)
    );
  }


  Widget getText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 25),
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
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
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

  void refresh()
  {
    if(CommonUtilities.callVenueImagesClear == "yes")
    {
      CommonUtilities.callVenueImagesClear = "";
      _selectedImages.clear();
      setState(() {});
    }else{}
  }
}

