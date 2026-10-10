import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../../Utills/common_utilities.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _Member {
  final String id;
  String name;
  String email;
  String phone;
  String role;       // lowercase: manager | receptionist | trainer | staff
  String status;     // 'active' | 'invited'
  String joinedDate;
  bool bookingMgmt;
  bool pricingControl;
  bool analyticsView;

  _Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.joinedDate,
    this.bookingMgmt = false,
    this.pricingControl = false,
    this.analyticsView = false,
  });

  factory _Member.fromJson(Map<String, dynamic> j) {
    final perms = j['permissions'] as Map<String, dynamic>? ?? {};
    final isActive = (j['status'] ?? '').toString().toLowerCase() == 'active';
    return _Member(
      id: j['id']?.toString() ?? '',
      name: j['fullName']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      role: j['role']?.toString() ?? 'staff',
      status: isActive ? 'active' : 'invited',
      joinedDate: _formatDate(j['createdAt']?.toString()),
      bookingMgmt: perms['bookingManagement'] == true,
      pricingControl: perms['pricingControl'] == true,
      analyticsView: perms['analyticsView'] == true,
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  String get displayRole => role[0].toUpperCase() + role.substring(1);
  bool get isActive => status == 'active';
  String get joinedLabel => isActive ? 'Joined' : 'Added';
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ManageTeamScreen extends StatefulWidget {
  const ManageTeamScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<ManageTeamScreen> createState() => _State();
}

class _State extends State<ManageTeamScreen> {
  List<_Member> _members = [];
  bool _loading = true;

  static const _roles = ['Manager', 'Receptionist', 'Trainer', 'Staff'];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // ── API helpers ────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await SharedPreference.readStr('jwt_token');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();
      final res = await (widget.client?.get ?? http.get)(Uri.parse(TEAM_URL), headers: headers);
      CommonUtilities.showLog('GET team: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List data = body is List ? body : (body['data'] ?? body['team'] ?? []);
        if (!mounted) return;
        setState(() { _members = data.map((j) => _Member.fromJson(j)).toList(); });
      }
    } catch (e) {
      CommonUtilities.showLog('loadMembers error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMember({
    required String name, required String email, required String role,
    required bool bookingMgmt, required bool pricingControl, required bool analyticsView,
    required BuildContext dialogCtx,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = jsonEncode({
        'fullName': name, 'email': email,
        'role': role.toLowerCase(),
        'permissions': {
          'bookingManagement': bookingMgmt,
          'pricingControl': pricingControl,
          'analyticsView': analyticsView,
        },
      });
      final res = await (widget.client?.post ?? http.post)(Uri.parse(TEAM_URL), headers: headers, body: body);
      CommonUtilities.showLog('POST team: ${res.statusCode} ${res.body}');
      if (!mounted || !dialogCtx.mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(dialogCtx);
        _loadMembers();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to send invite';
        CommonUtilities.createSnackBar(context, msg is List ? msg.first : msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog('createMember error: $e');
    }
  }

  Future<void> _updateMember({
    required _Member member, required String name, required String email,
    required String role, required bool bookingMgmt, required bool pricingControl,
    required bool analyticsView, required BuildContext dialogCtx,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = jsonEncode({
        'fullName': name, 'email': email,
        'role': role.toLowerCase(),
        'permissions': {
          'bookingManagement': bookingMgmt,
          'pricingControl': pricingControl,
          'analyticsView': analyticsView,
        },
      });
      final res = await (widget.client?.patch ?? http.patch)(Uri.parse('$TEAM_URL/${member.id}'), headers: headers, body: body);
      CommonUtilities.showLog('PATCH team: ${res.statusCode} ${res.body}');
      if (!mounted || !dialogCtx.mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(dialogCtx);
        _loadMembers();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Update failed';
        CommonUtilities.createSnackBar(context, msg is List ? msg.first : msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog('updateMember error: $e');
    }
  }

  Future<void> _deleteMember(String id, BuildContext dialogCtx) async {
    try {
      final headers = await _authHeaders();
      final res = await (widget.client?.delete ?? http.delete)(Uri.parse('$TEAM_URL/$id'), headers: headers);
      CommonUtilities.showLog('DELETE team: ${res.statusCode} ${res.body}');
      if (!mounted || !dialogCtx.mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(dialogCtx);
        _loadMembers();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Delete failed';
        CommonUtilities.createSnackBar(context, msg is List ? msg.first : msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog('deleteMember error: $e');
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Manager';
    bool bookingMgmt = true;
    bool pricingControl = false;
    bool analyticsView = false;
    bool saving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogHeader('Add new team member', ctx),
                const SizedBox(height: 20),
                _fieldLabel('Full Name'),
                _textField(nameCtrl, 'Abhishek Sharma'),
                const SizedBox(height: 14),
                _fieldLabel('Email Address'),
                _textField(emailCtrl, 'abhishek.sharma@maxfitness.com', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _fieldLabel('Role'),
                _roleDropdown(role, (v) => setLocal(() => role = v!)),
                const Divider(height: 28, color: Color(0xFFE5E7EB)),
                const Text('Permissions', style: TextStyle(fontSize: 15, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 12),
                _permissionRow('Booking management', 'Allow managing customer bookings', bookingMgmt, (v) => setLocal(() => bookingMgmt = v)),
                _permissionRow('Pricing control', 'Allow editing pricing and offers', pricingControl, (v) => setLocal(() => pricingControl = v)),
                _permissionRow('Analytics view', 'Allow viewing analytics and reports', analyticsView, (v) => setLocal(() => analyticsView = v)),
                const SizedBox(height: 20),
                saving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D38EB)))
                    : _purpleButton('Send Invite', () async {
                        if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                          CommonUtilities.createSnackBar(context, 'Name and email are required');
                          return;
                        }
                        setLocal(() => saving = true);
                        await _createMember(
                          name: nameCtrl.text.trim(), email: emailCtrl.text.trim(),
                          role: role, bookingMgmt: bookingMgmt,
                          pricingControl: pricingControl, analyticsView: analyticsView,
                          dialogCtx: ctx,
                        );
                        setLocal(() => saving = false);
                      }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(_Member m) {
    final nameCtrl = TextEditingController(text: m.name);
    final emailCtrl = TextEditingController(text: m.email);
    String role = m.displayRole;
    bool bookingMgmt = m.bookingMgmt;
    bool pricingControl = m.pricingControl;
    bool analyticsView = m.analyticsView;
    bool saving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogHeader('Edit member details', ctx),
                const SizedBox(height: 20),
                _fieldLabel('Full Name'),
                _textField(nameCtrl, 'Full name'),
                const SizedBox(height: 14),
                _fieldLabel('Email Address'),
                _textField(emailCtrl, 'Email address', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _fieldLabel('Role'),
                _roleDropdown(role, (v) => setLocal(() => role = v!)),
                const Divider(height: 28, color: Color(0xFFE5E7EB)),
                const Text('Permissions', style: TextStyle(fontSize: 15, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 12),
                _permissionRow('Booking management', 'Allow managing customer bookings', bookingMgmt, (v) => setLocal(() => bookingMgmt = v)),
                _permissionRow('Pricing control', 'Allow editing pricing and offers', pricingControl, (v) => setLocal(() => pricingControl = v)),
                _permissionRow('Analytics view', 'Allow viewing analytics and reports', analyticsView, (v) => setLocal(() => analyticsView = v)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () { Navigator.pop(ctx); _showDeleteConfirm(m); },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFE6B6B)),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Delete Member', style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFFFE6B6B))),
                ),
                const SizedBox(height: 10),
                saving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D38EB)))
                    : _purpleButton('Save Changes', () async {
                        setLocal(() => saving = true);
                        await _updateMember(
                          member: m,
                          name: nameCtrl.text.trim(), email: emailCtrl.text.trim(),
                          role: role, bookingMgmt: bookingMgmt,
                          pricingControl: pricingControl, analyticsView: analyticsView,
                          dialogCtx: ctx,
                        );
                        setLocal(() => saving = false);
                      }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(_Member m) {
    bool deleting = false;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Are you sure?', style: TextStyle(fontSize: 18, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)))),
                    InkWell(onTap: () => Navigator.pop(ctx), borderRadius: BorderRadius.circular(20),
                        child: const Icon(Icons.close, size: 20, color: Color(0xFF1F1F1F))),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('This action cannot be undone. This will permanently delete the member from your team.',
                    style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF3F3F3F))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1F1F1F)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: deleting
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFE6B6B)))
                          : ElevatedButton(
                              onPressed: () async {
                                setLocal(() => deleting = true);
                                await _deleteMember(m.id, ctx);
                                setLocal(() => deleting = false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFE6B6B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                              ),
                              child: const Text("Yes, I'm sure", style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _dialogHeader(String title, BuildContext ctx) => Row(
    children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)))),
      InkWell(onTap: () => Navigator.pop(ctx), borderRadius: BorderRadius.circular(20),
          child: const Icon(Icons.close, size: 20, color: Color(0xFF1F1F1F))),
    ],
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: text, style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFF3F3F3F))),
      const TextSpan(text: '*', style: TextStyle(color: Color(0xFFFE6B6B))),
    ])),
  );

  Widget _textField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', color: Color(0xFF1F1F1F)),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF9D38EB))),
          filled: true, fillColor: Colors.white,
        ),
      );

  Widget _roleDropdown(String value, ValueChanged<String?> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB)), color: Colors.white),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1F1F1F)),
        style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', color: Color(0xFF1F1F1F)),
        items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
        onChanged: onChanged,
      ),
    ),
  );

  Widget _permissionRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
          Text(subtitle, style: const TextStyle(fontSize: 11, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF7F7F7F))),
        ])),
        Switch(value: value, onChanged: onChanged,
            activeThumbColor: Colors.white, activeTrackColor: const Color(0xFF9D38EB),
            inactiveThumbColor: Colors.white, inactiveTrackColor: const Color(0xFFE5E7EB)),
      ],
    ),
  );

  Widget _purpleButton(String label, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(color: const Color(0xFF9D38EB), borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Colors.white))),
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D38EB)))
                  : RefreshIndicator(
                      onRefresh: _loadMembers,
                      color: const Color(0xFF9D38EB),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        children: [
                          Text('Team members (${_members.length})',
                              style: const TextStyle(fontSize: 15, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                          const SizedBox(height: 14),
                          if (_members.isEmpty) _buildEmptyState()
                          else ..._members.map((m) => _buildMemberCard(m)),
                        ],
                      ),
                    ),
            ),
            if (!_loading && _members.isNotEmpty) _buildNewMemberButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(width: 40, height: 40,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1F1F1F))),
        ),
        const SizedBox(width: 12),
        const Text('Manage team', style: TextStyle(fontSize: 18, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
      ],
    ),
  );

  Widget _buildEmptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Column(
      children: [
        Image.asset('assets/ic_question.png', width: 90, height: 90),
        const SizedBox(height: 16),
        const Text('No team members found', style: TextStyle(fontSize: 15, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
        const SizedBox(height: 6),
        const Text('Invite your team members to smoothly operate and manage your venue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF7F7F7F))),
        const SizedBox(height: 20),
        _purpleButton('+ New Member', _showAddDialog),
      ],
    ),
  );

  Widget _buildMemberCard(_Member m) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text.rich(TextSpan(children: [
          TextSpan(text: m.name, style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
          const TextSpan(text: '  |  ', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          TextSpan(text: m.displayRole, style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF3F3F3F))),
        ]))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: m.isActive ? const Color(0xFFEDE9FE) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(m.isActive ? 'Active' : 'Invite Sent',
              style: TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w600,
                  color: m.isActive ? const Color(0xFF9D38EB) : const Color(0xFFD97706))),
        ),
      ]),
      const SizedBox(height: 4),
      Text('${m.joinedLabel} ${m.joinedDate}',
          style: const TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF7F7F7F))),
      const SizedBox(height: 4),
      Text('${m.email}  |  ${m.phone}',
          style: const TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF3F3F3F))),
      const SizedBox(height: 12),
      Row(children: [
        _actionIcon(Icons.mail_outline, () {}),
        const SizedBox(width: 10),
        _actionIcon(Icons.chat_bubble_outline, () {}),
        const SizedBox(width: 10),
        _actionIcon(Icons.phone_outlined, () {}),
        const SizedBox(width: 10),
        _actionIcon(Icons.edit_outlined, () => _showEditDialog(m)),
      ]),
    ]),
  );

  Widget _actionIcon(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(20),
    child: Container(width: 36, height: 36,
        decoration: const BoxDecoration(color: Color(0xFFEDE9FE), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: const Color(0xFF9D38EB))),
  );

  Widget _buildNewMemberButton() => Container(
    color: Colors.transparent,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
    child: InkWell(
      onTap: _showAddDialog, borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, color: Color(0xFFFFD700), size: 18),
          SizedBox(width: 6),
          Text('New member', style: TextStyle(fontSize: 15, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
        ])),
      ),
    ),
  );
}
