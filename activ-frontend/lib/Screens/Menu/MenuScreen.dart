import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../../Style/app_colors.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../GetStartedScreen.dart';
import '../HelpSupportScreen.dart';
import '../Home/Activities/VenueActivityListScreen.dart';
import '../Home/ManageTeamScreen.dart';
import '../Home/PartnerAgreementScreen.dart';
import '../Home/ProfileScreen.dart';
import '../Home/VenueInfoScreen.dart';
import '../Home/ViewDocumentScreen.dart';
import '../StringExtensions.dart';
import 'SettingsScreen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ScrollController scrollController = ScrollController();
  bool _isPartner = true;
  String _profileName = 'Partner';
  String _profileEmail = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _loadProfileHeader();
  }

  Future<void> _loadUserType() async {
    final userType = checkString(await SharedPreference.readStr("user_type"));
    if (!mounted) return;
    setState(() {
      _isPartner = userType != "team_member";
    });
  }

  Future<void> _loadProfileHeader() async {
    try {
      final token = checkString(await SharedPreference.readStr("jwt_token"));
      if (token.isEmpty) return;

      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) return;

      final body = jsonDecode(response.body);
      final data = body['data'] ?? {};
      final member = data['member'];
      final partner = data['partner'] ?? data;

      String name = '';
      String email = '';
      String avatar = '';

      if (member is Map) {
        name = checkString(member['fullName'] ?? member['name']);
        email = checkString(member['email']);
        avatar = checkString(member['avatarUrl'] ?? member['profileImage']);
      } else if (partner is Map) {
        final firstName = checkString(partner['firstName']);
        final lastName = checkString(partner['lastName']);
        name =
            [firstName, lastName].where((value) => value.isNotEmpty).join(' ');
        if (name.isEmpty) {
          name = checkString(partner['fullName'] ??
              partner['name'] ??
              partner['businessName']);
        }
        email = checkString(partner['email']);
        avatar = checkString(partner['avatarUrl'] ?? partner['profileImage']);
      }

      if (!mounted) return;
      setState(() {
        if (name.isNotEmpty) _profileName = name;
        _profileEmail = email;
        _avatarUrl = avatar;
      });
    } catch (e) {
      CommonUtilities.showLog('Menu profile header error: $e');
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _openProfile() async {
    await Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => ProfileScreen(client: widget.client)));
    if (mounted) await _loadProfileHeader();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFFF0F7D2),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F7D2),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 26),
                    ..._menuItems().map(_buildMenuRow),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_ProfileMenuItem> _menuItems() {
    return [
      _ProfileMenuItem(
        title: 'Partner Details',
        icon: Icons.person_outline_rounded,
        onTap: _openProfile,
      ),
      _ProfileMenuItem(
        title: 'Venue Information',
        icon: Icons.location_on_outlined,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          VenueInfoScreen(client: widget.client),
        ),
      ),
      _ProfileMenuItem(
        title: 'Activity Management',
        icon: Icons.sports_baseball_outlined,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          const VenueActivityListScreen(),
        ),
      ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Business & Verification',
          icon: Icons.verified_user,
          onTap: () => CommonUtilities.NavigateWithPush(
            context,
            const ViewDocumentScreen(),
          ),
        ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Bank Details',
          icon: Icons.credit_card_rounded,
          onTap: () => _showComingSoon('Bank Details'),
        ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Payout History',
          icon: Icons.currency_rupee_rounded,
          onTap: () => _showComingSoon('Payout History'),
        ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Manage Team',
          icon: Icons.group_outlined,
          onTap: () => CommonUtilities.NavigateWithPush(
            context,
            ManageTeamScreen(client: widget.client),
          ),
        ),
      _ProfileMenuItem(
        title: 'Help & Support',
        icon: Icons.support_agent_rounded,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          HelpSupportScreen(client: widget.client),
        ),
      ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Partner Agreement',
          icon: Icons.article_outlined,
          onTap: () => CommonUtilities.NavigateWithPush(
            context,
            const PartnerAgreementScreen(),
          ),
        ),
      _ProfileMenuItem(
        title: 'App Controls',
        icon: Icons.logout_rounded,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          SettingsScreen(client: widget.client),
        ),
      ),
    ];
  }

  static const _labelStyle = TextStyle(
    fontFamily: 'Satoshi',
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.darkBlack,
  );

  Widget _buildHeader() {
    return Column(children: [
      Row(children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: Colors.black12,
          child: IconButton(
            tooltip: 'Back',
            style: IconButton.styleFrom(
              minimumSize: const Size.square(40),
              maximumSize: const Size.square(40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(Icons.arrow_back, size: 25, color: Colors.black),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
            child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Hey, Partner!',
              style: TextStyle(
                  fontSize: 26,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlack)),
        )),
      ]),
      const SizedBox(height: 28),
      SizedBox(
          width: 130,
          height: 130,
          child: Stack(children: [
            ClipOval(
              key: const Key('partner-avatar'),
              child: SizedBox(
                width: 130,
                height: 130,
                child: ColoredBox(
                  color: const Color(0xFFC8C8C8),
                  child: _avatarUrl.isNotEmpty
                      ? Image.network(_avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultAvatar())
                      : _buildDefaultAvatar(),
                ),
              ),
            ),
            Positioned(
                right: 2,
                bottom: 2,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFFA536F5), width: .7)),
                  elevation: 3,
                  shadowColor: Colors.black12,
                  child: IconButton(
                    tooltip: 'Edit profile photo',
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(24),
                      maximumSize: const Size.square(24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _openProfile,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                    icon: const Icon(Icons.camera_alt,
                        color: Color(0xFFA536F5), size: 18),
                  ),
                )),
          ])),
      const SizedBox(height: 18),
      Text(_profileName,
          textAlign: TextAlign.center,
          style: _labelStyle.copyWith(fontSize: 20)),
      const SizedBox(height: 8),
      SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_profileEmail.isNotEmpty ? _profileEmail : ' ',
                style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                    color: AppColors.black1)),
          )),
    ]);
  }

  Widget _buildDefaultAvatar() => const Icon(
        Icons.person_outline_rounded,
        color: AppColors.black1,
        size: 64,
        semanticLabel: 'Partner profile',
      );

  Widget _buildMenuRow(_ProfileMenuItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.icon, color: Colors.black, size: 25)),
                const SizedBox(width: 14),
                Expanded(child: Text(item.title, style: _labelStyle)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.black, size: 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    const footerStyle = TextStyle(
      fontFamily: 'Satoshi',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF53564A),
    );
    return Column(children: [
      const SizedBox(height: 22),
      SizedBox(
          width: 190,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, size: 28),
            label: const Text('Logout',
                style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 20)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: const Color(0xFFD8F34A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )),
      const SizedBox(height: 22),
      Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: [
            const Text('Our ', style: footerStyle),
            InkWell(
                onTap: () =>
                    _showPolicy('terms_and_conditions', 'Terms and Conditions'),
                child: Text('"Terms and Conditions"',
                    style:
                        footerStyle.copyWith(color: const Color(0xFFA536F5)))),
            const Text(' and ', style: footerStyle),
            InkWell(
                onTap: () => _showPolicy('refund_policy', 'Refund Policy'),
                child: Text('"Refund Policy"',
                    style:
                        footerStyle.copyWith(color: const Color(0xFFA536F5)))),
          ]),
      const SizedBox(height: 10),
      const Text('Version 1.0.1',
          style: TextStyle(
              fontFamily: 'Satoshi', fontSize: 13, color: Color(0xFF969C82))),
      const SizedBox(height: 36),
      Image.asset('assets/logo.png',
          width: 130,
          height: 60,
          color: const Color(0xFFB1B98D),
          colorBlendMode: BlendMode.srcIn,
          semanticLabel: 'ACTIV Partner'),
    ]);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you logging out?',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.darkBlack,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can log back any time. Stay ACTIV.',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  height: 1.35,
                  color: AppColors.darkBlack,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkBlack,
                          side: const BorderSide(
                            color: AppColors.darkBlack,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
      await SharedPreference.clearSF();
      if (mounted) {
        CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
            context, GetStartedScreen());
      }
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to logout. Please try again.');
      }
    }
  }

  Future<void> _showPolicy(String type, String title) async {
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse('$LEGAL_URL/$type'),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode != 200) throw Exception('Policy unavailable');
      final data = jsonDecode(response.body)['data'];
      final content =
          html.parse(data?['content']?.toString() ?? '').body?.text.trim() ??
              '';
      if (content.isEmpty) throw Exception('Policy unavailable');
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(child: Text(content)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              ));
    } catch (_) {
      if (mounted) {
        CommonUtilities.createSnackBar(
            context, 'Unable to load policy. Please try again.');
      }
    }
  }

  void _showComingSoon(String title) {
    CommonUtilities.createSnackBar(context, '$title will be available soon.');
  }
}

class _ProfileMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}
