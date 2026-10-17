import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Style/constants_messages.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'LoginScreen.dart';
import 'MobileNumberFormatter.dart';
import 'OTPVerificationScreen.dart';
import 'onboarding_widgets.dart';

class MobileNumberScreen extends StatefulWidget {
  const MobileNumberScreen({
    super.key,
    this.client,
    this.isCreatingAccount = false,
  });

  final http.Client? client;
  final bool isCreatingAccount;

  @override
  State<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends State<MobileNumberScreen> {
  final TextEditingController mobileController = TextEditingController();
  bool isButtonEnabled = false;
  bool _isSubmitting = false;
  final String phoneCode = '+91';

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  void _validateNumber(String input) {
    setState(() {
      isButtonEnabled = input.replaceAll('-', '').length == 10;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> sendOTP() async {
    if (_isSubmitting || !validation(context)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final mobile = mobileController.text.replaceAll('-', '');

    try {
      await SharedPreference.remove('jwt_token');
      await SharedPreference.remove('is_profile_complete');
      await SharedPreference.remove('is_active');
      if (!mounted) return;

      final response = await (widget.client?.post ?? http.post)(
        Uri.parse('$REQUEST_OTP_URL?intent=${widget.isCreatingAccount ? 'register' : 'login'}'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'phone': mobile}),
      );

      if (!mounted) return;
      CommonUtilities.showLog('Request OTP status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await SharedPreference.addStringToSF('phoneCode', phoneCode);
        await SharedPreference.addStringToSF(
            'userMobileNumber', mobileController.text);
        if (!mounted) return;
        CommonUtilities.NavigateWithPush(
            context, OTPVerificationScreen(
              client: widget.client,
              isCreatingAccount: widget.isCreatingAccount,
            ));
      } else {
        final body = jsonDecode(response.body);
        _showMessage(body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Failed to send OTP. Please try again.');
      }
    } catch (error) {
      if (!mounted) return;
      CommonUtilities.showLog('Request OTP error: $error');
      _showMessage('Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool validation(BuildContext context) {
    final digits = mobileController.text.replaceAll('-', '');
    if (digits.isEmpty) {
      _showMessage(ConstantsMessages.mobileNumberEnter);
      return false;
    } else if (digits.length != 10) {
      _showMessage(ConstantsMessages.mobileNumberValid);
      return false;
    }
    return true;
  }

  void _openLogin() {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(client: widget.client)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your mobile number',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 25,
                    height: 1.15,
                    color: AppColors.darkBlack,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "We'll send a 4-digit OTP to verify your number.",
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    height: 1.25,
                    color: AppColors.black1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          const SizedBox(height: 22),
                          const Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'Mobile Number'),
                              TextSpan(
                                text: '*',
                                style: TextStyle(color: AppColors.red),
                              ),
                            ]),
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                              color: AppColors.darkBlack,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 58,
                            child: TextFormField(
                              key: const Key('mobile-number'),
                              controller: mobileController,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.telephoneNumberNational
                              ],
                              cursorColor: Colors.black,
                              style: OnboardingStyles.body.copyWith(fontSize: 14),
                              inputFormatters: [MobileNumberFormatter()],
                              decoration: OnboardingStyles.inputDecoration(
                                hintText: '00-0000-0000',
                              ).copyWith(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.gray),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.gray1),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 58),
                                prefixIcon: Container(
                                  width: 48,
                                  height: 58,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: AppColors.gray),
                                    ),
                                  ),
                                  child: const Text(
                                    '+91',
                                    style: OnboardingStyles.body,
                                  ),
                                ),
                              ),
                              onChanged: _validateNumber,
                              onFieldSubmitted: (_) {
                                if (isButtonEnabled) sendOTP();
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OnboardingSupportMenu(
                              buttonKey: const Key('mobile-support'),
                              enabled: !_isSubmitting,
                              client: widget.client,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F7D7),
              boxShadow: [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 5,
                    offset: Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                width: 108,
                height: 58,
                  child: OnboardingButton(
                    label: 'Back',
                    outlined: true,
                    onPressed: _isSubmitting ? null : _openLogin,
                    fontSize: 16,
                    minHeight: 58,
                    borderRadius: 10,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OnboardingButton(
                      key: const Key('mobile-submit'),
                      label: 'Send OTP',
                      loading: _isSubmitting,
                      onPressed: isButtonEnabled ? sendOTP : null,
                      disabledBackgroundColor: AppColors.darkGray,
                      disabledForegroundColor: AppColors.lightGray,
                      fontSize: 16,
                      minHeight: 58,
                      borderRadius: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
