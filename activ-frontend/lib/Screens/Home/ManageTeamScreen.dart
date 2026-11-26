import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../Style/app_colors.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../StringExtensions.dart';

class ManageTeamScreen extends StatefulWidget {
  const ManageTeamScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<ManageTeamScreen> createState() => _ManageTeamScreenState();
}

class _RoleOption {
  const _RoleOption(this.label, this.value);

  final String label;
  final String value;
}

class _TeamMember {
  _TeamMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.bookingManagement,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String status;
  final String createdAt;
  final bool bookingManagement;

  factory _TeamMember.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'] is Map<String, dynamic>
        ? json['permissions'] as Map<String, dynamic>
        : <String, dynamic>{};
    final role = checkString(json['role']);
    final status = checkString(json['status']);

    return _TeamMember(
      id: checkString(json['id']),
      name: checkString(json['fullName'] ?? json['name']),
      phone: checkString(json['phone']),
      role: role.isEmpty ? 'staff' : role,
      status: status.isEmpty ? 'invite_sent' : status,
      createdAt: _formatDate(checkString(json['createdAt'])),
      bookingManagement: permissions['bookingManagement'] == true,
    );
  }

  static String smsSummary(Map delivery) {
    if (delivery['smsUnavailableReason'] == 'password_template_requires_new_account') {
      return 'unavailable for existing accounts/resends';
    }
    return delivery['smsSent'] == true ? 'accepted; delivery unconfirmed' : 'not confirmed';
  }

  static String _formatDate(String value) {
    if (value.isEmpty) return _todayLabel();
    try {
      final date = DateTime.parse(value).toLocal();
      return _formatDateParts(date.day, date.month, date.year);
    } catch (_) {
      return value;
    }
  }

  static String _todayLabel() {
    final now = DateTime.now();
    return _formatDateParts(now.day, now.month, now.year);
  }

  static String _formatDateParts(int day, int month, int year) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '$day ${months[month - 1]} $year';
  }

  String get roleLabel => _ManageTeamScreenState.roleLabelFor(role);

  String get statusLabel {
    if (status.toLowerCase() == 'active') return 'Active';
    if (status.toLowerCase() == 'invite_pending') return 'Invite Pending';
    return 'Invite Sent';
  }
}

class _ManageTeamScreenState extends State<ManageTeamScreen> {
  static const Color _background = Color(0xFFF0F7D2);
  static const Color _ink = Color(0xFF1F1F1F);
  static const Color _muted = Color(0xFF7F7F7F);
  static const Color _line = Color(0xFFE2E8E6);
  static const Color _purpleSoft = Color(0xFFF1E6FF);

  static const List<_RoleOption> _roles = [
    _RoleOption('Manager', 'manager'),
    _RoleOption('Receptionist', 'receptionist'),
    _RoleOption('Trainer', 'trainer'),
    _RoleOption('Staff', 'staff'),
    _RoleOption('Floor Manager', 'floor_manager'),
    _RoleOption('Security', 'security'),
  ];

  final List<_TeamMember> _members = [];
  bool _loading = true;
  String? _loadError;

  static String roleLabelFor(String value) {
    final normalized = value.toLowerCase();
    for (final role in _roles) {
      if (role.value == normalized) return role.label;
    }
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadMembers() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(TEAM_URL),
        headers: await _authHeaders(),
      );
      CommonUtilities.showLog('GET team ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final rawData = decoded is List ? decoded : decoded['data'];
        final data = rawData is List ? rawData : <dynamic>[];
        final nextMembers = data
            .whereType<Map<String, dynamic>>()
            .map(_TeamMember.fromJson)
            .toList();

        if (!mounted) return;
        setState(() {
          _members
            ..clear()
            ..addAll(nextMembers);
          _loadError = null;
        });
      } else {
        if (mounted) setState(() => _loadError = 'Unable to load team members');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team load error: $error');
      if (mounted) {
        setState(() => _loadError = 'Unable to load team members');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMember(_TeamMemberFormData data, BuildContext dialogContext) async {
    try {
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse(TEAM_URL),
        headers: await _authHeaders(),
        body: jsonEncode(data.toPayload()),
      );
      CommonUtilities.showLog('POST team ${response.statusCode}');

      if (!mounted || !dialogContext.mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(dialogContext);
        await _loadMembers();
        if (mounted) _showInvitationResult(jsonDecode(response.body)['data']);
      } else {
        _showApiError(response.body, 'Failed to send invite');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team create error: $error');
      if (mounted) CommonUtilities.createSnackBar(context, 'Failed to send invite');
    }
  }

  void _showInvitationResult(dynamic member) {
    final delivery = member is Map ? member['invitationDelivery'] : null;
    if (delivery is! Map) return;
    final sms = _TeamMember.smsSummary(delivery);
    CommonUtilities.createSnackBar(context,
        'SMS: $sms. The member can sign in using their phone OTP.');
  }

  Future<void> _updateMember(
    _TeamMember member,
    _TeamMemberFormData data,
    BuildContext dialogContext,
  ) async {
    try {
      final response = await (widget.client?.patch ?? http.patch)(
        Uri.parse('$TEAM_URL/${member.id}'),
        headers: await _authHeaders(),
        body: jsonEncode(data.toPayload()),
      );
      CommonUtilities.showLog('PATCH team ${response.statusCode}');

      if (!mounted || !dialogContext.mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(dialogContext);
        await _loadMembers();
      } else {
        _showApiError(response.body, 'Failed to save changes');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team update error: $error');
      if (mounted) CommonUtilities.createSnackBar(context, 'Failed to save changes');
    }
  }

  Future<void> _deleteMember(_TeamMember member, BuildContext dialogContext) async {
    if (_loading) return;
    Navigator.pop(dialogContext);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (confirmationContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        constraints: const BoxConstraints(maxWidth: 400),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
        title: Row(children: [
          const Expanded(child: Text('Are you sure?', style: TextStyle(
            fontFamily: 'Satoshi', fontSize: 18, fontWeight: FontWeight.w700,
            color: _ink,
          ))),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(confirmationContext, false),
            icon: const Icon(Icons.close, size: 20, color: _ink),
          ),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
        content: const Text(
          'This action cannot be undone. This will permanently delete the member from your team.',
          style: TextStyle(fontFamily: 'Satoshi', fontSize: 13, height: 1.5, color: AppColors.black1),
        ),
        actionsPadding: const EdgeInsets.all(18),
        actions: [Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: AppColors.black1),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontFamily: 'Satoshi', fontSize: 13),
            ),
            child: const Text('Cancel'),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.pop(confirmationContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontFamily: 'Satoshi', fontSize: 13),
            ),
            child: const Text("Yes, I'm sure"),
          )),
        ])],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final response = await (widget.client?.delete ?? http.delete)(
        Uri.parse('$TEAM_URL/${member.id}'),
        headers: await _authHeaders(),
      );
      CommonUtilities.showLog('DELETE team ${response.statusCode}');

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadMembers();
      } else {
        _showApiError(response.body, 'Failed to delete member');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team delete error: $error');
      if (mounted) CommonUtilities.createSnackBar(context, 'Failed to delete member');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showApiError(String body, String fallback) {
    var message = fallback;
    try {
      final decoded = jsonDecode(body);
      final apiMessage = decoded['message'];
      if (apiMessage is List && apiMessage.isNotEmpty) {
        message = apiMessage.first.toString();
      } else if (apiMessage != null) {
        message = apiMessage.toString();
      }
    } catch (_) {}

    if (mounted) CommonUtilities.createSnackBar(context, message);
  }

  void _openMemberDialog({_TeamMember? member}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (dialogContext) {
        return _TeamMemberDialog(
          roles: _roles,
          member: member,
          onSubmit: (data) {
            if (member == null) {
              return _createMember(data, dialogContext);
            }
            return _updateMember(member, data, dialogContext);
          },
          onDelete: member == null
              ? null
              : () => _deleteMember(member, dialogContext),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onBack: () => Navigator.pop(context)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.purple,
                              ),
                            )
                              : _loadError != null
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_loadError!),
                                          const SizedBox(height: 12),
                                          TextButton(onPressed: _loadMembers, child: const Text('Retry')),
                                        ],
                                      ),
                                    )
                                  : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Team members (${_members.length})',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontFamily: 'Satoshi',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_members.isEmpty)
                                  _EmptyMembersCard(
                                    onAdd: () => _openMemberDialog(),
                                  )
                                else
                                  Expanded(
                                    child: ListView.separated(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: _members.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (_, index) {
                                        final member = _members[index];
                                        return _MemberCard(
                                          member: member,
                                          onEdit: () =>
                                              _openMemberDialog(member: member),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  if (!_loading && _members.isNotEmpty)
                    _FixedAddButton(onTap: () => _openMemberDialog()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamMemberFormData {
  const _TeamMemberFormData({
    required this.fullName,
    required this.phone,
    required this.role,
    required this.bookingManagement,
  });

  final String fullName;
  final String phone;
  final String role;
  final bool bookingManagement;

  Map<String, dynamic> toPayload() {
    return {
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'permissions': {
        'bookingManagement': bookingManagement,
      },
    };
  }
}

class _TeamMemberDialog extends StatefulWidget {
  const _TeamMemberDialog({
    required this.roles,
    required this.onSubmit,
    this.member,
    this.onDelete,
  });

  final List<_RoleOption> roles;
  final _TeamMember? member;
  final Future<void> Function(_TeamMemberFormData data) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<_TeamMemberDialog> createState() => _TeamMemberDialogState();
}

class _TeamMemberDialogState extends State<_TeamMemberDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _role;
  late bool _bookingManagement;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _nameController = TextEditingController(text: member?.name ?? '');
    _phoneController = TextEditingController(
      text: _phoneDigits(member?.phone ?? ''),
    );
    final initialRole = member?.role ?? widget.roles.first.value;
    _role = widget.roles.any((role) => role.value == initialRole)
        ? initialRole
        : widget.roles.first.value;
    _bookingManagement = member?.bookingManagement ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  static String _phoneDigits(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length > 10) {
      return digits.substring(2);
    }
    return digits;
  }

  Future<void> _submit() async {
    if (_saving || _deleting) return;
    final name = _nameController.text.trim();
    final phoneDigits = _phoneDigits(_phoneController.text);

    if (name.isEmpty) {
      CommonUtilities.createSnackBar(context, 'Full name is required');
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phoneDigits)) {
      CommonUtilities.createSnackBar(
          context, 'Enter a valid 10-digit mobile number starting with 6, 7, 8 or 9');
      return;
    }
    setState(() => _saving = true);
    await widget.onSubmit(
      _TeamMemberFormData(
        fullName: name,
        phone: '+91$phoneDigits',
        role: _role,
        bookingManagement: _bookingManagement,
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    if (widget.onDelete == null || _saving || _deleting) return;
    setState(() => _deleting = true);
    await widget.onDelete!();
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = size.height - viewInsets.vertical - 80;

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit member details' : 'Add new team member',
                      style: const TextStyle(
                        color: _ManageTeamScreenState._ink,
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                    padding: EdgeInsets.zero,
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(24, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _RequiredLabel('Full Name'),
              _InputBox(
                controller: _nameController,
                hint: 'e.g. Abhishek Sharma',
              ),
              const SizedBox(height: 14),
              const _RequiredLabel('Mobile Number'),
              _InputBox(
                controller: _phoneController,
                hint: '9900990099',
                prefixText: '+91-',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.length != 12 || !newValue.text.startsWith('91')) {
                      return newValue;
                    }
                    final digits = _phoneDigits(newValue.text);
                    return TextEditingValue(
                      text: digits,
                      selection: TextSelection.collapsed(offset: digits.length),
                    );
                  }),
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 14),
              const _RequiredLabel('Role'),
              _RoleDropdown(
                value: _role,
                roles: widget.roles,
                onChanged: (value) => setState(() => _role = value),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _ManageTeamScreenState._line),
              const SizedBox(height: 20),
              const Text(
                'Permissions',
                style: TextStyle(
                  color: _ManageTeamScreenState._ink,
                  fontFamily: 'Satoshi',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking management',
                          style: TextStyle(
                            color: _ManageTeamScreenState._ink,
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Allow managing customer bookings',
                          style: TextStyle(
                            color: _ManageTeamScreenState._muted,
                            fontFamily: 'Satoshi',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: FittedBox(
                      child: Switch(
                        value: _bookingManagement,
                        activeTrackColor: AppColors.purple,
                        activeThumbColor: Colors.white,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFFE7E7E7),
                        onChanged: (value) {
                          setState(() => _bookingManagement = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (_isEdit) ...[
                const SizedBox(height: 26),
                _deleting
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.red,
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _delete,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Delete Member',
                            style: TextStyle(
                              color: AppColors.red,
                              fontFamily: 'Satoshi',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ],
              const SizedBox(height: 14),
              _saving
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.purple),
                    )
                  : _PurpleButton(
                      label: _isEdit ? 'Save Changes' : 'Send Invite',
                      compact: true,
                      onTap: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                color: _ManageTeamScreenState._ink,
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Text(
            'Manage team',
            style: TextStyle(
              color: _ManageTeamScreenState._ink,
              fontFamily: 'Satoshi',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMembersCard extends StatelessWidget {
  const _EmptyMembersCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 56, 26, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ManageTeamScreenState._line),
      ),
      child: Column(
        children: [
          const _SearchTeamIcon(),
          const SizedBox(height: 20),
          const Text(
            'No team members found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ManageTeamScreenState._ink,
              fontFamily: 'Satoshi',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Invite your team members to smoothly operate and manage your venue',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ManageTeamScreenState._muted,
              fontFamily: 'Satoshi',
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 30),
          _PurpleButton(label: '+ New Member', onTap: onAdd),
        ],
      ),
    );
  }
}

class _SearchTeamIcon extends StatefulWidget {
  const _SearchTeamIcon();

  @override
  State<_SearchTeamIcon> createState() => _SearchTeamIconState();
}

class _SearchTeamIconState extends State<_SearchTeamIcon> {
  Future<Uint8List?> _loadEmbeddedImage() async {
    final svg = await rootBundle.loadString('assets/search_team.svg');
    final match = RegExp(r'xlink:href="data:image/[^;]+;base64,([^"]+)"')
        .firstMatch(svg);
    if (match == null) return null;
    return Uint8List.fromList(base64Decode(match.group(1)!));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: FutureBuilder<Uint8List?>(
        future: _loadEmbeddedImage(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onEdit,
  });

  final _TeamMember member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isActive = member.status.toLowerCase() == 'active';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ManageTeamScreenState._line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: member.name,
                        style: const TextStyle(
                          color: _ManageTeamScreenState._ink,
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: '  |  ',
                        style: TextStyle(
                          color: _ManageTeamScreenState._muted,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                      TextSpan(
                        text: member.roleLabel,
                        style: const TextStyle(
                          color: _ManageTeamScreenState._ink,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? _ManageTeamScreenState._purpleSoft
                      : const Color(0xFFFFF1BF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  member.statusLabel,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.purple
                        : const Color(0xFFC98500),
                    fontFamily: 'Satoshi',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${isActive ? 'Joined' : 'Added'} ${member.createdAt}',
            style: const TextStyle(
              color: _ManageTeamScreenState._muted,
              fontFamily: 'Satoshi',
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                color: _ManageTeamScreenState._muted,
                size: 17,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  member.phone,
                  style: const TextStyle(
                    color: _ManageTeamScreenState._muted,
                    fontFamily: 'Satoshi',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _ManageTeamScreenState._purpleSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: AppColors.purple,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedAddButton extends StatelessWidget {
  const _FixedAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _ManageTeamScreenState._ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.yellow, size: 22),
              SizedBox(width: 8),
              Text(
                'New member',
                style: TextStyle(
                  color: AppColors.yellow,
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                color: _ManageTeamScreenState._ink,
                fontFamily: 'Satoshi',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(
              text: '*',
              style: TextStyle(
                color: AppColors.red,
                fontFamily: 'Satoshi',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.prefixText,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          color: _ManageTeamScreenState._ink,
          fontFamily: 'Satoshi',
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(prefixText!, style: const TextStyle(
                    color: _ManageTeamScreenState._ink,
                    fontFamily: 'Satoshi',
                    fontSize: 13,
                  )),
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          hintStyle: const TextStyle(
            color: Color(0xFFA0A0A0),
            fontFamily: 'Satoshi',
            fontSize: 12,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _ManageTeamScreenState._line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _ManageTeamScreenState._line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.purple),
          ),
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.value,
    required this.roles,
    required this.onChanged,
  });

  final String value;
  final List<_RoleOption> roles;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final menuMaxHeight =
        (MediaQuery.sizeOf(context).height * .32).clamp(180.0, 280.0).toDouble();
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ManageTeamScreenState._line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          menuMaxHeight: menuMaxHeight,
          dropdownColor: const Color(0xFFFFF8FF),
          borderRadius: BorderRadius.circular(2),
          style: const TextStyle(
            color: _ManageTeamScreenState._ink,
            fontFamily: 'Satoshi',
            fontSize: 13,
          ),
          items: roles
              .map(
                (role) => DropdownMenuItem<String>(
                  value: role.value,
                  child: Text(role.label),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _PurpleButton extends StatelessWidget {
  const _PurpleButton({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 6 : 10),
      child: Container(
        height: compact ? 36 : 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.purple,
          borderRadius: BorderRadius.circular(compact ? 6 : 10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Satoshi',
              fontSize: compact ? 13 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
