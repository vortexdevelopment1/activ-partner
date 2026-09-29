import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/api_calling/progress_bar/progress_bar_new.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'MobileNumberFormatter.dart';
import 'OTPVerificationScreen.dart';

class MobileNumberScreen extends StatefulWidget {
  const MobileNumberScreen({super.key});

  @override
  State<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends State<MobileNumberScreen> {

  TextEditingController mobileController = TextEditingController();
  bool isButtonEnabled = false;
  final String phoneCode = "+91";

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  void _validateNumber(String input) {
    String digits = input.replaceAll('-', '');
    setState(() {
      isButtonEnabled = digits.length == 10;
    });
  }

  void sendOTP() async {
    String mobile = mobileController.text.replaceAll('-', '');

    await SharedPreference.remove("jwt_token");
    await SharedPreference.remove("is_profile_complete");
    await SharedPreference.remove("is_active");

    ProgressBarNew().showLoader(context);

    try {
      final response = await http.post(
        Uri.parse(REQUEST_OTP_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"phone": mobile}),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog("Request OTP status: ${response.statusCode}");
      CommonUtilities.showLog("Request OTP response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await SharedPreference.addStringToSF("phoneCode", phoneCode);
        await SharedPreference.addStringToSF("userMobileNumber", mobileController.text);

        if (!mounted) return;
        CommonUtilities.NavigateWithPush(context, OTPVerificationScreen());
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Failed to send OTP. Please try again.';
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog("Request OTP error: $e");
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  bool validation(BuildContext context) {
    String digits = mobileController.text.replaceAll('-', '');
    if (digits.isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.mobileNumberEnter);
      return false;
    } else if (digits.length != 10) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.mobileNumberValid);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: 100, color: AppColors.yellowTop),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 100, color: AppColors.white),
          ),
          SafeArea(
            top: true,
            bottom: true,
            left: false,
            right: false,
            child: Scaffold(
              body: Container(
                decoration: context.getYellowGradient,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [

                          getActivIcon('assets/activ_tm.svg'),

                          Container(
                            margin: EdgeInsets.only(left: 15, right: 15),
                            child: getText('Enter your mobile number'),
                          ),

                          Container(
                            margin: EdgeInsets.only(top: 8, left: 15, right: 15, bottom: 0),
                            child: Text(
                              "We'll send a 4-digit OTP to verify your number.",
                              style: TextStyle(
                                fontSize: AppSize.size_14,
                                fontFamily: 'FontRegular',
                                color: AppColors.black1,
                                height: 1.4,
                              ),
                            ),
                          ),

                          getMobileLabel(),
                          getMobileField(context),

                        ],
                      ),
                    ),

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
                                  onTap: () => Navigator.pop(context),
                                  child: getBackButton(context, "Back", "mobileNumber"),
                                ),
                              ),
                              Expanded(
                                flex: 7,
                                child: InkWell(
                                  onTap: () {
                                    if (validation(context)) {
                                      sendOTP();
                                    }
                                  },
                                  child: isButtonEnabled
                                      ? getButtonBlack(context, "Send OTP", "mobileNumber")
                                      : getButtonGray(context, "Send OTP", "mobileNumber"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ],
    );
  }

  Widget getMobileLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 25, 0, 0),
          child: const Text(
            "Mobile Number",
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.red,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget getMobileField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 8, 15, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Row(
        children: [
          // Country code prefix
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.gray, width: 1),
              ),
            ),
            child: Text(
              phoneCode,
              style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.darkBlack,
              ),
            ),
          ),
          // Mobile number input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10),
              child: TextFormField(
                controller: mobileController,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.phone,
                cursorColor: AppColors.cursorBlack,
                inputFormatters: [
                  MobileNumberFormatter(),
                ],
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.darkBlack,
                ),
                decoration: InputDecoration(
                  hintText: '00-0000-0000',
                  hintStyle: TextStyle(
                    fontSize: AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.hintColor,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: _validateNumber,
                onFieldSubmitted: (_) {
                  if (validation(context)) sendOTP();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
