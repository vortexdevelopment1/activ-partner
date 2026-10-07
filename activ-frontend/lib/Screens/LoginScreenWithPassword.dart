import 'dart:developer';
import 'dart:io';

import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class LoginScreenWithPassword extends StatefulWidget {
  const LoginScreenWithPassword({super.key});

  @override
  State<LoginScreenWithPassword> createState() => _State();
}

class _State extends State<LoginScreenWithPassword> {

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isButtonEnabled = false;

  AuthService authService = AuthService();

  String phoneCode = "IND (+91)";

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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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

                                    getActivIcon('assets/logo.png'),

                                   // getStepBarCount(progress, currentStep, totalSteps),

                                    Container(
                                      margin: EdgeInsets.only(left: 15, right: 15),
                                        child: getText('Login to your account')),

                                   // getSubText('We’ll send you a verification code'),
                              
                                    getEmailText(),
                                    getEmailField(context),

                                    getPasswordText(),
                                    getPasswordField(context),

                                    getForgotPasswordText(context),

                                    Container(
                                      margin: const EdgeInsets.only(top: 10),
                                        child: getButtonBlack(context, "Login", "login")
                                    ),

                                    // Line and Or Text Layout
                                    Container(
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [

                                          getHorizontalLine(),

                                          getOrText(),

                                          getHorizontalLine(),
                                        ],
                                      ),
                                    ),

                                    InkWell(
                                      onTap: ()
                                      {
                                        CommonUtilities.NavigateWithPush(context, LoginScreen());
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(top: 5),
                                        child: getLoginWithOTP(context, 'Login using OTP', 'login'),
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
                                  getTermsConditionText(),

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


  Widget getEmailText()
  {
    return Row(
      children: [
         Container(
          margin: EdgeInsets.fromLTRB(15, 20, 0, 0),
          child: const Text(
            "Email Address",
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

  Widget getEmailField(BuildContext context)
  {
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
                  controller: emailController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.emailAddress,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [],
                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Email Id',
                    hintStyle: TextStyle(
                      fontSize:  AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.hintColor,
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
    
    String input = emailController.text.trim();

    if (input.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.emailIdEnter);
      return false;
    }
    else if (!CommonUtilities.emailVaidatation(emailController.text.trim())) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validEmailEnter);
      return false;
    }
    return true;
  }
}
