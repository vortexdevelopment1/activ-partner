import 'dart:convert';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:http/http.dart' as http;
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/api_calling/progress_bar/progress_bar_new.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'ContactSupportScreen.dart';
import 'Home/HomeScreen.dart';
import 'TellUsAboutScreen.dart';
import 'VenueScreen.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  State<OTPVerificationScreen> createState() => _State();
}

class _State extends State<OTPVerificationScreen> {

  final int otpLength = 4;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  String phoneCode = "", userMobileNumber="", enterOTP="";

  int currentStep = 2;
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

  _State()
  {
    getData();
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < otpLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    setState(() {});
  }

  @override
  void dispose() {
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

  /*void verifyOtp() {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length == otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Entered OTP: $otp")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter complete OTP")),
      );
    }
  }*/

  void handleOTP() async {
    String enteredOTP = _controllers.map((c) => c.text).join();
    String mobile = userMobileNumber.replaceAll("-", "");

    ProgressBarNew().showLoader(context);

    try {
      final response = await http.post(
        Uri.parse(VERIFY_OTP_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"phone": mobile, "otp": enteredOTP}),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog("Verify OTP status: ${response.statusCode}");
      CommonUtilities.showLog("Verify OTP response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final String token = _extractToken(body);
        final bool isProfileComplete = body['data']?['isProfileComplete'] == true;
        final bool isUserActive = body['data']?['partner']?['isActive'] == true;

        if (token.isEmpty) {
          CommonUtilities.showLog("Verify OTP missing token. Response: ${response.body}");
          CommonUtilities.createSnackBar(
              context, 'OTP verified, but login token was missing. Please try again.');
          return;
        }

        await SharedPreference.addStringToSF("jwt_token", token);
        await SharedPreference.addStringToSF("is_profile_complete", isProfileComplete ? "true" : "false");
        await SharedPreference.addStringToSF("is_active", isUserActive ? "true" : "false");

        if (!mounted) return;
        if (!isProfileComplete) {
          CommonUtilities.NavigateWithPush(context, TellUsAboutScreen());
        } else if (!isUserActive) {
          await _checkVenueAndNavigate(token);
        } else {
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, HomeScreen());
        }
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Invalid OTP. Please try again.';
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog("Verify OTP error: $e");
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  Future<void> _checkVenueAndNavigate(String token) async {
    try {
      final response = await http.get(
        Uri.parse(MY_VENUES_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      CommonUtilities.showLog("My venues status: ${response.statusCode}");
      CommonUtilities.showLog("My venues body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        final int total = (data?['total'] as num?)?.toInt() ?? 0;
        final List items = (data?['items'] ?? data?['venues'] ?? data?['data'] ?? []) as List;
        final String firstStatus = items.isNotEmpty
            ? (items.first['status']?.toString() ?? '')
            : '';
        final String firstVenueId = items.isNotEmpty
            ? (items.first['id']?.toString() ?? '')
            : '';

        if (total == 1 && firstStatus == 'pending') {
          if (firstVenueId.isNotEmpty) {
            await SharedPreference.addStringToSF("venue_id", firstVenueId);
          }
          if (!mounted) return;
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
              context, const ContactSupportScreen());
        } else if (total == 1 && firstStatus == 'draft') {
          if (!mounted) return;
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
              context, VenueScreen());
        } else {
          // No venue yet or unexpected state — start venue onboarding
          if (!mounted) return;
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
              context, VenueScreen());
        }
      } else {
        // Fallback: continue onboarding
        CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
            context, VenueScreen());
      }
    } catch (e) {
      CommonUtilities.showLog("My venues error: $e");
      if (!mounted) return;
      CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
          context, VenueScreen());
    }
  }

  bool validation(BuildContext context)
  {
    enterOTP = _controllers.map((c) => c.text).join();

    if (enterOTP.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterOTP);
      return false;
    }
    else if (enterOTP.length != otpLength) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterOTP);
      return false;
    }
    return true;
  }

  String _extractToken(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final directToken = data['accessToken'] ??
          data['token'] ??
          data['access_token'] ??
          data['jwtToken'] ??
          data['jwt_token'];
      if (directToken != null && directToken.toString().isNotEmpty) {
        return directToken.toString();
      }

      final auth = data['auth'];
      if (auth is Map<String, dynamic>) {
        final authToken =
            auth['accessToken'] ?? auth['token'] ?? auth['access_token'];
        if (authToken != null && authToken.toString().isNotEmpty) {
          return authToken.toString();
        }
      }
    }

    final rootToken = body['accessToken'] ??
        body['token'] ??
        body['access_token'] ??
        body['jwtToken'] ??
        body['jwt_token'];
    return rootToken?.toString() ?? '';
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
                     // width: containerWidth,
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
                                margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                    getActivIcon('assets/activ_tm.svg'),

                                    getStepBarCount(progress, currentStep, totalSteps),

                                    getText('Verify your number'),

                                    getSentCodeText(),

                                    getOneTimeCodeText(),

                                    getOTPBox(context)


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
                                   getEditNumberText(context),

                                   Expanded(
                                     child: InkWell(
                                         onTap: ()
                                         {
                                            if(validation(context))
                                            {
                                              handleOTP();

                                            }else{}
                                         },
                                         child: getButtonBlack(context, "Verify", "verifyOTP")
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


  Widget getSentCodeText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 10, 0, 15),
      child: Text(
        "We sent a code to " + phoneCode + "-" + userMobileNumber,
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'FontRegular',
            color: AppColors.black1,
            height: 1
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getOneTimeCodeText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
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

  Widget getOTPBox(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(top: 8),
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

  Widget getEditNumberText(BuildContext context)
  {
    return InkWell(
      onTap: ()
      {
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 5, 5, 10),
        child: const Text(
          'Edit Number',
          style: TextStyle(
            fontSize: AppSize.size_18,
            fontFamily: 'FontSemiBold',
            color: AppColors.black,
            height: 1,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.black,
            decorationThickness: 1.5,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

}
