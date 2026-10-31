import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/password_reset_service.dart';
import 'ResetPasswordScreen.dart';
import 'onboarding_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.emailId, this.client});
  final String emailId;
  final http.Client? client;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text:
        CommonUtilities.emailVaidatation(widget.emailId) ? widget.emailId : '',
  );
  bool _loading = false;
  String? _emailError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _emailError = null;
    });
    try {
      await PasswordResetService(widget.client).sendCode(_email.text.trim());
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ResetPasswordScreen(
            emailId: _email.text.trim(), client: widget.client),
      ));
    } on PasswordResetException catch (error) {
      if (mounted) {
        if ([400, 403, 404].contains(error.statusCode)) {
          setState(() => _emailError = error.message);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Forgot Password',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 25,
                    height: 1.15,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 18),
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Email Address'),
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
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 58),
                  child: TextFormField(
                    key: const Key('forgot-email'),
                    controller: _email,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    style: OnboardingStyles.body.copyWith(fontSize: 18),
                    decoration: OnboardingStyles.inputDecoration(
                      hintText: 'Enter your email address.',
                    ).copyWith(
                      errorText: _emailError,
                      errorMaxLines: 3,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 19,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.gray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.gray1),
                      ),
                    ),
                    validator: (value) =>
                        CommonUtilities.emailVaidatation(value?.trim() ?? '')
                            ? null
                            : 'Enter a valid email address.',
                    onFieldSubmitted: (_) => _sendCode(),
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 28),
                OnboardingButton(
                  key: const Key('forgot-send'),
                  label: 'Send OTP',
                  loading: _loading,
                  onPressed: _sendCode,
                  fontSize: 16,
                  minHeight: 58,
                  borderRadius: 14,
                ),
                const SizedBox(height: 32),
                OnboardingButton(
                  label: 'Back to Login',
                  outlined: true,
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  fontSize: 16,
                  minHeight: 58,
                  borderRadius: 14,
                ),
              ],
            ),
          ),
        ),
      );
}
