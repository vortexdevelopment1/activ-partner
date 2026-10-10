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
import 'MobileNumberScreen.dart';

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
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OnboardingLogo(),
                    const SizedBox(height: 40),
                    const Text('Login to your account',
                        style: OnboardingStyles.heading),
                    const SizedBox(height: 26),
                    _requiredLabel('Email Address or Phone Number'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('login-identifier'),
                      controller: emailController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      style: OnboardingStyles.body,
                      cursorColor: Colors.black,
                      decoration: OnboardingStyles.inputDecoration(),
                    ),
                    const SizedBox(height: 26),
                    _requiredLabel('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: passwordController,
                      enabled: !_isSubmitting,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      style: OnboardingStyles.body,
                      cursorColor: Colors.black,
                      decoration: OnboardingStyles.inputDecoration(),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _link(
                        'Forgot Password?',
                        () => CommonUtilities.NavigateWithPush(
                          context,
                          ForgotPasswordScreen(
                              emailId: emailController.text.trim(),
                              client: widget.client),
                        ),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 32),
                    OnboardingButton(
                      key: const Key('login-submit'),
                      label: 'Login',
                      loading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 32),
                    const Row(
                      children: [
                        Expanded(
                            child: Divider(color: AppColors.gray, height: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or'),
                        ),
                        Expanded(
                            child: Divider(color: AppColors.gray, height: 1)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    OnboardingButton(
                      label: 'Login using OTP',
                      outlined: true,
                      onPressed: _isSubmitting ? null : _openPhoneEntry,
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('New to ACTIV? ',
                            style: TextStyle(fontSize: 12)),
                        _link('Create Account', _openPhoneEntry, fontSize: 12),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OnboardingSupportMenu(
                        buttonKey: const Key('login-support'),
                        enabled: !_isSubmitting,
                        client: widget.client,
                      ),
                    ),
                    const SizedBox(height: 42),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                              text: 'By clicking on Login, I accept the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: const TextStyle(color: AppColors.purple),
                            recognizer: _termsTap,
                          ),
                          const TextSpan(text: ' &\n'),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(color: AppColors.purple),
                            recognizer: _privacyTap,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: OnboardingStyles.body
                          .copyWith(fontSize: 12, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _requiredLabel(String text) => Text.rich(
        TextSpan(children: [
          TextSpan(text: text),
          const TextSpan(text: '*', style: TextStyle(color: AppColors.red)),
        ]),
        style: OnboardingStyles.body.copyWith(fontSize: 14),
      );

  Widget _link(String text, VoidCallback onTap, {double fontSize = 14}) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(text,
              style: OnboardingStyles.body
                  .copyWith(color: AppColors.purple, fontSize: fontSize)),
        ),
      ),
    );
  }

  void _openPhoneEntry() =>
      CommonUtilities.NavigateWithPush(context, const MobileNumberScreen());

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
      CommonUtilities.showLog("Partner Login response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        final String token = _extractToken(body);

        // Detect login type: partner vs team member
        final bool isTeamMember = data['member'] != null;
        final bool isPartnerActive = data['partner']?['isActive'] == true;

        if (token.isEmpty) {
          CommonUtilities.showLog(
              "Partner Login missing token. Response: ${response.body}");
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
                context, HomeScreen());
          } else {
            _showMessage(context,
                'Your account is not active yet. Please wait for approval.');
          }
        } else if (isPartnerActive) {
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
