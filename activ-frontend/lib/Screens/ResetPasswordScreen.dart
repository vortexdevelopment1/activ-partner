import 'dart:developer';
import 'dart:io';

import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/LoginScreenWithPassword.dart';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../Database/auth_service.dart';
import '../Database/database_service.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'ForgotPasswordScreen.dart';
import 'ListActivityTypeScreen.dart';
import 'MobileNumberFormatter.dart';
import 'OTPVerificationScreen.dart';

class ResetPasswordScreen extends StatefulWidget {
  String emailId="";

  ResetPasswordScreen({required this.emailId});

  @override
  State<ResetPasswordScreen> createState() => _State();
}

class _State extends State<ResetPasswordScreen> {

  String enterOTP = "";

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isButtonEnabled = false;

  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  AuthService authService = AuthService();

  String phoneCode = "IND (+91)";
  final int otpLength = 4;
  int currentStep = 1;
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
    for (int i = 0; i < otpLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void onChangedValue(String value, int index) {
    if (value.isNotEmpty) {
      if (index < otpLength - 1) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      }
    } else {
      if (index > 0) {
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }
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
                      //margin: const EdgeInsets.only(right: 20),
                      //padding: EdgeInsets.all(isMobile ? 20 : 30),
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Expanded(
                              child: Container(
                                margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                    getActivIcon('assets/activ_tm.svg'),

                                    // getStepBarCount(progress, currentStep, totalSteps),

                                    Container(
                                        margin: EdgeInsets.only(left: 15, right: 15),
                                        child: getText('Reset Password')),

                                    // getSubText('We’ll send you a verification code'),

                                    getSentCodeText(),

                                    getOneTimeCodeText(),
                                    getOTPBox(context),

                                    getPasswordText(),
                                    getPasswordField(context),

                                    getConfirmPasswordText(),
                                    getConfirmPasswordField(context),


                                    InkWell(
                                      onTap: ()
                                      {
                                        if(validation(context))
                                        {

                                        }
                                      },
                                      child: Container(
                                          margin: EdgeInsets.only(top: 15),
                                          child: getButtonBlack(context, "Submit", "login")
                                      ),
                                    ),


                                    InkWell(
                                      onTap: ()
                                      {
                                        CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, LoginScreenWithPassword());
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(top: 5),
                                        child: getLoginWithOTP(context, 'Back to Login', 'login'),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),

                            Container(
                              margin: EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 10),
                              child: Column(
                                children: [

                                  // bottomBarShadow(),

                                  /*InkWell(
                                      onTap: ()
                                      {

                                        if(isButtonEnabled)
                                        {
                                          SharedPreference.addStringToSF("userEmail", checkString(emailController.text.trim().toString()));

                                          if(validation(context))
                                          {
                                            handleLogin(context);
                                            //CommonUtilities.NavigateWithPush(context, OTPVerificationScreen());
                                          }
                                        }
                                        else{}

                                      },
                                      child: isButtonEnabled ? getButtonBlack(context, "Send Code", "login") :
                                           getButtonGray(context, "Send Code", "login")
                                  )*/
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

  Widget getSentCodeText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(15, 10, 15, 0),
      child: Text(
        "Verification code sent to " + widget.emailId,
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

  Widget getOneTimeCodeText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(15, 15, 15, 0),
      child: const Text(
        "Enter the 4 digit one-time code",
        style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontMedium',
            color: AppColors.black1,
            height: 1
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getOTPBox(BuildContext context)
  {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(top: 8, left: 15, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(
          otpLength,
              (index) => Padding(
            padding: const EdgeInsets.only(right: 20),
            child: SizedBox(
              width: 50,
              height: 50,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: "",
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.gray,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.gray1,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => onChangedValue(value, index),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget getPasswordText()
  {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(15, 20, 0, 0),
          child: const Text(
            "Password",
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
          margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
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

  bool _isPasswordVisible = false;

  Widget getPasswordField(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(15, 8, 15, 0),
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
            Expanded(
              //flex: 4,
              child: Container(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: TextFormField(
                  controller: passwordController,
                  obscureText: !_isPasswordVisible, // hide/show password dynamically
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.text,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [],
                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Password',
                    hintStyle: TextStyle(
                      fontSize:  AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.hintColor,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.hintColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),

                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }


  Widget getConfirmPasswordText()
  {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(15, 20, 0, 0),
          child: const Text(
            "Confirm Password",
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
          margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
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

  bool _isConfirmPasswordVisible = false;

  Widget getConfirmPasswordField(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(15, 8, 15, 0),
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
            Expanded(
              //flex: 4,
              child: Container(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible, // hide/show password dynamically
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.text,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [],
                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Confirm Password',
                    hintStyle: TextStyle(
                      fontSize:  AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.hintColor,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.hintColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),

                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget getForgotPasswordText(BuildContext context)
  {
    return InkWell(
      onTap: ()
      {
        CommonUtilities.NavigateWithPush(context, ForgotPasswordScreen(emailId: emailController.text.toString().trim(),));
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 10, 15, 0),
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'FontMedium',
                  color: AppColors.purple,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget getHorizontalLine()
  {
    return Container(
      color: AppColors.gray,
      height: 1,
      width: 145,
    );
  }

  Widget getOrText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: Text(
        'Or',
        style: TextStyle(
            color: AppColors.darkBlack,
            fontSize: AppSize.size_14,
            fontFamily: 'FontMedium'
        ),
      ),
    );
  }

  Widget getTermsConditionText()
  {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'FontMedium',
            fontSize: AppSize.size_14,
            height: 1.5
        ),
        children: [
          const TextSpan(
            text: 'By clicking on Login, I accept the ',
            style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'FontMedium',
                fontSize: AppSize.size_14
            ),
          ),

          TextSpan(
            text: 'Terms & Conditions',
            style: const TextStyle(
                color: AppColors.purple,
                fontFamily: 'FontMedium',
                fontSize: AppSize.size_14
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Terms & Conditions click
                debugPrint('Terms & Conditions clicked');
                // Navigator.push(...)
              },
          ),

          const TextSpan(
            text: ' & ',
          ),

          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
                color: AppColors.purple,
                fontFamily: 'FontMedium',
                fontSize: AppSize.size_14
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Privacy Policy click
                debugPrint('Privacy Policy clicked');
                // Navigator.push(...)
              },
          ),
        ],
      ),
    );
  }

  String deviceType = "", appVersionName="", appVersionCode="", deviceName="", deviceVersion="", dateTime="", todayDate="";

  void handleLogin(BuildContext context) async {
    String email = emailController.text.trim();

    // Check if user exists in Firestore
    /*bool exists = await DatabaseService(uid: mobile).checkIfUserExists(mobile);

    if (exists) {
      // User already exists Go to HomeScreen
      CommonUtilities.NavigateWithPush(context, ListActivityTypeScreen());
    } else {
      authService.registerWithNumber(phoneCode, mobileNumberController.text.toString().trim()).then((value) async
      {
        CommonUtilities.NavigateWithPush(context, OTPVerificationScreen());
      });
    }*/

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceDetails = deviceInfo.toString();

    DateTime today = DateTime.now(); // Get Today Date
    todayDate = today.toString();
    String formatedDate1 = CommonUtilities.converDateFormate(todayDate, "DD-MM-YYYY", "yyyy-MM-dd HH:mm:ss"); //2022-09-29T08:07:48.000Z
    dateTime = CommonUtilities.converDateFormate(formatedDate1, "yyyy-MM-dd HH:mm:ss", "dd-MM-yyyy HH:mm:ss a");

    CommonUtilities.showLog("dateTime : " + dateTime);

    if (Platform.isAndroid) {
      deviceType = "Android";
      appVersionName = packageInfo.version;
      appVersionCode = packageInfo.buildNumber;

      AndroidDeviceInfo androidDeviceInfo = await deviceInfo.androidInfo;
      deviceName = androidDeviceInfo.name;
      deviceVersion = androidDeviceInfo.version.sdkInt.toString();
    }
    else{
      deviceType = "IOS";
      appVersionName = packageInfo.version;
      appVersionCode = packageInfo.buildNumber;

      IosDeviceInfo iosDeviceInfo = await deviceInfo.iosInfo;
      deviceName = iosDeviceInfo.name;
      deviceVersion = iosDeviceInfo.model;
    }

    authService.registerWithNumber(phoneCode, emailController.text.toString().trim(), deviceType, appVersionName, appVersionCode,
        deviceName, deviceVersion, dateTime, "LoginScreen").then((value) async
    {
      CommonUtilities.NavigateWithPush(context, OTPVerificationScreen());
    });
  }

  bool validation(BuildContext context)
  {

    enterOTP = _controllers.map((c) => c.text).join();

    if (enterOTP.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterOTP);
      return false;
    }
    else if (passwordController.text.toString().trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.passwordEnter);
      return false;
    }
    else if (passwordController.text.toString().trim().length < 6) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.passwordMustBeAtLeast6characters);
      return false;
    }
    else if (confirmPasswordController.text.toString().trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.confirmPasswordEnter);
      return false;
    }
    else if (confirmPasswordController.text.toString().trim().length < 6) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.passwordMustBeAtLeast6characters);
      return false;
    }
    return true;
  }
}
