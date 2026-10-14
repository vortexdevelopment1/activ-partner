import 'dart:convert';

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
    if (mounted) setState(() => _loading = true);
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(TEAM_URL),
        headers: await _authHeaders(),
      );
      CommonUtilities.showLog('GET team ${response.statusCode}: ${response.body}');

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
        });
      } else {
        _showApiError(response.body, 'Unable to load team members');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team load error: $error');
      if (mounted) {
        CommonUtilities.createSnackBar(context, 'Unable to load team members');
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
      CommonUtilities.showLog('POST team ${response.statusCode}: ${response.body}');

      if (!mounted || !dialogContext.mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(dialogContext);
        await _loadMembers();
      } else {
        _showApiError(response.body, 'Failed to send invite');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team create error: $error');
      if (mounted) CommonUtilities.createSnackBar(context, 'Failed to send invite');
    }
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
      CommonUtilities.showLog('PATCH team ${response.statusCode}: ${response.body}');

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
    try {
      final response = await (widget.client?.delete ?? http.delete)(
        Uri.parse('$TEAM_URL/${member.id}'),
        headers: await _authHeaders(),
      );
      CommonUtilities.showLog('DELETE team ${response.statusCode}: ${response.body}');

      if (!mounted || !dialogContext.mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        Navigator.pop(dialogContext);
        await _loadMembers();
      } else {
        _showApiError(response.body, 'Failed to delete member');
      }
    } catch (error) {
      CommonUtilities.showLog('Manage team delete error: $error');
      if (mounted) CommonUtilities.createSnackBar(context, 'Failed to delete member');
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
                                      physics: _members.length <= 3
                                          ? const NeverScrollableScrollPhysics()
                                          : const BouncingScrollPhysics(),
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
    final name = _nameController.text.trim();
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty) {
      CommonUtilities.createSnackBar(context, 'Full name is required');
      return;
    }
    if (phoneDigits.length < 10) {
      CommonUtilities.createSnackBar(context, 'Enter a valid mobile number');
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
    if (widget.onDelete == null) return;
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _RequiredLabel('Full Name'),
              _InputBox(
                controller: _nameController,
                hint: 'e.g. Abhishek Sharma',
              ),
              const SizedBox(height: 18),
              const _RequiredLabel('Mobile Number'),
              Row(
                children: [
                  Container(
                    height: 58,
                    width: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _ManageTeamScreenState._line),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '+91',
                          style: TextStyle(
                            color: _ManageTeamScreenState._ink,
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InputBox(
                      controller: _phoneController,
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'A login link will be sent via SMS/WhatsApp',
                style: TextStyle(
                  color: _ManageTeamScreenState._muted,
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              const _RequiredLabel('Role'),
              _RoleDropdown(
                value: _role,
                roles: widget.roles,
                onChanged: (value) => setState(() => _role = value),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: _ManageTeamScreenState._line),
              const SizedBox(height: 20),
              const Text(
                'Permissions',
                style: TextStyle(
                  color: _ManageTeamScreenState._ink,
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Allow managing customer bookings',
                          style: TextStyle(
                            color: _ManageTeamScreenState._muted,
                            fontFamily: 'Satoshi',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _bookingManagement,
                    activeTrackColor: AppColors.purple,
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE7E7E7),
                    onChanged: (value) {
                      setState(() => _bookingManagement = value);
                    },
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
                          onPressed: _delete,
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
          const Icon(
            Icons.help_outline_rounded,
            color: _ManageTeamScreenState._muted,
            size: 46,
          ),
          const SizedBox(height: 54),
          const Text(
            'No team members yet',
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
            'Add your on-ground staff - receptionists, managers, floor staff and more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ManageTeamScreenState._muted,
              fontFamily: 'Satoshi',
              fontSize: 15,
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onEdit,
  });

  final _TeamMember member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: '  |  ',
                        style: TextStyle(
                          color: _ManageTeamScreenState._muted,
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: member.roleLabel,
                        style: const TextStyle(
                          color: _ManageTeamScreenState._ink,
                          fontFamily: 'Satoshi',
                          fontSize: 14,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1BF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  member.statusLabel,
                  style: const TextStyle(
                    color: Color(0xFFC98500),
                    fontFamily: 'Satoshi',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Added ${member.createdAt}',
            style: const TextStyle(
              color: _ManageTeamScreenState._muted,
              fontFamily: 'Satoshi',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
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
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: _ManageTeamScreenState._purpleSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: AppColors.purple,
                size: 22,
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
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(
              text: '*',
              style: TextStyle(
                color: AppColors.red,
                fontFamily: 'Satoshi',
                fontSize: 15,
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
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          color: _ManageTeamScreenState._ink,
          fontFamily: 'Satoshi',
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFA0A0A0),
            fontFamily: 'Satoshi',
            fontSize: 15,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
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
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
          dropdownColor: const Color(0xFFFFF8FF),
          borderRadius: BorderRadius.circular(2),
          style: const TextStyle(
            color: _ManageTeamScreenState._ink,
            fontFamily: 'Satoshi',
            fontSize: 16,
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
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.purple,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Satoshi',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
