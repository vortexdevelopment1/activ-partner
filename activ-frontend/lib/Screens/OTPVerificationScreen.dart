import 'dart:async';
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
import 'MobileNumberScreen.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({
    super.key,
    this.client,
    this.isCreatingAccount = false,
  });

  final http.Client? client;
  final bool isCreatingAccount;

  @override
  State<OTPVerificationScreen> createState() => _State();
}

class _State extends State<OTPVerificationScreen> {
  final int otpLength = 4;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  String phoneCode = "", userMobileNumber = "", enterOTP = "";

  bool _isSubmitting = false;
  bool _isResending = false;
  int _resendSeconds = 40;
  Timer? _resendTimer;

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
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendSeconds = 40;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds == 0) timer.cancel();
    });
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 ||
        _isResending ||
        _isSubmitting ||
        userMobileNumber.isEmpty) {
      return;
    }
    setState(() => _isResending = true);
    try {
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse(REQUEST_OTP_URL),
        headers: {'accept': '*/*', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': userMobileNumber.replaceAll(RegExp(r'\D'), ''),
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        for (final controller in _controllers) {
          controller.clear();
        }
        _startResendCountdown();
        _focusNodes.first.requestFocus();
        _showMessage(context, 'OTP sent successfully.');
      } else {
        final body = jsonDecode(response.body);
        _showMessage(
            context,
            body['message']?.toString() ??
                'Failed to resend OTP. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context, 'Network error. Please check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _editNumber() {
    if (_isSubmitting || _isResending) return;
    FocusScope.of(context).unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => MobileNumberScreen(
          client: widget.client,
          isCreatingAccount: widget.isCreatingAccount,
        ),
      ));
    }
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

  String get _formattedPhone {
    final digits = userMobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final prefix = phoneCode.isEmpty
        ? ''
        : '${phoneCode.startsWith('+') ? phoneCode : '+$phoneCode'}-';
    final number = digits.length == 10
        ? '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6)}'
        : digits;
    return '$prefix$number';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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
    if (_controllers.every((controller) =>
        RegExp(r'^\d$').hasMatch(controller.text))) {
      _submit();
    }
  }

  void _submit() {
    if (!_isSubmitting && !_isResending && validation(context)) {
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
        Uri.parse('$VERIFY_OTP_URL?intent=${widget.isCreatingAccount ? 'register' : 'login'}'),
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
        if (!isProfileComplete || (widget.isCreatingAccount && !isUserActive)) {
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
        final String firstVenueName =
            items.isNotEmpty ? (items.first['name']?.toString() ?? '') : '';

        if (total == 1 && firstStatus == 'pending') {
          if (firstVenueId.isNotEmpty) {
            await SharedPreference.addStringToSF("venue_id", firstVenueId);
          }
          if (firstVenueName.isNotEmpty) {
            await SharedPreference.addStringToSF("venue_name", firstVenueName);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Verify your number',
                    style: OnboardingStyles.heading),
                const SizedBox(height: 6),
                Text(
                  'We sent a code to $_formattedPhone',
                  key: const Key('otp-phone'),
                  style: OnboardingStyles.body
                      .copyWith(fontSize: 16, color: AppColors.black1),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  const SizedBox(height: 32),
                  const Text('Enter the 4 digit one-time code'),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final boxSize =
                        (constraints.maxWidth / 6.6).clamp(40.0, 50.0);
                    final gap = ((constraints.maxWidth - boxSize * otpLength) /
                            (otpLength - 1))
                        .clamp(0.0, 20.0);
                    return Row(
                        children: List.generate(otpLength, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                            right: index == otpLength - 1 ? 0 : gap),
                        child: SizedBox(
                          width: boxSize,
                          height: boxSize,
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
                              enabled: !_isSubmitting && !_isResending,
                              textAlign: TextAlign.center,
                              expands: true,
                              maxLines: null,
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
                              style:
                                  OnboardingStyles.body.copyWith(fontSize: 24),
                              cursorColor: AppColors.purple,
                              decoration:
                                  OnboardingStyles.inputDecoration().copyWith(
                                contentPadding: EdgeInsets.zero,
                                constraints:
                                    BoxConstraints.tightFor(height: boxSize),
                                filled: false,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.gray1, width: 2),
                                ),
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (value) =>
                                  onChangedValue(value, index),
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ),
                      );
                    }));
                  }),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _resendSeconds > 0
                        ? Text('Resend OTP in ${_resendSeconds}s',
                            key: const Key('otp-countdown'))
                        : TextButton(
                            key: const Key('otp-resend'),
                            onPressed: _isResending || _isSubmitting
                                ? null
                                : _resendOtp,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.darkBlack,
                              textStyle: OnboardingStyles.body,
                            ),
                            child: Text(
                                _isResending ? 'Sending OTP...' : 'Resend OTP'),
                          ),
                  ),
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
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: TextButton(
                    key: const Key('otp-edit-number'),
                    onPressed:
                        _isSubmitting || _isResending ? null : _editNumber,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.darkBlack,
                      textStyle: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 18,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    child: const Text(
                      'Edit Number',
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                    ),
                  )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 7,
                  child: OnboardingButton(
                    key: const Key('otp-submit'),
                    label: 'Verify',
                    loading: _isSubmitting,
                    onPressed: _isResending ? null : _submit,
                  )),
            ]),
          ),
        ],
      ),
    );
  }
}
