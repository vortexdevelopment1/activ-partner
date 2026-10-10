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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await PasswordResetService(widget.client).sendCode(_email.text.trim());
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ResetPasswordScreen(
            emailId: _email.text.trim(), client: widget.client),
      ));
    } on PasswordResetException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingLogo(),
                  const SizedBox(height: 40),
                  const Text('Forgot password?',
                      style: OnboardingStyles.heading),
                  const SizedBox(height: 6),
                  Text(
                      "Enter your email address and we'll send you a verification code to reset your password",
                      style: OnboardingStyles.body
                          .copyWith(fontSize: 16, height: 1.4)),
                  const SizedBox(height: 26),
                  const Text.rich(TextSpan(children: [
                    TextSpan(text: 'Email Address'),
                    TextSpan(text: '*', style: TextStyle(color: AppColors.red)),
                  ])),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('forgot-email'),
                    controller: _email,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    style: OnboardingStyles.body,
                    decoration: OnboardingStyles.inputDecoration(),
                    validator: (value) =>
                        CommonUtilities.emailVaidatation(value?.trim() ?? '')
                            ? null
                            : 'Enter a valid email address.',
                    onFieldSubmitted: (_) => _sendCode(),
                  ),
                  const SizedBox(height: 24),
                  OnboardingButton(
                      key: const Key('forgot-send'),
                      label: 'Send Code',
                      loading: _loading,
                      onPressed: _sendCode),
                  const SizedBox(height: 16),
                  Center(
                      child: TextButton.icon(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text('Back to Login'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.purple,
                        textStyle: OnboardingStyles.body),
                  )),
                ]),
          ),
        ),
      );
}
