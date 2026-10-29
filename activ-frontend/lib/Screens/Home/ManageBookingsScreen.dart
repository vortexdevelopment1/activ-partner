
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_svg/svg.dart';

import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../Menu/MenuScreen.dart';
import '../default_partner_avatar.dart';

DateTime _indiaTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 5, minutes: 30));

enum _BookingStatus { upcoming, ongoing, canceled, noShow, completed, pending }

class _Booking {
  _Booking({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.activity,
    required this.date,
    required this.time,
    required this.bookedOn,
    required this.participants,
    required this.totalAmount,
    required this.commission,
    required this.paymentMode,
    required _BookingStatus status,
    this.endsAt,
    this.checkedIn = false,
  }) : _status = status;

  final String id;
  final String reference;
  final String customerName;
  final String phone;
  final String email;
  final String activity;
  final String date;
  final String time;
  final String bookedOn;
  final int participants;
  final double totalAmount;
  final double commission;
  final String paymentMode;
  final DateTime? endsAt;
  bool checkedIn;
  _BookingStatus _status;
  _BookingStatus get status {
    if (!checkedIn && endsAt != null && !endsAt!.isAfter(DateTime.now()) &&
        (_status == _BookingStatus.upcoming || _status == _BookingStatus.ongoing)) {
      return _BookingStatus.noShow;
    }
    return _status;
  }
  set status(_BookingStatus value) {
    _status = value;
    if (value == _BookingStatus.ongoing) checkedIn = true;
  }

  double get earnings => totalAmount - commission;

  factory _Booking.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? json['user'] as Map : const {};
    final service = json['service'] is Map ? json['service'] as Map : const {};
    final first = user['firstName']?.toString() ?? '';
    final last = user['lastName']?.toString() ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final total = double.tryParse(json['totalAmount']?.toString() ?? '') ?? 0;
    return _Booking(
      id: json['id']?.toString() ?? '',
      reference: (json['bookingReference'] ??
              json['booking_reference'] ??
              json['public_code'] ??
              _displayWalkInReference(json['id']))
          .toString(),
      customerName:
          '$first $last'.trim().isEmpty ? 'Customer' : '$first $last'.trim(),
      phone: user['phone']?.toString() ?? '0',
      email: user['email']?.toString() ?? '0',
      activity:
          service['name']?.toString() ?? service['title']?.toString() ?? '0',
      date: _formatDate(json['bookingDate']?.toString()),
      time: _formatTime(json['startTime']?.toString()),
      bookedOn: createdAt == null
          ? '0'
          : DateFormat('dd MMM yyyy').format(createdAt.toLocal()),
      participants: int.tryParse(json['participants']?.toString() ?? '') ?? 0,
      totalAmount: total,
      commission: total * .15,
      paymentMode: json['paymentMode']?.toString() ?? 'Not available',
      status: _statusFromApi(json['status']?.toString()),
    );
  }

  factory _Booking.fromManagement(
      Map<String, dynamic> json, String fallbackActivity) {
    final startsAt = DateTime.tryParse(json['startsAt']?.toString() ?? '');
    final local = startsAt == null ? null : _indiaTime(startsAt);
    final total = double.tryParse(json['amount']?.toString() ?? '') ?? 0;
    return _Booking(
      id: json['id']?.toString() ?? '',
      reference: (json['bookingReference'] ??
              json['booking_reference'] ??
              json['public_code'] ??
              _displayWalkInReference(json['id']))
          .toString(),
      customerName: json['customerName']?.toString() ?? 'Customer',
      phone: json['phone']?.toString() ?? '0',
      email: json['email']?.toString() ?? '0',
      activity: json['activity']?.toString() ?? fallbackActivity,
      date: local == null ? '0' : DateFormat('dd MMM yyyy').format(local),
      time: local == null ? '0' : DateFormat('hh:mm a').format(local),
      bookedOn: _formatDate(
          json['bookedOn']?.toString() ?? json['startsAt']?.toString()),
      participants: int.tryParse(json['participants']?.toString() ?? '') ?? 0,
      totalAmount: total,
      commission: total * .15,
      paymentMode: json['paymentMode']?.toString() ?? 'Not available',
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? ''),
      checkedIn: json['checkedIn'] == true,
      status: _statusFromApi(json['status']?.toString()),
    );
  }

static String _displayWalkInReference(Object? value) {
  final id = value?.toString() ?? '';
  if (id.isEmpty) return 'Not available';
  return id.contains('-') && id.length >= 32
      ? 'WI-${id.substring(0, 8).toUpperCase()}'
      : id;
}

  static String _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    return parsed == null ? '0' : DateFormat('dd MMM yyyy').format(parsed);
  }

  static String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return '0';
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final date = DateTime(2026, 1, 1, hour, minute);
    return DateFormat('hh:mm a').format(date);
  }

  static _BookingStatus _statusFromApi(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'confirmed' || 'upcoming' => _BookingStatus.upcoming,
      'completed' => _BookingStatus.completed,
      'cancelled' || 'canceled' => _BookingStatus.canceled,
      'no_show' || 'no show' => _BookingStatus.noShow,
      'ongoing' => _BookingStatus.ongoing,
      _ => _BookingStatus.pending,
    };
  }
}

class ManageBookingsScreen extends StatefulWidget {
  const ManageBookingsScreen({
    super.key,
    this.venueId = '',
    this.client,
    this.managerLayout = false,
  });

  final String venueId;
  final http.Client? client;
  final bool managerLayout;

  @override
  State<ManageBookingsScreen> createState() => _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends State<ManageBookingsScreen> {
  late final http.Client _client;
  final _searchCtrl = TextEditingController();
  final _money = NumberFormat.currency(
      locale: 'en_IN', symbol: '\u20b9', decimalDigits: 2);
  final _tabs = ['All', 'Upcoming', 'Past'];
  final List<_Booking> _bookings = [];
  int _selectedTab = 0;
  bool _loading = true;
  final _bookingAction = ValueNotifier<String?>(null);
  bool get _saving => _bookingAction.value != null;
  String? _actionError;
  String _searchQuery = '';
  String _venueId = '';
  String _venueName = '';
  String _avatarUrl = '';
  String? _error;
  Timer? _statusTimer;
  final _statusTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    _venueId = widget.venueId;
    if (widget.managerLayout) _loadManagerAvatar();
    _load();
  }

  Future<void> _loadManagerAvatar() async {
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      if (token.isEmpty) return;
      final response = await _client.get(Uri.parse(AUTH_PROFILE_URL), headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 201) return;
      final body = jsonDecode(response.body);
      final member = body['data']?['member'];
      if (member is! Map) return;
      var avatar =
          (member['avatarUrl'] ?? member['profileImage'] ?? '').toString();
      if (avatar.startsWith('/')) {
        avatar = Uri.parse(BASE_URL).resolve(avatar).toString();
      }
      if (mounted) setState(() => _avatarUrl = avatar);
    } catch (_) {
      // The default profile image remains visible if the avatar cannot load.
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _statusTick.dispose();
    _bookingAction.dispose();
    _searchCtrl.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  void _scheduleStatusUpdate() {
    _statusTimer?.cancel();
    final active = _bookings.where((b) => !b.checkedIn && b.endsAt != null &&
        (b.status == _BookingStatus.upcoming || b.status == _BookingStatus.ongoing)).toList()
      ..sort((a, b) => a.endsAt!.compareTo(b.endsAt!));
    if (active.isEmpty) return;
    final end = active.first.endsAt!;
    final delay = end.difference(DateTime.now());
    _statusTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      setState(() {
        for (final booking in active) {
          if (!booking.endsAt!.isAfter(end)) booking.status = _BookingStatus.noShow;
        }
      });
      _statusTick.value++;
      _scheduleStatusUpdate();
    });
  }

  List<_Booking> get _filtered {
    var list = _bookings.where((booking) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return booking.customerName.toLowerCase().contains(q) ||
          booking.reference.toLowerCase().contains(q) ||
          booking.id.toLowerCase().contains(q) ||
          booking.activity.toLowerCase().contains(q);
    }).toList();
    if (_selectedTab == 1) {
      list = list
          .where((booking) =>
              booking.status == _BookingStatus.upcoming ||
              booking.status == _BookingStatus.ongoing ||
              booking.status == _BookingStatus.pending)
          .toList();
    } else if (_selectedTab == 2) {
      list = list
          .where((booking) =>
              booking.status == _BookingStatus.completed ||
              booking.status == _BookingStatus.canceled ||
              booking.status == _BookingStatus.noShow)
          .toList();
    }
    return list;
  }

  int get _totalBookings => _bookings.length;

  double get _totalRevenue {
    return _bookings
        .where((booking) => booking.status != _BookingStatus.canceled)
        .fold(0, (sum, booking) => sum + booking.totalAmount);
  }

  int get _completed => _bookings
      .where((booking) => booking.status == _BookingStatus.completed)
      .length;

  Future<Map<String, String>> _headers() async {
    final token = await SharedPreference.readStr('jwt_token');
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await _headers();
      var venueId = _venueId;
      var venueName = _venueName;
      List services = const [];
      if (venueId.isEmpty) {
        final venues = await _client
            .get(Uri.parse(MY_APPROVED_VENUES_URL), headers: headers)
            .timeout(const Duration(seconds: 15));
        final body = jsonDecode(venues.body);
        if (venues.statusCode < 200 || venues.statusCode >= 300) {
          throw Exception(body['message'] ?? 'Unable to load venue.');
        }
        final items = body['data'] is List ? body['data'] as List : const [];
        final venue = items.isEmpty ? null : items.last;
        venueId = venue is Map ? venue['id']?.toString() ?? '' : '';
        venueName = venue is Map ? venue['name']?.toString() ?? '' : '';
        services = venue is Map && venue['services'] is List
            ? venue['services'] as List
            : const [];
      } else {
        final venues = await _client
            .get(Uri.parse(MY_APPROVED_VENUES_URL), headers: headers)
            .timeout(const Duration(seconds: 15));
        final body = jsonDecode(venues.body);
        if (venues.statusCode < 200 || venues.statusCode >= 300) {
          throw Exception(body['message'] ?? 'Unable to load venue.');
        }
        final items = body['data'] is List ? body['data'] as List : const [];
        final venue = items.whereType<Map>().cast<Map>().firstWhere(
            (item) => item['id']?.toString() == venueId,
            orElse: () => const {});
        venueName = venue['name']?.toString() ?? '';
        services =
            venue['services'] is List ? venue['services'] as List : const [];
      }
      if (venueId.isEmpty) {
        if (mounted) {
          setState(() {
            _venueId = '';
            _venueName = '';
            _bookings.clear();
          });
        }
        return;
      }
      final collected = <_Booking>[];
      for (final service in services.whereType<Map>()) {
        final serviceId =
            (service['id'] ?? service['activityId'] ?? service['activity_id'])
                ?.toString();
        if (serviceId == null || serviceId.isEmpty) continue;
        final response = await _client
            .get(Uri.parse('$BASE_URL/venues/activities/$serviceId/management'),
                headers: headers)
            .timeout(const Duration(seconds: 15));
        final body = jsonDecode(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(body['message'] ?? 'Unable to load bookings.');
        }
        final data = body['data'] is Map ? body['data'] as Map : const {};
        final activityName = data['name']?.toString() ??
            service['title']?.toString() ??
            service['name']?.toString() ??
            'Activity';
        final bookings =
            data['bookings'] is List ? data['bookings'] as List : const [];
        collected.addAll(bookings.whereType<Map>().map((booking) =>
            _Booking.fromManagement(
                Map<String, dynamic>.from(booking), activityName)));
      }
      if (mounted) {
        setState(() {
          _venueId = venueId;
          _venueName = venueName;
          _bookings
            ..clear()
            ..addAll(collected);
        });
        _scheduleStatusUpdate();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patchBooking(_Booking booking, String action) async {
    if (_saving) return;
    _actionError = null;
    _bookingAction.value = action;
    try {
      final response = await _client
          .patch(Uri.parse('$BASE_URL/bookings/${booking.id}/$action'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) {
        throw Exception('Unable to update booking. Please retry.');
      }
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Unable to update booking.');
      }
      booking.status = switch (action) {
        'no-show' => _BookingStatus.noShow,
        'check-in' => _BookingStatus.ongoing,
        'complete' => _BookingStatus.completed,
        _ => booking.status,
      };
      if (mounted) {
        setState(() {});
        Navigator.of(context).pop();
      }
      // Refresh the shared booking list in the background so the next view
      // uses the server state without requiring a manual pull-to-refresh.
      await _load();
    } catch (e) {
      if (mounted) {
        _actionError = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (mounted) _bookingAction.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5E8),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: widget.managerLayout
                  ? const EdgeInsets.fromLTRB(20, 12, 20, 32)
                  : const EdgeInsets.fromLTRB(28, 28, 28, 32),
              children: [
                widget.managerLayout ? _buildManagerHeader() : _buildAppBar(),
                if (widget.managerLayout) ...[
                  const SizedBox(height: 18),
                  _buildManagerGreeting(),
                  const SizedBox(height: 44),
                ] else ...[
                  const SizedBox(height: 30),
                  _buildStats(),
                  const SizedBox(height: 24),
                ],
                _buildTabs(),
                const SizedBox(height: 18),
                _buildSearch(),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  _errorState()
                else if (_filtered.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                          child: Text('No bookings found.',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Satoshi',
                                  color: Colors.grey.shade600))))
                else
                  ..._filtered.map(_buildBookingCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() => Row(children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back,
                size: 22, color: Color(0xFF1F1F1F)),
          ),
        ),
        const SizedBox(width: 18),
        const Text('Manage bookings',
            style: TextStyle(
                fontSize: 22,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F1F1F))),
      ]);

  Widget _buildManagerHeader() {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MenuScreen(client: widget.client),
              ),
            ),
            borderRadius: BorderRadius.circular(20),
            child: ClipOval(
              child: SizedBox(
                width: 34,
                height: 34,
                child: _avatarUrl.isEmpty
                    ? const DefaultPartnerAvatar()
                    : Image.network(
                        _avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const DefaultPartnerAvatar(),
                      ),
              ),
            ),
          ),
          const Spacer(),
          Image.asset('assets/logo.png',
              width: 70, height: 36, fit: BoxFit.contain),
          const Spacer(),
          SvgPicture.asset(
            'assets/ic_notifications.svg',
            width: 22,
            height: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildManagerGreeting() {
    final venue = _venueName.isEmpty ? 'your venue' : _venueName;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Hi! 👋 Here\'s what\'s happening at ',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Satoshi',
              color: Color(0xFF1F1F1F),
            ),
          ),
          TextSpan(
            text: venue,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() => Column(children: [
        Row(children: [
          Expanded(
              child: _statCard('Total Bookings', '$_totalBookings',
                  Icons.calendar_today_outlined, const Color(0xFF3F3F3F))),
          const SizedBox(width: 18),
          Expanded(
              child: _statCard('Total Revenue', _money.format(_totalRevenue),
                  Icons.currency_rupee, const Color(0xFF9D38EB))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _statCard('Completed', '$_completed',
                  Icons.check_circle_outline, const Color(0xFF2EB944))),
          const SizedBox(width: 18),
          const Expanded(child: SizedBox()),
        ]),
      ]);

  Widget _statCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3F3F3F)))),
          Icon(icon, size: 22, color: iconColor),
        ]),
        const Spacer(),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F1F)))),
      ]),
    );
  }

  Widget _buildTabs() => Container(
      height: widget.managerLayout ? 38 : 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
          children: List.generate(_tabs.length, (index) {
        final selected = index == _selectedTab;
        return Expanded(
            child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() => _selectedTab = index),
                child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF9D38EB)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9)),
                    child: Text(_tabs[index],
                        style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF3F3F3F))))));
      })));

  Widget _buildSearch() => Container(
      height: widget.managerLayout ? 38 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        Icon(Icons.search,
            size: widget.managerLayout ? 17 : 22,
            color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 10),
        Expanded(
            child: TextField(
                controller: _searchCtrl,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
                style: TextStyle(
                    fontSize: widget.managerLayout ? 12 : 14,
                    fontFamily: 'Satoshi',
                    color: Color(0xFF1F1F1F)),
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search by name, booking id...',
                    hintStyle: TextStyle(
                        fontSize: widget.managerLayout ? 12 : 14,
                        fontFamily: 'Satoshi',
                        color: Color(0xFF9E9E9E)),
                    isDense: true))),
      ]));

  Widget _buildBookingCard(_Booking booking) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showBookingDetails(booking),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(widget.managerLayout ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(booking.customerName,
                      style: TextStyle(
                          fontSize: widget.managerLayout ? 13 : 15,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F1F1F)))),
              _statusBadge(booking.status),
            ]),
            const SizedBox(height: 8),
            Text('${booking.activity}  |  ${booking.date}  |  ${booking.time}',
                style: TextStyle(
                    fontSize: widget.managerLayout ? 11 : 13,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7F7F7F))),
            const SizedBox(height: 12),
            Text(
                '${_money.format(booking.totalAmount)}  |  ${booking.participants} ${booking.participants == 1 ? 'person' : 'persons'}${booking.paymentMode != 'Not available' && booking.paymentMode != '0' && booking.paymentMode.trim().isNotEmpty ? '  |  ${booking.paymentMode}' : ''}',
                style: TextStyle(
                    fontSize: widget.managerLayout ? 13 : 15,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F1F))),
          ]),
        ),
      ),
    );
  }

  Widget _errorState() => Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(children: [
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, fontFamily: 'Satoshi', color: Color(0xFFFE6B6B))),
        const SizedBox(height: 10),
        TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry')),
      ]));

  Widget _statusBadge(_BookingStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusBg[status],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_statusLabels[status]!,
          style: TextStyle(
              fontSize: 12,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              color: _statusColors[status])),
    );
  }

  void _showBookingDetails(_Booking booking) {
    _actionError = null;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => ListenableBuilder(
        listenable: _statusTick,
        builder: (ctx, _) => ValueListenableBuilder<String?>(
          valueListenable: _bookingAction,
          builder: (ctx, action, _) => PopScope(
              canPop: action == null,
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .86,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Booking details',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Satoshi',
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F1F1F)))),
                          IconButton(
                              onPressed: action == null
                                  ? () => Navigator.pop(ctx)
                                  : null,
                              icon: const Icon(Icons.close, size: 22)),
                        ]),
                        const SizedBox(height: 18),
                        _detailSection('Customer information', [
                          ('Full Name', booking.customerName),
                          ('Phone Number', booking.phone),
                        ]),
                        const Divider(height: 30, color: Color(0xFFE5E7EB)),
                        _detailSection('Booking information', [
                          ('Booking ID', booking.reference),
                          ('Activity', booking.activity),
                          ('Date', booking.date),
                          ('Time', booking.time),
                          ('Participants', '${booking.participants} people'),
                          ('Booked On', booking.bookedOn),
                        ]),
                        const Divider(height: 30, color: Color(0xFFE5E7EB)),
                        _detailSection('Payment information', [
                          ('Payment Mode', booking.paymentMode),
                          ('Total Amount', _money.format(booking.totalAmount)),
                        ]),
                        const Divider(height: 30, color: Color(0xFFE5E7EB)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: const Text('Manage Booking',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Satoshi',
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F1F1F))),
                        ),
                        const SizedBox(height: 14),
                        if (_actionError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(_actionError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFB3261E),
                                    fontFamily: 'Satoshi')),
                          ),
                        _buildManageActions(booking),
                      ]),
                    ),
                  ),
                ),
              )))),
    );
  }

  Widget _detailSection(String title, List<(String, String)> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F1F1F))),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i += 2)
          Padding(
              padding: EdgeInsets.only(bottom: i + 2 < items.length ? 18 : 0),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _detailItem(items[i].$1, items[i].$2)),
                const SizedBox(width: 28),
                Expanded(
                    child: i + 1 < items.length
                        ? _detailItem(items[i + 1].$1, items[i + 1].$2)
                        : const SizedBox.shrink()),
              ])),
      ]);

  Widget _detailItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w500,
              color: Color(0xFF7F7F7F))),
      const SizedBox(height: 3),
      Row(
        children: [
          Expanded(
            child: label == 'Booking ID'
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1F1F))),
                  )
                : Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1F1F))),
          ),
          if (label == 'Booking ID')
            IconButton(
              tooltip: 'Copy booking ID',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.copy_outlined, size: 15),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (mounted) {
                  CommonUtilities.createSnackBar(context, 'Booking ID copied');
                }
              },
            ),
        ],
      ),
    ]);
  }

  Widget _buildManageActions(_Booking booking) {
    if (booking.status == _BookingStatus.canceled ||
        booking.status == _BookingStatus.noShow ||
        booking.status == _BookingStatus.completed) {
      return _statusBadge(booking.status);
    }
    final isUpcoming = booking.status == _BookingStatus.upcoming ||
        booking.status == _BookingStatus.pending;
    return Row(children: [
      Expanded(
          child: OutlinedButton(
              onPressed:
                  _saving ? null : () => _patchBooking(booking, 'no-show'),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFE6B6B)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              child: _bookingAction.value == 'no-show'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFE6B6B),
                          semanticsLabel: 'Marking no-show'))
                  : const Text('Mark No-show',
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFE6B6B))))),
      const SizedBox(width: 12),
      Expanded(
          child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () => _patchBooking(
                      booking, isUpcoming ? 'check-in' : 'complete'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D38EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0),
              child: _saving && _bookingAction.value != 'no-show'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                          semanticsLabel: 'Updating booking'))
                  : Text(isUpcoming ? 'Check-in' : 'Mark Completed',
                      style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          color: Colors.white)))),
    ]);
  }

  static const _statusLabels = {
    _BookingStatus.upcoming: 'Upcoming',
    _BookingStatus.ongoing: 'Ongoing',
    _BookingStatus.canceled: 'Cancelled',
    _BookingStatus.noShow: 'No Show',
    _BookingStatus.completed: 'Completed',
    _BookingStatus.pending: 'Pending',
  };

  static const _statusColors = {
    _BookingStatus.upcoming: Color(0xFFFFA000),
    _BookingStatus.ongoing: Color(0xFF2EB944),
    _BookingStatus.canceled: Color(0xFF9E9E9E),
    _BookingStatus.noShow: Color(0xFFFE6B6B),
    _BookingStatus.completed: Color(0xFF9D38EB),
    _BookingStatus.pending: Color(0xFFFFA000),
  };

  static const _statusBg = {
    _BookingStatus.upcoming: Color(0xFFFFF3E0),
    _BookingStatus.ongoing: Color(0xFFE8F5E9),
    _BookingStatus.canceled: Color(0xFFF5F5F5),
    _BookingStatus.noShow: Color(0xFFFFEBEB),
    _BookingStatus.completed: Color(0xFFF3E8FF),
    _BookingStatus.pending: Color(0xFFFFF3E0),
  };
}
