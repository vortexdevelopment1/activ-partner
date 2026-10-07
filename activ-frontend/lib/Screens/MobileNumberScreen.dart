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
  const MobileNumberScreen({super.key, this.client});

  final http.Client? client;

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
        Uri.parse(REQUEST_OTP_URL),
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
            context, const OTPVerificationScreen());
      } else {
        final body = jsonDecode(response.body);
        _showMessage(body['message']?.toString() ??
            'Failed to send OTP. Please try again.');
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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const OnboardingLogo(),
                          const SizedBox(height: 16),
                          const Text('Enter your mobile number',
                              style: OnboardingStyles.heading),
                          const SizedBox(height: 6),
                          Text("We'll send you a verification code",
                              style: OnboardingStyles.body.copyWith(
                                  fontSize: 16, color: AppColors.black1)),
                          const SizedBox(height: 26),
                          const Text.rich(TextSpan(children: [
                            TextSpan(text: 'Phone Number'),
                            TextSpan(
                                text: '*',
                                style: TextStyle(color: AppColors.red)),
                          ])),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const Key('mobile-number'),
                            controller: mobileController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational
                            ],
                            cursorColor: Colors.black,
                            style: OnboardingStyles.body,
                            inputFormatters: [MobileNumberFormatter()],
                            decoration: OnboardingStyles.inputDecoration(
                                    hintText: 'XX-XXXX-XXXX')
                                .copyWith(
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 76, minHeight: 44),
                              prefixIcon: Container(
                                width: 76 *
                                    MediaQuery.textScalerOf(context).scale(14) /
                                    14,
                                height: 44,
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      right: BorderSide(color: AppColors.gray)),
                                ),
                                child: const Text('IND (+91)',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: OnboardingStyles.body),
                              ),
                            ),
                            onChanged: _validateNumber,
                            onFieldSubmitted: (_) {
                              if (isButtonEnabled) sendOTP();
                            },
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Already have an account? '),
                              Semantics(
                                button: true,
                                child: InkWell(
                                  onTap: _isSubmitting ? null : _openLogin,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('Login',
                                        style: OnboardingStyles.body
                                            .copyWith(color: AppColors.purple)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
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
            child: OnboardingButton(
              key: const Key('mobile-submit'),
              label: 'Send Code',
              loading: _isSubmitting,
              onPressed: isButtonEnabled ? sendOTP : null,
              disabledBackgroundColor: AppColors.darkGray,
              disabledForegroundColor: AppColors.lightGray,
            ),
          ),
        ],
      ),
    );
  }
}
