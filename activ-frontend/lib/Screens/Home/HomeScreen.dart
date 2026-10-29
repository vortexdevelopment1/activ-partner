import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

import '../../Utills/common_utilities.dart';
import '../../Utills/performance_logger.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';
import '../Menu/MenuScreen.dart';
import '../default_partner_avatar.dart';
import 'ManagePricingScreen.dart';
import 'ManageTeamScreen.dart';
import 'ManageSlotsScreen.dart';
import 'ManageBookingsScreen.dart';
import 'BankAccountScreen.dart';
import 'ManagerHomeScreen.dart';
import 'dashboard_setup_cards.dart';
import 'NotificationsScreen.dart';

// ── Dummy data models ─────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  final String change;
  final bool positive;
  final IconData icon;
  final Color iconColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
    required this.icon,
    required this.iconColor,
  });
}

class _BookingItem {
  final String name;
  final String service;
  final String date;
  final String time;
  final String amount;
  final String persons;
  final String status;
  final DateTime? startsAt;

  const _BookingItem({
    required this.name,
    required this.service,
    required this.date,
    required this.time,
    required this.amount,
    required this.persons,
    required this.status,
    this.startsAt,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<HomeScreen> createState() => _State();
}

class _State extends State<HomeScreen> {
  String venueName = '';
  String _venueId = '';
  String _avatar = '';
  bool _isBookingsPaused = false;
  bool _pausing = false;
  bool _isPartner = true;
  bool _permBooking = true;
  bool _permPricing = true;

  /// Toggle: true = approved venue (screenshot 1), false = new venue (screenshot 2)
  bool _isApproved = false;
  bool _needsPricing = false, _needsTeam = false, _needsBankAccount = false;
  String? _setupError;
  bool _dashboardLoading = false;

  // ── Dummy stats ──────────────────────────────────────────────────────────────
  List<_StatItem> _approvedStats = const [
    _StatItem(label: 'Bookings', value: '0', change: '0 vs last month', positive: true, icon: Icons.calendar_today_outlined, iconColor: Color(0xFF9E9E9E)),
    _StatItem(label: 'Revenue', value: '\u20b90', change: '0 vs last month', positive: true, icon: Icons.currency_rupee, iconColor: Color(0xFF7C3AED)),
    _StatItem(label: 'Availability', value: '0%', change: '0 vs last month', positive: true, icon: Icons.access_time, iconColor: Color(0xFF16A34A)),
    _StatItem(label: 'Avg Rating', value: '0.0', change: '0 vs last month', positive: true, icon: Icons.star_border, iconColor: Color(0xFFF59E0B)),
  ];

  final List<_StatItem> _newVenueStats = const [
    _StatItem(label: 'Bookings', value: '0', change: '0% vs last month', positive: true, icon: Icons.calendar_today_outlined, iconColor: Color(0xFF9E9E9E)),
    _StatItem(label: 'Revenue', value: '\u20b90', change: '0 vs last month', positive: true, icon: Icons.currency_rupee, iconColor: Color(0xFF7C3AED)),
    _StatItem(label: 'Availability', value: '0%', change: '0 vs last month', positive: true, icon: Icons.access_time, iconColor: Color(0xFF16A34A)),
    _StatItem(label: 'Avg Rating', value: '0.0', change: '0 vs last month', positive: true, icon: Icons.star_border, iconColor: Color(0xFFF59E0B)),
  ];

  List<_BookingItem> _bookings = const [];

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _redirectTeamMemberIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (CommonUtilities.firstTimeLoginSignup == 'yes') {
        CommonUtilities.firstTimeLoginSignup = '';
        _showThankYouDialog();
      }
    });
    _fetchVenueName();
    _loadUserPermissions();
    _loadProfilePhoto();
  }

  Future<void> _redirectTeamMemberIfNeeded() async {
    final userType = checkString(await SharedPreference.readStr('user_type'));
    if (userType != 'team_member' || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ManagerHomeScreen(client: widget.client),
      ),
    );
  }

  Future<void> _loadUserPermissions() async {
    final userType = checkString(await SharedPreference.readStr('user_type'));
    final permsStr = checkString(await SharedPreference.readStr('permissions'));
    if (!mounted) return;
    if (userType == 'team_member') {
      Map perms = {};
      try { perms = jsonDecode(permsStr); } catch (_) {}
      setState(() {
        _isPartner = false;
        _permBooking = perms['bookingManagement'] == true;
        _permPricing = perms['pricingControl'] == true;
      });
    }
  }

  Future<void> _fetchVenueName() async {
    final requestId = PerformanceLogger.id();
    final started = DateTime.now();
    PerformanceLogger.apiStart(requestId, 'GET', MY_APPROVED_VENUES_URL, 1);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      if (token.isEmpty) {
        PerformanceLogger.apiEnd(requestId, 'GET', MY_APPROVED_VENUES_URL, 1,
            DateTime.now().difference(started).inMilliseconds, 'auth_missing');
        return;
      }

      final res = await (widget.client?.get ?? http.get)(
        Uri.parse(MY_APPROVED_VENUES_URL),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        PerformanceLogger.apiEnd(requestId, 'GET', MY_APPROVED_VENUES_URL, 1,
            DateTime.now().difference(started).inMilliseconds, 'success',
            status: res.statusCode, bytes: res.bodyBytes.length);
        final body = jsonDecode(res.body);
        final List items = (body['data'] is List) ? body['data'] : [];
        if (items.isNotEmpty) {
          final venue = items.last;
          final name = venue['name']?.toString() ?? '';
          final id = venue['id']?.toString() ?? '';
          final paused = venue['bookingAccept'] == false;
          if (mounted) {
            setState(() {
            if (name.isNotEmpty) { venueName = name; }
            _venueId = id;
            _isBookingsPaused = paused;
            _isApproved = true;
            _needsPricing = dashboardNeedsPricing(Map<String, dynamic>.from(venue));
            _setupError = null;
          });
          }
          if (venue is Map) {
            await _loadDashboardData(Map<String, dynamic>.from(venue), token);
          }
        } else if (mounted) {
          setState(() {
            _isApproved = false;
            _needsPricing = false;
            _needsTeam = false;
            _needsBankAccount = false;
            _setupError = null;
            _approvedStats = _emptyStats();
            _bookings = const [];
          });
        }
        if (items.isNotEmpty && checkString(await SharedPreference.readStr('user_type')) != 'team_member') {
          final team = await (widget.client?.get ?? http.get)(Uri.parse(TEAM_URL),
            headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
          if (team.statusCode != 200) throw Exception('Unable to check team setup.');
          final data = jsonDecode(team.body)['data'] as List;
          if (mounted) setState(() => _needsTeam = data.isEmpty);
        }
        if (items.isNotEmpty && checkString(await SharedPreference.readStr('user_type')) != 'team_member') {
          final accounts = await (widget.client?.get ?? http.get)(
            Uri.parse('$BASE_URL/bank-accounts/my'),
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 15));
          if (accounts.statusCode != 200) throw Exception('Unable to check bank account setup.');
          final accountData = jsonDecode(accounts.body)['data'];
          if (mounted) setState(() => _needsBankAccount = accountData is List && accountData.isEmpty);
        }
      } else {
        PerformanceLogger.apiEnd(requestId, 'GET', MY_APPROVED_VENUES_URL, 1,
            DateTime.now().difference(started).inMilliseconds, 'http_error',
            status: res.statusCode, bytes: res.bodyBytes.length);
        throw Exception('Unable to check venue setup.');
      }
    } catch (e) {
      PerformanceLogger.apiEnd(requestId, 'GET', MY_APPROVED_VENUES_URL, 1,
          DateTime.now().difference(started).inMilliseconds,
          e is TimeoutException ? 'timeout' : 'network_error');
      CommonUtilities.showLog('_fetchVenueName error: $e');
      if (mounted) setState(() => _setupError = 'Unable to check setup.');
    }
  }

  List<_StatItem> _emptyStats() => const [
        _StatItem(label: 'Bookings', value: '0', change: '0 vs last month', positive: true, icon: Icons.calendar_today_outlined, iconColor: Color(0xFF9E9E9E)),
        _StatItem(label: 'Revenue', value: '\u20b90', change: '0 vs last month', positive: true, icon: Icons.currency_rupee, iconColor: Color(0xFF7C3AED)),
        _StatItem(label: 'Availability', value: '0%', change: '0 vs last month', positive: true, icon: Icons.access_time, iconColor: Color(0xFF16A34A)),
        _StatItem(label: 'Avg Rating', value: '0.0', change: '0 vs last month', positive: true, icon: Icons.star_border, iconColor: Color(0xFFF59E0B)),
      ];

  Future<void> _loadDashboardData(
      Map<String, dynamic> venue, String token) async {
    if (_dashboardLoading) return;
    if (mounted) setState(() => _dashboardLoading = true);
    try {
      final services = venue['services'] is List ? venue['services'] as List : const [];
      final recent = <_BookingItem>[];
      final occupancies = <num>[];
      final ratings = <num>[];
      var bookingCount = 0;
      num revenue = 0;

      for (final service in services.whereType<Map>()) {
        final serviceId = (service['id'] ??
                service['activityId'] ??
                service['activity_id'])
            ?.toString();
        if (serviceId == null || serviceId.isEmpty) continue;
        final response = await (widget.client?.get ?? http.get)(
          Uri.parse('$BASE_URL/venues/activities/$serviceId/management'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 15));
        final body = jsonDecode(response.body);
        if (response.statusCode == 403) continue;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(body['message'] ?? 'Unable to load dashboard.');
        }
        final data = body['data'] is Map ? body['data'] as Map : const {};
        final activityName = data['name']?.toString() ??
            service['name']?.toString() ??
            service['title']?.toString() ??
            'Activity';
        bookingCount += _asInt(data['bookingCount']);
        revenue += _asNum(data['earnings']);
        final occupancy = _asNullableNum(data['occupancy']);
        if (occupancy != null) occupancies.add(occupancy);

        final reviews = data['reviews'] is List ? data['reviews'] as List : const [];
        for (final review in reviews.whereType<Map>()) {
          final rating = _asNullableNum(review['rating']);
          if (rating != null) ratings.add(rating);
        }

        final bookings = data['bookings'] is List ? data['bookings'] as List : const [];
        for (final booking in bookings.whereType<Map>()) {
          recent.add(_bookingFromManagement(
            Map<String, dynamic>.from(booking),
            activityName,
          ));
        }
      }

      recent.sort((a, b) {
        final ad = a.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      final avgOccupancy = occupancies.isEmpty
          ? 0
          : (occupancies.reduce((a, b) => a + b) / occupancies.length).round();
      final avgRating = ratings.isEmpty
          ? 0
          : ratings.reduce((a, b) => a + b) / ratings.length;

      if (!mounted) return;
      setState(() {
        _approvedStats = [
          _StatItem(label: 'Bookings', value: '$bookingCount', change: 'Live data', positive: true, icon: Icons.calendar_today_outlined, iconColor: const Color(0xFF9E9E9E)),
          _StatItem(label: 'Revenue', value: _formatMoney(revenue), change: 'Live data', positive: true, icon: Icons.currency_rupee, iconColor: const Color(0xFF7C3AED)),
          _StatItem(label: 'Availability', value: '$avgOccupancy%', change: 'Next 7 days', positive: true, icon: Icons.access_time, iconColor: const Color(0xFF16A34A)),
          _StatItem(label: 'Avg Rating', value: avgRating.toStringAsFixed(1), change: '${ratings.length} reviews', positive: true, icon: Icons.star_border, iconColor: const Color(0xFFF59E0B)),
        ];
        _bookings = recent.take(3).toList();
      });
    } catch (e) {
      CommonUtilities.showLog('_loadDashboardData error: $e');
      if (mounted) setState(() => _setupError = 'Unable to load dashboard.');
    } finally {
      if (mounted) setState(() => _dashboardLoading = false);
    }
  }

  _BookingItem _bookingFromManagement(
      Map<String, dynamic> json, String fallbackActivity) {
    final startsAt = DateTime.tryParse(json['startsAt']?.toString() ?? '');
    final local = startsAt?.toLocal();
    final participants = _asInt(json['participants']);
    return _BookingItem(
      name: json['customerName']?.toString() ?? 'Customer',
      service: json['activity']?.toString() ?? fallbackActivity,
      date: local == null ? '' : DateFormat('dd MMM yyyy').format(local),
      time: local == null ? '' : DateFormat('hh:mm a').format(local),
      amount: _formatMoney(_asNum(json['amount'])),
      persons: '$participants ${participants == 1 ? 'person' : 'persons'}',
      status: _displayStatus(json['status']?.toString()),
      startsAt: startsAt,
    );
  }

  String _displayStatus(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'cancelled' || normalized == 'canceled') return 'Cancelled';
    if (normalized == 'no_show' || normalized == 'no show') return 'No Show';
    if (normalized.isEmpty) return 'Upcoming';
    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);
  }

  int _asInt(dynamic value) => _asNum(value).round();

  num _asNum(dynamic value) => _asNullableNum(value) ?? 0;

  num? _asNullableNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      if (token.isEmpty) return;
      final userType = checkString(await SharedPreference.readStr('user_type'));

      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 201) return;
      final body = jsonDecode(response.body);
      final data = body['data'];
      if (data is! Map) return;
      final profile = userType == 'team_member'
          ? data['member']
          : (data['partner'] ?? data);
      if (profile is! Map) return;

      var avatar =
          (profile['avatarUrl'] ?? profile['profileImage'] ?? '').toString();
      if (avatar.startsWith('/')) {
        avatar = Uri.parse(BASE_URL).resolve(avatar).toString();
      }
      if (mounted) setState(() => _avatar = avatar);
    } catch (e) {
      CommonUtilities.showLog('_loadProfilePhoto error: $e');
    }
  }

  Future<void> _openSetup(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _fetchVenueName();
  }

  void _noAccess() => CommonUtilities.createSnackBar(
      context, "You don't have access to this feature.");

  Future<void> _pauseBookings() async {
    if (_venueId.isEmpty || _pausing) return;
    setState(() => _pausing = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final res = await http.patch(
        Uri.parse('$PAUSE_BOOKINGS_URL/$_venueId/pause-bookings'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'bookingAccept': _isBookingsPaused}),
      );
      CommonUtilities.showLog('pause-bookings: ${res.statusCode} ${res.body}');
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _isBookingsPaused = !_isBookingsPaused);
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to update booking status';
        CommonUtilities.createSnackBar(context, msg is List ? msg.first : msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog('_pauseBookings error: $e');
    } finally {
      if (mounted) setState(() => _pausing = false);
    }
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 20),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close,
                        color: AppColors.darkBlack, size: 22),
                    tooltip: 'Close',
                  ),
                ),
                SizedBox(
                  width: 204,
                  height: 120,
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 5),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Welcome to ACTIV Partner! Your account is approved and your dashboard is ready. You can now manage bookings, pricing, slots, and your team from here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Satoshi',
                      color: AppColors.darkBlack,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                    },
                    child: getButtonBlack(context, 'Get Started', 'HomeScreen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        decoration: context.getYellowGradient,
        child: SafeArea(
          top: true,
          bottom: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 20),
                    children: [
                      _buildGreeting(),
                      const SizedBox(height: 16),
                      if (_isPartner && _isApproved) DashboardSetupCards(
                        pricingRequired: _needsPricing, teamRequired: _needsTeam,
                        bankAccountRequired: _needsBankAccount,
                        onPricing: () => _openSetup(ManagePricingScreen(client: widget.client)),
                        onTeam: () => _openSetup(ManageTeamScreen(client: widget.client)),
                        onBankAccount: () => _openSetup(BankAccountScreen(client: widget.client)),
                      ),
                      if (_isPartner && _setupError != null) TextButton.icon(
                        onPressed: _fetchVenueName, icon: const Icon(Icons.refresh), label: Text('$_setupError Retry')),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Quick Actions'),
                      const SizedBox(height: 10),
                      _buildQuickActionsGrid(),
                      if (_isApproved) ...[
                        const SizedBox(height: 16),
                        _buildVenueStatusCard(),
                      ],
                      const SizedBox(height: 20),
                      _buildSectionLabel('Insights & Growth'),
                      const SizedBox(height: 10),
                      _buildInsightsRow(),
                      const SizedBox(height: 20),
                      _buildRecentBookingsHeader(),
                      const SizedBox(height: 10),
                      if (_isApproved && _bookings.isNotEmpty)
                        ..._bookings.map(_buildBookingCard)
                      else
                        _buildEmptyBookings(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────

  Widget _buildHomeAvatar() {
    Widget fallback() => const DefaultPartnerAvatar();

    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: _avatar.isNotEmpty
            ? Image.network(
                _avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation1, animation2) =>
                      MenuScreen(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
              if (mounted) _loadProfilePhoto();
            },
            child: _buildHomeAvatar(),
          ),
          const Spacer(),
          Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => NotificationsScreen(client: widget.client))),
            borderRadius: BorderRadius.circular(4),
            child: SvgPicture.asset(
              'assets/ic_notifications.svg',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ── Greeting ──────────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Hi! 👋 Here\'s what\'s happening at ',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w400,
              height: 1.375, // 22px / 16px
              letterSpacing: 0,
              color: Color(0xFF1F1F1F),
            ),
          ),
          TextSpan(
            text: venueName.isNotEmpty ? venueName : 'your venue',
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              height: 1.375,
              letterSpacing: 0,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA banners (new/unapproved state only) ───────────────────────────────────

  Widget _buildCTABanners() {
    return Container(
      height: 130,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ctaBanner(
            color: const Color(0xFFE0F0F8),
            title: 'Add pricing to start accepting bookings',
            subtitle:
                'Congratulations on your venue\'s approval!\nSet your prices per slot and start earning.',
            buttonLabel: 'Set Pricing →',
          ),
          const SizedBox(width: 12),
          _ctaBanner(
            color: const Color(0xFFF0E8FF),
            title: 'Invite team members',
            subtitle:
                'Add team members to help\nmanage your venue efficiently.',
            buttonLabel: 'Invite Now →',
          ),
        ],
      ),
    );
  }

  Widget _ctaBanner({
    required Color color,
    required String title,
    required String subtitle,
    required String buttonLabel,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width - 50,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Satoshi',
                        color: AppColors.darkBlack)),
              ),
              const Icon(Icons.close, size: 16, color: AppColors.darkBlack),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Satoshi',
                  color: AppColors.black1)),
          const Spacer(),
          Container(
            width: double.infinity,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(buttonLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats grid ────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final stats = _isApproved ? _approvedStats : _newVenueStats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCell(stats[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCell(stats[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCell(stats[2])),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCell(stats[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCell(_StatItem stat) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w500,
                        height: 1.429, // 20px / 14px
                        letterSpacing: 0,
                        color: Color(0xFF3F3F3F))),
              ),
              Icon(stat.icon, size: 18, color: stat.iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: const TextStyle(
                fontSize: 24,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                height: 1.333, // 32px / 24px
                letterSpacing: 0,
                color: Color(0xFF1F1F1F)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Builder(builder: (_) {
            const base = TextStyle(
              fontSize: 12,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w500,
              height: 1.333,
              letterSpacing: 0,
            );
            final parts = stat.change.split(' vs ');
            final pct = parts.first;
            return Text.rich(TextSpan(children: [
              TextSpan(
                text: pct,
                style: base.copyWith(
                  color: stat.positive
                      ? const Color(0xFF2EB944)
                      : const Color(0xFFFE6B6B),
                ),
              ),
              if (parts.length > 1)
                TextSpan(
                  text: ' vs ${parts[1]}',
                  style: base.copyWith(color: const Color(0xFF1F1F1F)),
                ),
            ]));
          }),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisExtent: 150 + (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 32).toDouble() * 5,
      children: [
        _actionCard(
          title: 'Manage Bookings',
          subtitle: 'Manage venue bookings',
          image: 'assets/ic_manage_booking.png',
          onTap: _permBooking
              ? () => CommonUtilities.NavigateWithPush(context,
                  ManageBookingsScreen(venueId: _venueId, client: widget.client))
              : _noAccess,
        ),
        _actionCard(
          title: 'Manage Team',
          subtitle: 'Add team members',
          image: 'assets/ic_manage_team.png',
          onTap: _isPartner
              ? () => _openSetup(ManageTeamScreen(client: widget.client))
              : _noAccess,
        ),
        _actionCard(
          title: 'Manage Slots',
          subtitle: 'Add or update availability',
          image: 'assets/ic_manage_slot.png',
          onTap: _isPartner
              ? () => _openSetup(ManageSlotsScreen(client: widget.client))
              : _noAccess,
        ),
        _actionCard(
          title: 'Manage Pricing',
          subtitle: 'Manage pricing strategy',
          image: 'assets/ic_manage_price.png',
          onTap: _permPricing
              ? () => _openSetup(ManagePricingScreen(client: widget.client))
              : _noAccess,
        ),
      ],
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required String image,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 132,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    height: 1.429, // 20px / 14px
                    letterSpacing: 0,
                    color: Color(0xFF1F1F1F))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    height: 1.333, // 16px / 12px
                    letterSpacing: 0,
                    color: Color(0xFF7F7F7F)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Image.asset(image, width: 60, height: 60),
            ),
          ],
        ),
      ),
    );
  }

  // ── Venue Status ──────────────────────────────────────────────────────────────

  Widget _buildVenueStatusCard() {
    const base = TextStyle(
      fontSize: 12,
      fontFamily: 'Satoshi',
      height: 1.333, // 16px / 12px
      letterSpacing: 0,
      color: Color(0xFF3F3F3F),
    );
    const medium = TextStyle(fontWeight: FontWeight.w500);
    const bold = TextStyle(fontWeight: FontWeight.w700);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            children: [
              const Text('Venue Status',
                  style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      height: 1.429, // 20px / 14px
                      letterSpacing: 0,
                      color: Color(0xFF1F1F1F))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _isBookingsPaused
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFE8F7EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_isBookingsPaused ? 'InACTIV' : 'ACTIV',
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        height: 1.333, // 16px / 12px
                        letterSpacing: 0,
                        color: _isBookingsPaused
                            ? const Color(0xFFE53935)
                            : const Color(0xFF16A34A))),
              ),
            ],
          ),
          Text.rich(TextSpan(style: base.merge(medium), children: [
            const TextSpan(text: 'Your venue is '),
            TextSpan(text: _isBookingsPaused ? 'InACTIV' : 'ACTIV', style: bold),
            TextSpan(text: _isBookingsPaused
                ? ' and is not accepting new bookings.'
                : ' and is accepting bookings.'),
          ])),
          Text.rich(TextSpan(style: base.merge(medium), children: [
            const TextSpan(text: 'Go '),
            const TextSpan(text: 'InACTIV', style: bold),
            const TextSpan(text: ' and temporarily stop accepting bookings?'),
          ])),
          OutlinedButton.icon(
            onPressed: _pausing ? null : () {
            if (!_isPartner) {
              CommonUtilities.createSnackBar(context, 'Only the venue partner can pause or resume bookings.');
              return;
            }
            _pauseBookings();
          },
            icon: _pausing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFE6B6B)))
                : Icon(_isBookingsPaused ? Icons.play_arrow : Icons.pause, color: const Color(0xFFFE6B6B), size: 16),
            label: Text(_isBookingsPaused ? 'Resume Bookings' : 'Pause Bookings',
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                    color: Color(0xFFFE6B6B))),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFFE6B6B), width: 1),
              minimumSize: const Size(double.infinity, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Insights row ──────────────────────────────────────────────────────────────

  Widget _buildInsightsRow() {
    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: 0.4,
            child: _actionCard(
              title: 'Analytics',
              subtitle: 'View detailed insights',
              image: 'assets/ic_analytics.png',
              onTap: () => CommonUtilities.createSnackBar(context, 'Coming soon!'),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Opacity(
            opacity: 0.4,
            child: _actionCard(
              title: 'Offers & Deals',
              subtitle: 'Manage promotions',
              image: 'assets/ic_deals.png',
              onTap: () => CommonUtilities.createSnackBar(context, 'Coming soon!'),
            ),
          ),
        ),
      ],
    );
  }

  // ── Recent Bookings ───────────────────────────────────────────────────────────

  Widget _buildRecentBookingsHeader() {
    return Row(
      children: [
        const Text('Recent Bookings',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                height: 1.375, // 22px / 16px
                letterSpacing: 0,
                color: Color(0xFF1F1F1F))),
        const Spacer(),
        InkWell(
          onTap: _permBooking
              ? () => CommonUtilities.NavigateWithPush(context,
                  ManageBookingsScreen(venueId: _venueId, client: widget.client))
              : _noAccess,
          child: const Text('View all →',
              style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                  height: 1.429, // 20px / 14px
                  letterSpacing: 0,
                  color: Color(0xFF9D38EB))),
        ),
      ],
    );
  }

  Widget _buildBookingCard(_BookingItem b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          // Title + description block (gap 4)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(b.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Satoshi',
                              color: AppColors.darkBlack)),
                    ),
                    _statusBadge(b.status),
                  ],
                ),
                Text(
                  '${b.service}  |  ${b.date}  |  ${b.time}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Satoshi',
                      color: AppColors.black1),
                ),
            ],
          ),
          // Price row (height 22, gap 8)
          SizedBox(
            height: 22,
            child: Row(
              spacing: 8,
              children: [
                Text(
                  b.amount,
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      color: AppColors.darkBlack),
                ),
                const Text('|',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.black1)),
                Text(
                  b.persons,
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      color: AppColors.darkBlack),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Upcoming':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFF57C00);
        break;
      case 'Ongoing':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Cancelled':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        break;
      case 'No Show':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'Completed':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              fontSize: 11,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              color: fg)),
    );
  }

  Widget _buildEmptyBookings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Image.asset('assets/ic_no_bookings.png', width: 80, height: 80),
          const SizedBox(height: 12),
          const Text('No bookings found',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  height: 22 / 16,
                  letterSpacing: 0,
                  color: Color(0xFF1F1F1F))),
          const SizedBox(height: 4),
          const Text('Set your pricing to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w400,
                  height: 20 / 14,
                  letterSpacing: 0,
                  color: Color(0xFF1F1F1F))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _permPricing
                ? () => CommonUtilities.NavigateWithPush(context, const ManagePricingScreen())
                : _noAccess,
            child: Container(
              width: 350,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9D38EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Set Pricing',
                    style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontFamily: 'Satoshi',
        fontWeight: FontWeight.w700,
        height: 1.375, // 22px / 16px
        letterSpacing: 0,
        color: Color(0xFF1F1F1F),
      ),
    );
  }
}
