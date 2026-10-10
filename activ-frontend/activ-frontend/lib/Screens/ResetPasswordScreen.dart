import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../api_calling/password_reset_service.dart';
import 'LoginScreen.dart';
import 'onboarding_widgets.dart';

enum _ResetStep { verify, password, success }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.emailId, this.client});
  final String emailId;
  final http.Client? client;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _ResetStep _step = _ResetStep.verify;
  bool _loading = false;
  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _backToLogin() => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => LoginScreen(client: widget.client)),
        (_) => false,
      );

  Future<void> _submit({bool resend = false}) async {
    if (_loading || (resend && _resendSeconds > 0)) return;
    if (!resend && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final service = PasswordResetService(widget.client);
    try {
      if (resend) {
        await service.sendCode(widget.emailId);
        if (!mounted) return;
        _code.clear();
        _startCooldown();
        _message('A new verification code has been sent to your email.');
      } else if (_step == _ResetStep.verify) {
        await service.verifyCode(widget.emailId, _code.text.trim());
        if (!mounted) return;
        setState(() => _step = _ResetStep.password);
      } else {
        await service.resetPassword(
            widget.emailId, _code.text.trim(), _password.text);
        if (!mounted) return;
        _timer?.cancel();
        _password.clear();
        _confirm.clear();
        setState(() => _step = _ResetStep.success);
      }
    } on PasswordResetException catch (error) {
      if (!mounted) return;
      if (!resend && _step == _ResetStep.password && error.invalidCode) {
        setState(() => _step = _ResetStep.verify);
        _code.clear();
      }
      _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _label(String text) => Text.rich(TextSpan(children: [
        TextSpan(text: text),
        const TextSpan(text: '*', style: TextStyle(color: AppColors.red)),
      ]));

  Widget _passwordField(TextEditingController controller, String key,
          {bool confirm = false}) =>
      TextFormField(
        key: Key(key),
        controller: controller,
        enabled: !_loading,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: confirm ? TextInputAction.done : TextInputAction.next,
        style: OnboardingStyles.body,
        decoration: OnboardingStyles.inputDecoration(),
        validator: (value) {
          if (value == null || value.length < 6) {
            return 'Password must be at least 6 characters.';
          }
          if (confirm && value != _password.text) {
            return 'Passwords do not match.';
          }
          return null;
        },
        onFieldSubmitted: confirm ? (_) => _submit() : null,
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_loading && _step != _ResetStep.success,
        onPopInvokedWithResult: (popped, _) {
          if (!popped && !_loading && _step == _ResetStep.success) {
            _backToLogin();
          }
        },
        child: OnboardingScaffold(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OnboardingLogo(),
                  if (_step == _ResetStep.success) ...[
                    const SizedBox(height: 61),
                    Center(
                        child: Image.asset('assets/password_reset_success.png',
                            width: 130,
                            height: 130,
                            semanticLabel: 'Password reset successful')),
                    const SizedBox(height: 76),
                    Text.rich(
                        TextSpan(children: [
                          WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Image.asset(
                                  'assets/password_reset_confetti.png',
                                  width: 30,
                                  height: 34)),
                          const TextSpan(
                              text:
                                  ' Your password has been reset successfully!'),
                        ]),
                        textAlign: TextAlign.center,
                        style: OnboardingStyles.heading.copyWith(height: 1.35)),
                    const SizedBox(height: 14),
                    const Text('You can now log in with your new password.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 56),
                    OnboardingButton(label: 'Login', onPressed: _backToLogin),
                  ] else ...[
                    const SizedBox(height: 40),
                    Text(
                        _step == _ResetStep.verify
                            ? 'Verify code'
                            : 'Reset password',
                        style: OnboardingStyles.heading),
                    const SizedBox(height: 6),
                    Text(
                        _step == _ResetStep.verify
                            ? 'Enter the verification code sent to your email'
                            : 'Set a new password for your account',
                        style: OnboardingStyles.body
                            .copyWith(fontSize: 16, height: 1.4)),
                    const SizedBox(height: 26),
                    Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_step == _ResetStep.verify) ...[
                              _label('Verification Code'),
                              const SizedBox(height: 6),
                              TextFormField(
                                key: const Key('reset-code'),
                                controller: _code,
                                enabled: !_loading,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6)
                                ],
                                style: OnboardingStyles.body,
                                decoration: OnboardingStyles.inputDecoration(),
                                validator: (value) => RegExp(r'^\d{4,6}$')
                                        .hasMatch(value ?? '')
                                    ? null
                                    : 'Enter the verification code from your email.',
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ] else ...[
                              _label('New Password'),
                              const SizedBox(height: 6),
                              _passwordField(_password, 'reset-password'),
                              const SizedBox(height: 26),
                              _label('Confirm Password'),
                              const SizedBox(height: 6),
                              _passwordField(_confirm, 'reset-confirm',
                                  confirm: true),
                            ],
                          ]),
                    ),
                    const SizedBox(height: 24),
                    OnboardingButton(
                        key: const Key('reset-submit'),
                        label: _step == _ResetStep.verify
                            ? 'Verify Code'
                            : 'Reset Password',
                        loading: _loading,
                        onPressed: () => _submit()),
                    if (_step == _ResetStep.verify) ...[
                      const SizedBox(height: 16),
                      Center(
                          child: TextButton(
                        onPressed: _loading || _resendSeconds > 0
                            ? null
                            : () => _submit(resend: true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.purple,
                            disabledForegroundColor: AppColors.purple,
                            textStyle: OnboardingStyles.body),
                        child: Text(_resendSeconds > 0
                            ? "Didn't receive code? Resend (${_resendSeconds}s)"
                            : "Didn't receive code? Resend"),
                      )),
                      const SizedBox(height: 4),
                    ] else
                      const SizedBox(height: 16),
                    Center(
                        child: TextButton.icon(
                      onPressed: _loading ? null : _backToLogin,
                      icon: const Icon(Icons.arrow_back, size: 14),
                      label: const Text('Back to Login'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.purple,
                          textStyle: OnboardingStyles.body),
                    )),
                  ],
                ]),
          ),
        ),
      );
}
