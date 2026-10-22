import 'dart:convert';

import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'onboarding_widgets.dart';
import 'ForgotPasswordScreen.dart';
import 'Home/HomeScreen.dart';
import 'Home/ManagerHomeScreen.dart';
import 'MobileNumberScreen.dart';
import '../Database/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _showLegalPopup('terms_and_conditions');
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _showLegalPopup('privacy_policy');

  @override
  void initState() {
    super.initState();
    initLogin().catchError((Object error) {
      CommonUtilities.showLog('Login initialization failed: $error');
    });
  }

  Future<void> initLogin() async {
    if (Firebase.apps.isEmpty) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    CommonUtilities.showLog("UID: $uid");
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final horizontalPadding = compact ? 16.0 : 24.0;
              final titleSize = 25.0;
              final fieldFontSize = compact ? 14.0 : 17.0;
              final buttonFontSize = compact ? 18.0 : 21.0;
              final otpFontSize = compact ? 18.0 : 22.0;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 0, horizontalPadding, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          Text('Login to your account',
                              style: OnboardingStyles.heading.copyWith(
                                fontSize: titleSize,
                                height: 1.12,
                              )),
                          const SizedBox(height: 12),
                          _requiredLabel('Email Address or Phone Number',
                              fontSize: compact ? 13 : 14),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 58,
                            child: TextFormField(
                              key: const Key('login-identifier'),
                              controller: emailController,
                              enabled: !_isSubmitting,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              style: _fieldTextStyle.copyWith(
                                  fontSize: fieldFontSize),
                              cursorColor: Colors.black,
                              decoration: _loginInputDecoration(
                                  'Enter your email address.'),
                            ),
                          ),
                          const SizedBox(height: 2),
                          _requiredLabel('Password',
                              fontSize: compact ? 13 : 14),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 58,
                            child: TextFormField(
                              key: const Key('login-password'),
                              controller: passwordController,
                              enabled: !_isSubmitting,
                              obscureText: !_isPasswordVisible,
                              enableSuggestions: false,
                              autocorrect: false,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              style: _fieldTextStyle.copyWith(
                                  fontSize: fieldFontSize),
                              cursorColor: Colors.black,
                              decoration:
                                  _loginInputDecoration('Enter Password')
                                      .copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  }),
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.hintColor,
                                    size: compact ? 22 : 26,
                                  ),
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ),
                          const SizedBox(height: 0),
                          Transform.translate(
                            offset: const Offset(0, -6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _link(
                                'Forgot Password?',
                                () => CommonUtilities.NavigateWithPush(
                                  context,
                                  ForgotPasswordScreen(
                                      emailId: emailController.text.trim(),
                                      client: widget.client),
                                ),
                                fontSize: compact ? 13 : 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OnboardingButton(
                            key: const Key('login-submit'),
                            label: 'Login',
                            loading: _isSubmitting,
                            fontSize: buttonFontSize,
                            minHeight: 58,
                            borderRadius: 8,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(
                                      color: AppColors.gray, height: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or',
                                    style: OnboardingStyles.body.copyWith(
                                      fontSize: compact ? 13 : 14,
                                      fontFamily: 'Satoshi',
                                    )),
                              ),
                              const Expanded(
                                  child: Divider(
                                      color: AppColors.gray, height: 1)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          OnboardingButton(
                            label: 'Login using OTP',
                            outlined: true,
                            fontSize: otpFontSize,
                            minHeight: 58,
                            borderRadius: 8,
                            onPressed: _isSubmitting ? null : _openPhoneEntry,
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('New to ACTIV? ',
                                  style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: compact ? 13 : 15,
                                    color: AppColors.darkBlack,
                                  )),
                              _link(
                                  'Create Account',
                                  () =>
                                      _openPhoneEntry(isCreatingAccount: true),
                                  fontSize: compact ? 13 : 15),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                    text:
                                        'By clicking on Login, I accept the '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style:
                                      const TextStyle(color: AppColors.purple),
                                  recognizer: _termsTap,
                                ),
                                const TextSpan(text: ' & '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style:
                                      const TextStyle(color: AppColors.purple),
                                  recognizer: _privacyTap,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: OnboardingStyles.body.copyWith(
                                fontSize: compact ? 10 : 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          DraggableOnboardingSupportMenu(
            buttonKey: const Key('login-support'),
            enabled: !_isSubmitting,
            client: widget.client,
          ),
        ],
      ),
    );
  }

  TextStyle get _fieldTextStyle => OnboardingStyles.body.copyWith(
        fontSize: 16,
        fontFamily: 'Satoshi',
        fontWeight: FontWeight.w400,
        color: AppColors.darkBlack.withValues(alpha: 0.82),
      );

  InputDecoration _loginInputDecoration(String hintText) =>
      OnboardingStyles.inputDecoration(hintText: hintText).copyWith(
        hintStyle: OnboardingStyles.body.copyWith(
          color: AppColors.hintColor.withValues(alpha: 0.55),
          fontSize: 14,
          fontFamily: 'Satoshi',
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray1, width: 1.2),
        ),
      );

  Widget _requiredLabel(String text, {double fontSize = 14}) => Text.rich(
        TextSpan(children: [
          TextSpan(text: text),
          const TextSpan(text: '*', style: TextStyle(color: AppColors.red)),
        ]),
        style: OnboardingStyles.body.copyWith(
          fontSize: fontSize,
          fontFamily: 'Satoshi',
        ),
      );

  Widget _link(String text, VoidCallback onTap, {double fontSize = 14}) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Text(text,
              style: OnboardingStyles.body.copyWith(
                color: AppColors.purple,
                fontSize: fontSize,
                fontFamily: 'Satoshi',
              )),
        ),
      ),
    );
  }

  void _openPhoneEntry({bool isCreatingAccount = false}) =>
      CommonUtilities.NavigateWithPush(
        context,
        MobileNumberScreen(
          client: widget.client,
          isCreatingAccount: isCreatingAccount,
        ),
      );

  void _submit() {
    if (!_isSubmitting && validation(context)) {
      FocusScope.of(context).unfocus();
      handleLogin();
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _syncFirebasePartnerMapping(Map<String, dynamic> data) async {
    final rawPhone = data['partner']?['phone']?.toString() ?? '';
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return false;
    final nationalNumber = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits.substring(digits.length - 10);
    final firebaseUser = FirebaseAuth.instance.currentUser ??
        (await FirebaseAuth.instance.signInAnonymously()).user;
    if (firebaseUser == null) return false;
    await SharedPreference.addStringToSF('phoneCode', 'IND (+91)');
    await SharedPreference.addStringToSF('userMobileNumber', nationalNumber);
    final synced = await AuthService().registerWithNumber(
      'IND (+91)',
      nationalNumber,
      'unknown',
      'unknown',
      'unknown',
      'unknown',
      'unknown',
      DateTime.now().toIso8601String(),
      'PartnerLogin',
    );
    return synced;
  }

  Future<void> handleLogin() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await SharedPreference.remove("jwt_token");
      await SharedPreference.remove("is_active");
      await SharedPreference.remove("user_type");
      await SharedPreference.remove("permissions");

      if (!mounted) return;

      final response = await (widget.client?.post ?? http.post)(
        Uri.parse(PARTNER_LOGIN_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text,
        }),
      );

      if (!mounted) return;

      CommonUtilities.showLog("Partner Login status: ${response.statusCode}");
      CommonUtilities.showLog("Partner Login completed: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] is Map ? body['data'] : body;
        final String token = _extractToken(body);

        // Detect login type: partner vs team member
        final bool isTeamMember = data['member'] != null ||
            data['userType'] == 'team_member' ||
            body['userType'] == 'team_member' ||
            body['member'] != null;
        final bool isPartnerActive = data['partner']?['isActive'] == true;

        if (token.isEmpty) {
          CommonUtilities.showLog(
              "Partner Login completed without an access token");
          _showMessage(context,
              'Login succeeded, but token was missing. Please try again.');
          return;
        }

        await SharedPreference.addStringToSF("jwt_token", token);

        if (!mounted) return;

        if (isTeamMember) {
          final bool isMemberActive = data['member']?['isActive'] == true;
          final Map perms = data['member']?['permissions'] ?? {};
          await SharedPreference.addStringToSF(
              "is_active", isMemberActive ? "true" : "false");
          await SharedPreference.addStringToSF("user_type", "team_member");
          await SharedPreference.addStringToSF(
              "permissions", jsonEncode(perms));
          if (!mounted) return;
          if (isMemberActive) {
            CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
                context, ManagerHomeScreen(client: widget.client));
          } else {
            _showMessage(context,
                'Your account is not active yet. Please wait for approval.');
          }
        } else if (isPartnerActive) {
          if (!await _syncFirebasePartnerMapping(data)) {
            _showMessage(context,
                'Login succeeded, but account synchronization failed. Please try again.');
            return;
          }
          await SharedPreference.addStringToSF("is_active", "true");
          await SharedPreference.addStringToSF("user_type", "partner");
          await SharedPreference.addStringToSF("permissions", "{}");
          if (!mounted) return;
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
              context, HomeScreen());
        } else {
          await SharedPreference.addStringToSF("is_active", "false");
          if (!mounted) return;
          _showMessage(context,
              'Your account is not active yet. Please wait for approval.');
        }
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Login failed. Please try again.';
        if (!mounted) return;
        _showMessage(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      CommonUtilities.showLog("Partner Login error: $e");
      _showMessage(context, 'Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  Future<void> _showLegalPopup(String type) async {
    try {
      // Refresh the local-server selection after a backend restart or hot reload.
      if (widget.client == null) await initializeApiBaseUrl();
      if (!mounted) return;
      final response =
          await (widget.client?.get ?? http.get)(Uri.parse(LEGAL_URL))
              .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> list = jsonDecode(response.body) is List
            ? jsonDecode(response.body)
            : (jsonDecode(response.body)['data'] ?? []);

        Map<String, dynamic>? item;
        for (final entry in list) {
          if (entry is Map<String, dynamic> && entry['type'] == type) {
            item = entry;
            break;
          }
        }

        if (!mounted) return;

        final String title = item?['title']?.toString() ??
            (type == 'terms_and_conditions'
                ? 'Terms & Conditions'
                : 'Privacy Policy');
        final String raw =
            item?['content']?.toString() ?? 'Content not available.';
        final String content = raw
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            backgroundColor: AppColors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              OnboardingStyles.heading.copyWith(fontSize: 18),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close,
                            color: AppColors.darkBlack, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.gray),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Text(
                      content,
                      style: OnboardingStyles.body.copyWith(height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _showMessage(context, 'Failed to load content. Please try again.');
      }
    } catch (e) {
      CommonUtilities.showLog('Legal content request failed ($LEGAL_URL): $e');
      if (!mounted) return;
      _showMessage(context, 'Network error. Please check your connection.');
    }
  }

  bool validation(BuildContext context) {
    final identifier = emailController.text.trim();
    final password = passwordController.text;
    final phoneDigits = identifier.replaceAll(RegExp(r'\D'), '');
    final isEmail = CommonUtilities.emailVaidatation(identifier);
    final isPhone = phoneDigits.length == 10 || phoneDigits.length == 12;

    if (identifier.isEmpty) {
      _showMessage(context, 'Please enter email address or phone number.');
      return false;
    } else if (!isEmail && !isPhone) {
      _showMessage(
          context, 'Please enter a valid email address or phone number.');
      return false;
    } else if (password.isEmpty) {
      _showMessage(context, ConstantsMessages.passwordEnter);
      return false;
    }
    return true;
  }
}
