import 'dart:io';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'CustomerPlacesOffer.dart';
import 'MobileNumberFormatter.dart';

class ContactSupportFormScreen extends StatefulWidget {
  const ContactSupportFormScreen({super.key});

  @override
  State<ContactSupportFormScreen> createState() => _State();
}

class _State extends State<ContactSupportFormScreen> {

  TextEditingController nameController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  bool isButtonEnabled = false;
  String phoneCode = "", userMobileNumber = "";

  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  _State()
  {
    getData();
  }

  @override
  void initState() {
    super.initState();
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));

    setState(() {});
  }

  void _validateNumber(String input) {
    String digits = input.replaceAll('-', '');
    if (digits.length == 10) {
      setState(() {
        isButtonEnabled = true;
      });
    } else {
      setState(() {
        isButtonEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileNumberController.dispose();
    descriptionController.dispose();
    super.dispose();
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
                    double width = constraints.maxWidth;

                    bool isMobile = width < 600;
                    bool isTablet = width >= 600 && width < 1100;

                    double containerWidth =
                    isMobile ? width * 1 : (isTablet ? 500 : 600);

                    return Container(
                      //width: containerWidth,
                      //margin: const EdgeInsets.only(right: 20),
                      //padding: EdgeInsets.all(isMobile ? 20 : 30),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            getToolTab(context),

                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                   // getActivIcon('assets/logo.png'),


                                   /* Container(
                                      margin: const EdgeInsets.only(top: 10),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Contact Support',
                                        style: TextStyle(
                                            fontSize: AppSize.size_25,
                                            fontFamily: 'FontSemiBold',
                                            color: AppColors.darkBlack,
                                            height: 1.2
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),*/

                                    //getSubText(''),

                                    getNameLabel(),
                                    getNameField(context),

                                    getPhoneNumberText(),
                                    getMobileNumberField(context),

                                    getDescriptionLabel(),
                                    getDescriptionField(context),


                                    // Upload Box
                                    _selectedImage == null
                                        ?
                                    Container(
                                        margin: const EdgeInsets.fromLTRB(0, 25, 0, 20),
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
                                                    "Please upload a clear wide-angle photos in PNG or JPG formats up-to 5 MB",
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

                                    )
                                        :
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 25, 0, 20),
                                      child: Stack(
                                        children: [
                                          // Image Container
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                                            decoration: BoxDecoration(
                                              color: AppColors.white,
                                              borderRadius: BorderRadius.circular(12.0),
                                              border: Border.all(color: AppColors.gray, width: 1),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.file(
                                                File(_selectedImage!.path),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),

                                          // Cross Icon (Top-Right)
                                          Positioned(
                                            top: 15,
                                            right: 10,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedImage = null;
                                                });
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),



                                  ],
                                ),
                              ),
                            ),

                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: Column(
                                children: [
                                  bottomBarShadow(),

                                  Row(
                                    children: [


                                     /* Expanded(
                                          flex: 3,
                                          child: InkWell(
                                              onTap: ()
                                              {
                                                Navigator.pop(context);
                                              },
                                              child: getBackButton(context, "Back", "contactSupportForm"))
                                      ),*/


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                            onTap: ()
                                            {
                                              if(validation(context))
                                              {
                                                customAlertDialog(context, 'Your message has been submitted. Our team will reach out to you soon. Thank you for contacting us.');
                                              }else{}

                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(left: 5),
                                                child: getButtonBlack(context, "Submit", "contactSupportForm"))
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            )

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

  // To show the toolbar
  Widget getToolTab(BuildContext context)
  {
    return Container(
      height: AppSize.toolTabSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: InkWell(onTap: ()
              {
                Navigator.pop(context);
              },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(13,10,15,10),
                    child: SvgPicture.asset('assets/ic_back.svg',),
                  )
              ),
            ),
          ),

          getTitleText(context, 'Contact Us', 'Contact_Us')

        ],
      ),
    );
  }

  Widget getNameLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: const Text(
            "Name",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.red,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        )
      ],
    );
  }

  Widget getNameField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: const Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray, width: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("[a-zA-Z ]")),
              new LengthLimitingTextInputFormatter(50),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Full Name', // Set the hint label text
              hintStyle: TextStyle(
                fontSize:  AppSize.size_14,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor, // Text color of the hint label
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget getPhoneNumberText()
  {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Phone Number",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        Container(
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.red,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        )
      ],
    );
  }

  Widget getMobileNumberField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: const Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray, width: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 0, right: 0),
        child: Row(
          children: [
            // Country Code Layout
            InkWell(
              onTap: ()
              {
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                margin: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: Row(
                  children: [
                    Container(
                      child: Text(
                        (phoneCode!=null && phoneCode!="") ? phoneCode : "",
                        style: TextStyle(
                          fontSize:  AppSize.size_14,
                          fontFamily: 'FontRegular',
                          color: AppColors.darkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider Line.
            Container(
              height: 50,
              margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: VerticalDivider(
                color: AppColors.gray,
                thickness: 1,
              ),
            ),

            Expanded(
              //flex: 4,
              child: Container(
                child: TextFormField(
                  controller: mobileNumberController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.number,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    MobileNumberFormatter(),
                  ],
                  onChanged: _validateNumber,
                  validator: (value) {
                    String digits = value?.replaceAll('-', '') ?? '';
                    if (digits.length != 10) {
                      return "Enter valid 10-digit mobile number";
                    }
                    return null;
                  },

                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XX-XXXX-XXXX', // Set the hint label text
                    hintStyle: TextStyle(
                      fontSize:  AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.hintColor, // Text color of the hint label
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget getDescriptionLabel() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(
            child: const Text(
              "Description",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontMedium',
                  color: AppColors.black1,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          ),

          Container(
            child: const Text(
              "*",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontMedium',
                  color: AppColors.red,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          )
        ],
      ),
    );
  }

  Widget getDescriptionField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: const Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray, width: 1)),
      child: TextFormField(
        controller: descriptionController,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        cursorColor: AppColors.cursorBlack,
        /*inputFormatters: [
          LengthLimitingTextInputFormatter(50),
        ],*/
        maxLines: 4,
        maxLength: 500,
        style: TextStyle(
          fontSize:  AppSize.size_14,
          fontFamily: 'FontRegular',
          color: AppColors.darkBlack,
        ),
        decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Enter Description',
          hintStyle: TextStyle(
            fontSize:  AppSize.size_14,
            fontFamily: 'FontRegular',
            color: AppColors.hintColor, // Text color of the hint label
          ),
        ),
      ),
    );
  }

  // Crop Image
  Future<XFile?> _cropImage(String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: "Crop Image",
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          statusBarColor: Colors.black,
          initAspectRatio: CropAspectRatioPreset.original,
          showCropGrid: true,
          lockAspectRatio: true,
          hideBottomControls: true
        ),
        IOSUiSettings(
          title: "Crop Image",
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (cropped != null) {
      return XFile(cropped.path);
    }
    return null;
  }

// Pick from Gallery (single image only)
  Future<void> _pickSingleFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final cropped = await _cropImage(image.path);
      if (cropped != null) {
        setState(() {
          _selectedImage = cropped;
        });
      }
    }
  }

  // Pick from Camera (single image only)
  Future<void> _pickSingleFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final cropped = await _cropImage(image.path);
      if (cropped != null) {
        setState(() {
          _selectedImage = cropped;
        });
      }
    }
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
                _pickSingleFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickSingleFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  customAlertDialog(BuildContext buildContext, String message)
  {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 20),
              margin: const EdgeInsets.only(top: 45,left: 40,right: 40),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),

              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[

                  const Text(
                    '⚠ Alert!',
                    style: TextStyle(
                        fontSize:  AppSize.size_18,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkBlack,
                        textBaseline: null),
                  ),

                  const SizedBox(height: 15,),

                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                    child: Text(
                      message,
                      style: const TextStyle(
                          fontSize:  AppSize.size_16,
                          fontFamily: 'FontSemiBold',
                          color: AppColors.darkBlack,
                          height: 1.5),
                      textAlign: TextAlign.center,),
                  ),

                  const SizedBox(height: 15,),

                  // Divider Line
                  Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: Divider(
                        color: AppColors.gray1,
                        height: 1,
                      )
                  ),

                  const SizedBox(height: 0,),

                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: ()
                            {
                              Navigator.pop(context);
                              //Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(30, 13, 30, 13),
                              alignment: Alignment.center,
                              child: const Text(
                               'OK',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize:  AppSize.size_16,
                                    fontFamily: 'FontSemiBold',
                                    color: AppColors.darkBlack
                                ),
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool validation(BuildContext context)
  {
    String input = mobileNumberController.text.trim();

    if (nameController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationFullNameEnter);
      return false;
    }
    else if (input.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.mobileNumberEnter);
      return false;
    }
    else if (!RegExp(r'^\d{2}-\d{4}-\d{4}$').hasMatch(input)) {
    CommonUtilities.createSnackBar(context, ConstantsMessages.mobileNumberValid);
    return false;
    }
    else if (descriptionController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterValidDescription);
      return false;
    }
    return true;
  }
}
