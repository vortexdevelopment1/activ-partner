import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../Style/app_colors.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../ContactSupportFormScreen.dart';
import '../Home/Activities/VenueActivityListScreen.dart';
import '../Home/ManageTeamScreen.dart';
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
        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
    if (mounted) await _loadProfileHeader();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Container(
          decoration: context.getYellowGradient,
          child: SafeArea(
            left: false,
            top: true,
            bottom: true,
            right: false,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 216).clamp(1.0, 1.8);
                  final horizontalPadding = 12.0 * scale;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          14 * scale,
                          horizontalPadding,
                          18 * scale,
                        ),
                        children: [
                          _buildHeader(scale),
                          SizedBox(height: 18 * scale),
                          ..._menuItems()
                              .map((item) => _buildMenuRow(item, scale)),
                        ],
                      ),
                    ),
                  );
                },
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
        icon: Icons.sports_tennis_rounded,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          const VenueActivityListScreen(),
        ),
      ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Business & Verification',
          icon: Icons.verified_user_outlined,
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
            const ManageTeamScreen(),
          ),
        ),
      _ProfileMenuItem(
        title: 'Help & Support',
        icon: Icons.support_agent_rounded,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          const ContactSupportFormScreen(),
        ),
      ),
      if (_isPartner)
        _ProfileMenuItem(
          title: 'Partner Agreement',
          icon: Icons.article_outlined,
          onTap: () => CommonUtilities.NavigateWithPush(
            context,
            const ViewDocumentScreen(),
          ),
        ),
      _ProfileMenuItem(
        title: 'App Controls',
        icon: Icons.logout_rounded,
        onTap: () => CommonUtilities.NavigateWithPush(
          context,
          const SettingsScreen(),
        ),
      ),
    ];
  }

  Widget _buildHeader(double scale) {
    return Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 22 * scale,
                width: 22 * scale,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.black,
                  size: 12 * scale,
                ),
              ),
            ),
            SizedBox(width: 10 * scale),
            Text(
              'Hey, Partner!',
              style: TextStyle(
                fontSize: 12 * scale,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: AppColors.darkBlack,
              ),
            ),
          ],
        ),
        SizedBox(height: 22 * scale),
        ClipOval(
          child: Container(
            width: 68 * scale,
            height: 68 * scale,
            color: const Color(0xFFC8C8C8),
            child: _avatarUrl.isNotEmpty
                ? Image.network(
                    _avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        SizedBox(height: 9 * scale),
        Text(
          _profileName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11 * scale,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
          ),
        ),
        SizedBox(height: 3 * scale),
        Text(
          _profileEmail.isNotEmpty ? _profileEmail : ' ',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 8 * scale,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w500,
            color: AppColors.black1,
          ),
        ),
        SizedBox(height: 8 * scale),
        InkWell(
          onTap: _openProfile,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 24 * scale,
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 8 * scale,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: AppColors.yellow,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return const Icon(
      Icons.person_outline_rounded,
      color: AppColors.black1,
      size: 48,
      semanticLabel: 'Partner profile',
    );
  }

  Widget _buildMenuRow(_ProfileMenuItem item, double scale) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 31 * scale,
        margin: EdgeInsets.only(bottom: 7 * scale),
        padding: EdgeInsets.fromLTRB(8 * scale, 0, 7 * scale, 0),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              height: 22 * scale,
              width: 22 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E2E2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                item.icon,
                color: AppColors.black,
                size: 14 * scale,
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8 * scale,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlack,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.black,
              size: 12 * scale,
            ),
          ],
        ),
      ),
    );
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
