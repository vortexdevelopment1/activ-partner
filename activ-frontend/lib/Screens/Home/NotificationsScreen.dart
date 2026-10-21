import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';

const _notificationBackground = Color(0xFFF0F7D2);
const _notificationPurple = Color(0xFFA536E5);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _tabs = const ['All', 'Bookings', 'Payments', 'Approvals', 'Admin'];
  List<Map<String, dynamic>> _items = [];
  int _selectedTab = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<http.Response> _request(String method, String url) async {
    final token = await SharedPreference.readStr('jwt_token') ?? '';
    final headers = {'Authorization': 'Bearer $token', 'accept': '*/*'};
    final client = widget.client;
    if (method == 'PATCH') {
      return (client?.patch ?? http.patch)(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
    }
    return (client?.get ?? http.get)(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 20));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _request('GET', NOTIFICATIONS_URL);
      if (response.statusCode != 200)
        throw Exception('Unable to load notifications');
      final raw = jsonDecode(response.body)['data'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Unable to load notifications. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _category(String type) {
    if (type.contains('booking')) return 'Bookings';
    if (type.contains('payment')) return 'Payments';
    if (type.contains('approved') ||
        type.contains('rejected') ||
        type.contains('review')) {
      return 'Approvals';
    }
    return 'Admin';
  }

  List<Map<String, dynamic>> get _filtered => _selectedTab == 0
      ? _items
      : _items
          .where((item) =>
              _category(item['type']?.toString() ?? '') == _tabs[_selectedTab])
          .toList();

  IconData _icon(String type) {
    if (type.contains('booking')) return Icons.calendar_month_outlined;
    if (type.contains('payment')) return Icons.currency_rupee;
    if (type.contains('approved') || type.contains('venue_approved')) {
      return Icons.verified_outlined;
    }
    if (type.contains('rejected')) return Icons.cancel_outlined;
    return Icons.campaign_outlined;
  }

  Color _iconColor(String type) {
    if (type.contains('booking')) return const Color(0xFF2DB84D);
    if (type.contains('payment')) return _notificationPurple;
    if (type.contains('rejected')) return const Color(0xFFFF5757);
    if (type.contains('approved')) return const Color(0xFFFF8A3D);
    return const Color(0xFF006B78);
  }

  Color _iconBackground(String type) {
    if (type.contains('booking')) return const Color(0xFFEFFFF1);
    if (type.contains('payment')) return const Color(0xFFF6ECFF);
    if (type.contains('rejected')) return const Color(0xFFFFEDEE);
    if (type.contains('approved')) return const Color(0xFFFFEBDD);
    return const Color(0xFFE9FAF1);
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    if (day == today) return DateFormat('h:mm a').format(date);
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM').format(date);
  }

  String _groupLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Earlier';
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE').format(date);
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    if (item['isRead'] != true) {
      try {
        await _request('PATCH', '$NOTIFICATIONS_URL/${item['id']}/read');
        if (mounted) {
          setState(() => item['isRead'] = true);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(item['title']?.toString() ?? 'Notification'),
              content: Text(item['body']?.toString() ?? ''),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
        backgroundColor: _notificationBackground,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          child: Row(children: [
                            Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 4,
                                child: IconButton(
                                    tooltip: 'Back',
                                    onPressed: () =>
                                        Navigator.maybePop(context),
                                    icon: const Icon(Icons.arrow_back,
                                        size: 26))),
                            const SizedBox(width: 16),
                            Text('Notifications',
                                style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700))
                          ])),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _tabs.length; i++)
                              Expanded(
                                  child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedTab = i),
                                      child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 14),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                    height: 20,
                                                    child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(_tabs[i],
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            style: const TextStyle(
                                                                fontFamily:
                                                                    'Satoshi',
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)))),
                                                const SizedBox(height: 10),
                                                SizedBox(
                                                    width: double.infinity,
                                                    height: 2,
                                                    child: ColoredBox(
                                                        color: i == _selectedTab
                                                            ? _notificationPurple
                                                            : Colors
                                                                .transparent))
                                              ]))))
                          ]),
                      Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _error != null
                                  ? Center(
                                      child: TextButton(
                                          onPressed: _load,
                                          child: Text(_error!)))
                                  : RefreshIndicator(
                                      onRefresh: _load,
                                      child: items.isEmpty
                                          ? ListView(children: const [
                                              SizedBox(height: 180),
                                              Center(
                                                  child: Text(
                                                      'No notifications yet'))
                                            ])
                                          : ListView.builder(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      20, 24, 20, 24),
                                              itemCount: items.length,
                                              itemBuilder: (_, index) {
                                                final item = items[index];
                                                final previous = index == 0
                                                    ? null
                                                    : items[index - 1];
                                                final showGroup = previous ==
                                                        null ||
                                                    _groupLabel(previous[
                                                            'createdAt']) !=
                                                        _groupLabel(
                                                            item['createdAt']);
                                                return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (showGroup)
                                                        Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    bottom: 12),
                                                            child: Text(
                                                                _groupLabel(item[
                                                                    'createdAt']),
                                                                style: const TextStyle(
                                                                    fontFamily:
                                                                        'Satoshi',
                                                                    fontSize:
                                                                        18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700))),
                                                      _notificationCard(item)
                                                    ]);
                                              })))
                    ])))));
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openNotification(item),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                              color: _iconBackground(type),
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(_icon(type),
                              color: _iconColor(type), size: 42)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item['title']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(item['body']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 14,
                                    color: Color(0xFF555555))),
                          ])),
                      const SizedBox(width: 8),
                      Column(children: [
                        Text(_time(item['createdAt']),
                            style: const TextStyle(
                                fontFamily: 'Satoshi', fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(children: [
                          if (item['isRead'] != true)
                            Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFD8F34A),
                                    shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right, size: 28)
                        ])
                      ])
                    ])))));
  }
}
