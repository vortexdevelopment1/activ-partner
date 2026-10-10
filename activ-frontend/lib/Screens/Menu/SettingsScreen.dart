import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../Style/app_colors.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../GetStartedScreen.dart';
import '../StringExtensions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.client});

  final http.Client? client;

  @override
  Widget build(BuildContext context) {
    return _AppScaffold(
      title: 'App Controls',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
        children: [
          _ControlTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your account password securely',
            onTap: () => CommonUtilities.NavigateWithPush(
              context,
              ChangePasswordScreen(client: client),
            ),
          ),
          const SizedBox(height: 18),
          _ControlTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Preferences',
            subtitle: 'Manage booking and payments alerts',
            onTap: () => CommonUtilities.NavigateWithPush(
              context,
              NotificationPreferencesScreen(client: client),
            ),
          ),
          const SizedBox(height: 18),
          _ControlTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            titleColor: AppColors.red,
            onTap: () => _showDeleteAccountSheet(context, client),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNext = true;
  bool _hideConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final response = await (widget.client?.patch ?? http.patch)(
        Uri.parse(CHANGE_PARTNER_PASSWORD_URL),
        headers: _authJsonHeaders(token),
        body: jsonEncode({
          'currentPassword': _current.text,
          'newPassword': _next.text,
        }),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromResponse(response.body) ??
            'Unable to update password. Please try again.');
      }
      _current.clear();
      _next.clear();
      _confirm.clear();
      CommonUtilities.createSnackBar(context, 'Password updated successfully');
    } catch (e) {
      if (mounted) CommonUtilities.createSnackBar(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AppScaffold(
      title: 'Change Password',
      footer: _PrimaryButton(
        text: _saving ? 'Updating...' : 'Update Password',
        onPressed: _saving ? null : _save,
      ),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PasswordField(
                label: 'Current Password',
                controller: _current,
                obscure: _hideCurrent,
                onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
                validator: _requiredPassword,
                showInfo: true,
              ),
              const SizedBox(height: 24),
              _PasswordField(
                label: 'New Password',
                controller: _next,
                obscure: _hideNext,
                onToggle: () => setState(() => _hideNext = !_hideNext),
                validator: _strongPassword,
              ),
              const SizedBox(height: 24),
              _PasswordField(
                label: 'Confirm New Password',
                controller: _confirm,
                obscure: _hideConfirm,
                onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                validator: (value) {
                  if (checkString(value).isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _next.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 46),
              const Text(
                'Password must contain:',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkBlack,
                ),
              ),
              const SizedBox(height: 14),
              const _BulletText('At least 8 characters'),
              const _BulletText('One uppercase letter'),
              const _BulletText('One number'),
              const _BulletText('One special character'),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredPassword(String? value) =>
      checkString(value).isEmpty ? 'Please enter your password' : null;

  String? _strongPassword(String? value) {
    final password = checkString(value);
    if (password.isEmpty) return 'Please enter a new password';
    if (!CommonUtilities.passwordVaidatation(password)) {
      return 'Use uppercase, lowercase, number and special character';
    }
    return null;
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _enableAll = true;
  bool _booking = true;
  bool _payments = true;
  bool _approval = true;
  bool _promo = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(NOTIFICATION_PREFERENCES_URL),
        headers: _authJsonHeaders(token),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body)['data'] ?? {};
        if (!mounted) return;
        setState(() {
          _enableAll = data['enableAllNotifications'] ?? true;
          _booking = data['bookingNotifications'] ?? true;
          _payments = data['paymentUpdates'] ?? true;
          _approval = data['approvalUpdates'] ?? true;
          _promo = data['promotionalMessages'] ?? false;
        });
      }
    } catch (e) {
      CommonUtilities.showLog('notification preferences load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final response = await (widget.client?.patch ?? http.patch)(
        Uri.parse(NOTIFICATION_PREFERENCES_URL),
        headers: _authJsonHeaders(token),
        body: jsonEncode({
          'enableAllNotifications': _enableAll,
          'bookingNotifications': _booking,
          'paymentUpdates': _payments,
          'approvalUpdates': _approval,
          'promotionalMessages': _promo,
        }),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromResponse(response.body) ??
            'Unable to save preferences. Please try again.');
      }
      await _showSavedDialog(context);
    } catch (e) {
      if (mounted) CommonUtilities.createSnackBar(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setAll(bool value) {
    setState(() {
      _enableAll = value;
      _booking = value;
      _payments = value;
      _approval = value;
      _promo = value;
    });
  }

  void _setChild(void Function() update) {
    setState(() {
      update();
      _enableAll = _booking && _payments && _approval && _promo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AppScaffold(
      title: 'Notifications Preferences',
      footer: _PrimaryButton(
        text: _saving ? 'Saving...' : 'Save Preferences',
        onPressed: _saving ? null : _save,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SwitchCard(
                  title: 'Enable all notifications',
                  subtitle: 'Turn on all notifications categories',
                  value: _enableAll,
                  onChanged: _setAll,
                ),
                const SizedBox(height: 26),
                const Divider(color: Color(0xFFD5DEB4), height: 1),
                const SizedBox(height: 26),
                const Text(
                  'Type of Notification',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 18),
                _SwitchCard(
                  icon: Icons.event_available_outlined,
                  title: 'Booking notification',
                  subtitle: 'Get alert for new bookings,\nupdate and cancellations',
                  value: _booking,
                  onChanged: (value) => _setChild(() => _booking = value),
                ),
                const SizedBox(height: 14),
                _SwitchCard(
                  icon: Icons.currency_rupee_rounded,
                  title: 'Payment updates',
                  subtitle: 'Receive payment success,\nfailures and refund alerts',
                  value: _payments,
                  onChanged: (value) => _setChild(() => _payments = value),
                ),
                const SizedBox(height: 14),
                _SwitchCard(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Approval updates',
                  subtitle: 'Get notified for activity and\nlisting approvals',
                  value: _approval,
                  onChanged: (value) => _setChild(() => _approval = value),
                ),
                const SizedBox(height: 14),
                _SwitchCard(
                  icon: Icons.local_offer_outlined,
                  title: 'Promotional Messages',
                  subtitle: 'Receive offers and product\nupdates',
                  value: _promo,
                  onChanged: (value) => _setChild(() => _promo = value),
                ),
              ],
              ),
            ),
    );
  }
}

class _AppScaffold extends StatelessWidget {
  const _AppScaffold({required this.title, required this.child, this.footer});

  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF0F7D2),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7D2),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: Colors.black12,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.darkBlack),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 28),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor = AppColors.darkBlack,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
          child: Row(
            children: [
              _IconBox(icon),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                        height: 1.25,
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.darkBlack, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
      child: Row(
        children: [
          if (icon != null) ...[
            _IconBox(icon!, size: 46, iconSize: 27),
            const SizedBox(width: 18),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.15,
                    color: AppColors.darkBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.2,
                    color: AppColors.darkBlack,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: .82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFD8F34A),
              activeTrackColor: AppColors.darkBlack,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF6A6A6A),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {this.size = 58, this.iconSize = 32});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.black, size: iconSize),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.validator,
    this.showInfo = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final bool showInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: AppColors.darkBlack,
              ),
            ),
            const Text('*', style: TextStyle(color: AppColors.red)),
            if (showInfo) ...[
              const SizedBox(width: 6),
              const Icon(Icons.info_outline, size: 18),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: AppColors.darkBlack, size: 28),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.darkBlack,
                size: 28,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.darkBlack),
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.darkBlack,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: AppColors.darkBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: const Color(0xFFD8F34A),
          disabledBackgroundColor: Colors.black54,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
      ),
    );
  }
}

Future<void> _showSavedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 70, 34, 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFF70B842),
              child: Icon(Icons.check, color: Colors.white, size: 58),
            ),
            const SizedBox(height: 32),
            const Text(
              'Preferences Saved!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 23,
                color: Color(0xFF70B842),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You will now receive notifications as per\nyour preferences.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.35,
                color: Color(0xFF5B5B5B),
              ),
            ),
            const SizedBox(height: 42),
            _PrimaryButton(
              text: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showDeleteAccountSheet(BuildContext context, http.Client? client) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _DeleteAccountSheet(client: client),
  );
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({this.client});

  final http.Client? client;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final response = await (widget.client?.delete ?? http.delete)(
        Uri.parse(DELETE_PARTNER_ACCOUNT_URL),
        headers: _authJsonHeaders(token),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromResponse(response.body) ??
            'Unable to delete account. Please try again.');
      }
      await FirebaseAuth.instance.signOut();
      await SharedPreference.clearSF();
      if (mounted) {
        CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
          context,
          GetStartedScreen(),
        );
      }
    } catch (e) {
      if (mounted) CommonUtilities.createSnackBar(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0F7D2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 34),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFD8F34A),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Delete Account',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppColors.darkBlack,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Are you sure you want to permanently delete your account?\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                height: 1.35,
                color: AppColors.darkBlack,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 58,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _deleting ? null : _delete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.red.withOpacity(.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _deleting ? 'Deleting...' : 'Delete',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 58,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkBlack,
                  side: const BorderSide(color: AppColors.darkBlack),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, String> _authJsonHeaders(String token) => {
      'accept': '*/*',
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

String? _messageFromResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    final message = decoded['message'];
    if (message is List) return message.join('\n');
    return checkString(message).isEmpty ? null : checkString(message);
  } catch (_) {
    return null;
  }
}

String _cleanError(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
