import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'onboarding_widgets.dart';
import 'ContactSupportScreen.dart';
import 'Home/HomeScreen.dart';
import 'TellUsAboutScreen.dart';
import 'VenueScreen.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<OTPVerificationScreen> createState() => _State();
}

class _State extends State<OTPVerificationScreen> {
  final int otpLength = 4;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  String phoneCode = "", userMobileNumber = "", enterOTP = "";

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < otpLength; i++) {
      _controllers.add(TextEditingController());
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          _controllers[i].selection = TextSelection(
              baseOffset: 0, extentOffset: _controllers[i].text.length);
        }
      });
      _focusNodes.add(node);
    }
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    final code = await SharedPreference.readStr('phoneCode') ?? '';
    final number = await SharedPreference.readStr('userMobileNumber') ?? '';
    if (!mounted) return;
    setState(() {
      phoneCode = code;
      userMobileNumber = number;
    });
  }

  String get _maskedPhone {
    final digits = userMobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final suffix =
        digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    final prefix = phoneCode.isEmpty
        ? ''
        : '${phoneCode.startsWith('+') ? phoneCode : '+$phoneCode'}-';
    return '${prefix}xx-xxxx-$suffix';
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
    if (value.length > 1) {
      // A complete pasted code replaces all four boxes, regardless of focus.
      final start = value.length == otpLength ? 0 : index;
      final count = value.length.clamp(0, otpLength - start);
      for (int i = 0; i < count; i++) {
        _controllers[start + i].text = value[i];
      }
      _focusNodes[(start + count).clamp(0, otpLength - 1)].requestFocus();
    } else if (value.isNotEmpty && index < otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _submit() {
    if (!_isSubmitting && validation(context)) {
      FocusScope.of(context).unfocus();
      handleOTP();
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> handleOTP() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    String enteredOTP = _controllers.map((c) => c.text).join();
    String mobile = userMobileNumber.replaceAll("-", "");

    try {
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse(VERIFY_OTP_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"phone": mobile, "otp": enteredOTP}),
      );

      if (!mounted) return;

      CommonUtilities.showLog("Verify OTP status: ${response.statusCode}");
      CommonUtilities.showLog("Verify OTP response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final String token = _extractToken(body);
        final bool isProfileComplete =
            body['data']?['isProfileComplete'] == true;
        final bool isUserActive = body['data']?['partner']?['isActive'] == true;

        if (token.isEmpty) {
          CommonUtilities.showLog(
              "Verify OTP missing token. Response: ${response.body}");
          _showMessage(context,
              'OTP verified, but login token was missing. Please try again.');
          return;
        }

        await SharedPreference.addStringToSF("jwt_token", token);
        await SharedPreference.addStringToSF(
            "is_profile_complete", isProfileComplete ? "true" : "false");
        await SharedPreference.addStringToSF(
            "is_active", isUserActive ? "true" : "false");

        if (!mounted) return;
        if (!isProfileComplete) {
          CommonUtilities.NavigateWithPush(context, TellUsAboutScreen());
        } else if (!isUserActive) {
          await _checkVenueAndNavigate(token);
        } else {
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
              context, HomeScreen());
        }
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Invalid OTP. Please try again.';
        if (!mounted) return;
        _showMessage(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      CommonUtilities.showLog("Verify OTP error: $e");
      _showMessage(context, 'Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _checkVenueAndNavigate(String token) async {
    try {
      final response = await (widget.client?.get ?? http.get)(
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
        final List items =
            (data?['items'] ?? data?['venues'] ?? data?['data'] ?? []) as List;
        final String firstStatus =
            items.isNotEmpty ? (items.first['status']?.toString() ?? '') : '';
        final String firstVenueId =
            items.isNotEmpty ? (items.first['id']?.toString() ?? '') : '';

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

  bool validation(BuildContext context) {
    enterOTP = _controllers.map((c) => c.text).join();

    if (enterOTP.isEmpty) {
      _showMessage(context, ConstantsMessages.enterOTP);
      return false;
    } else if (enterOTP.length != otpLength) {
      _showMessage(context, ConstantsMessages.enterOTP);
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
    return OnboardingScaffold(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingLogo(),
                  const SizedBox(height: 16),
                  const Text('Verify your number',
                      style: OnboardingStyles.heading),
                  const SizedBox(height: 6),
                  Text(
                    'We sent a code to $_maskedPhone',
                    key: const Key('otp-phone'),
                    style: OnboardingStyles.body
                        .copyWith(fontSize: 16, color: AppColors.black1),
                  ),
                  const SizedBox(height: 32),
                  const Text('Enter the 4 digit one-time code'),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final gap = ((constraints.maxWidth - 44 * otpLength) /
                            (otpLength - 1))
                        .clamp(0.0, 20.0);
                    return Row(
                        children: List.generate(otpLength, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                            right: index == otpLength - 1 ? 0 : gap),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Focus(
                            onKeyEvent: (_, event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.backspace &&
                                  _controllers[index].text.isEmpty &&
                                  index > 0) {
                                _controllers[index - 1].clear();
                                _focusNodes[index - 1].requestFocus();
                                setState(() {});
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              key: Key('otp-digit-$index'),
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              enabled: !_isSubmitting,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: index == otpLength - 1
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              autofillHints: index == 0
                                  ? const [AutofillHints.oneTimeCode]
                                  : null,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(otpLength),
                              ],
                              style: OnboardingStyles.body,
                              cursorColor: AppColors.gray1,
                              decoration:
                                  OnboardingStyles.inputDecoration().copyWith(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (value) =>
                                  onChangedValue(value, index),
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ),
                      );
                    }));
                  }),
                ],
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
              key: const Key('otp-submit'),
              label: 'Verify',
              loading: _isSubmitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
