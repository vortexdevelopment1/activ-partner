import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../Beans/activity_model.dart';
import '../../../Style/activity_logos.dart';
import '../../../api_calling/api_constant.dart';
import '../../../api_calling/api_request.dart';
import '../ManageSlotsScreen.dart';
import 'DirectBookSlotScreen.dart';

const _background = Color(0xFFF0F6D2);
const _purple = Color(0xFFA536F5);
const _border = Color(0xFFDCE2E5);

class ActivityManagementScreen extends StatefulWidget {
  const ActivityManagementScreen(
      {super.key,
      required this.activity,
      this.initialStatus = 'Active',
      this.venueId = '',
      this.client});

  final ActivityModel activity;
  final String initialStatus;
  final String venueId;
  final http.Client? client;

  @override
  State<ActivityManagementScreen> createState() => _ActivityManagementState();
}

class _ActivityManagementState extends State<ActivityManagementScreen> {
  late final http.Client _client;
  Map<String, dynamic> _data = {};
  bool _loading = true, _saving = false, _changed = false;
  String? _error;
  String _reason = 'Maintenance / Repair';
  final _otherReason = TextEditingController();
  final _currency = NumberFormat.currency(
      locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
  static const _reasons = [
    ('Maintenance / Repair', 'Maintenance / Repair', Icons.construction),
    (
      'Staff Unavailable',
      'Staff not available to manage bookings',
      Icons.person_outline
    ),
    (
      'Private event/tournament',
      'Venue booked for private event/tournament',
      Icons.emoji_events_outlined
    ),
    ('Weather issue', 'Bad weather conditions', Icons.thunderstorm_outlined),
    (
      'Renovation work',
      'Venue under renovation or improvement',
      Icons.work_outline
    ),
    (
      'Safety concern',
      'Safety or security related issue',
      Icons.verified_user_outlined
    ),
    ('Other', 'Other reason (please specify)', Icons.more_horiz),
  ];

  String get _name => _data['name']?.toString() ?? widget.activity.title;
  String get _description =>
      _data['description']?.toString() ?? widget.activity.description;
  String get _status {
    if (_data.isEmpty) return widget.initialStatus;
    return switch (_data['status']) {
      'approved' => _data['isActive'] == false ? 'Inactive' : 'Active',
      'draft' => 'Draft',
      'pending' || 'submitted' => 'In Review',
      _ => 'Inactive',
    };
  }

  bool get _active => _status == 'Active';
  bool get _canControl =>
      !_loading &&
      _error == null &&
      ['Active', 'Inactive'].contains(_status) &&
      _data['status'] == 'approved';
  List<Map<String, dynamic>> _items(String key) => (_data[key] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  List<String> get _images => _data.containsKey('imageUrls')
      ? (_data['imageUrls'] as List? ?? []).map((e) => e.toString()).toList()
      : widget.activity.images
          .whereType<Map>()
          .map((e) => e['url'].toString())
          .toList();
  String _imageUrl(String url) => Uri.parse(BASE_URL).resolve(url).toString();
  String get _endpoint =>
      '$BASE_URL/venues/activities/${widget.activity.activityId}/management';

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    _load();
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    _otherReason.dispose();
    super.dispose();
  }

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

  dynamic _response(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['message'];
      throw Exception(message is List
          ? message.join(', ')
          : message ?? 'Unable to save. Please try again.');
    }
    return body['data'];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _client
          .get(Uri.parse(_endpoint), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      final data = Map<String, dynamic>.from(_response(response) as Map);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _save(Map<String, dynamic> payload,
      {bool delete = false}) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final headers = await _headers();
      final response = await (delete
              ? _client.delete(Uri.parse(_endpoint), headers: headers)
              : _client.patch(Uri.parse(_endpoint),
                  headers: headers, body: jsonEncode(payload)))
          .timeout(const Duration(seconds: 15));
      _response(response);
      _changed = true;
      if (!delete && mounted) await _load();
      return true;
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pause() async {
    final reason = _reason == 'Other' ? _otherReason.text.trim() : _reason;
    if (reason.isEmpty) {
      _message('Please enter a reason.');
      return;
    }
    if (await _save({'isActive': false, 'reason': reason}) && mounted) {
      _message('Bookings paused. Existing bookings are preserved.');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (context) => SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                          color: const Color(0xFFDADADA),
                          borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 36),
                  Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFFEFEF), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 42)),
                  const SizedBox(height: 28),
                  const Text('Delete Activity?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 22,
                          color: Colors.redAccent)),
                  const SizedBox(height: 22),
                  const Text(
                      'This will permanently delete this activity and all associated data including bookings history, slot configurations and images. This action cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF777777))),
                  const SizedBox(height: 34),
                  Row(children: [
                    Expanded(
                        child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: ElevatedButton.styleFrom(
                                elevation: 0,
                                minimumSize: const Size(0, 56),
                                backgroundColor: const Color(0xFFFFF8C8),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    fontFamily: 'Satoshi', fontSize: 16)))),
                    const SizedBox(width: 18),
                    Expanded(
                        flex: 2,
                        child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                                elevation: 0,
                                minimumSize: const Size(0, 56),
                                backgroundColor: const Color(0xFF1F1F1F),
                                foregroundColor: const Color(0xFFD8F34A),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('Delete Activity',
                                style: TextStyle(
                                    fontFamily: 'Satoshi', fontSize: 16)))),
                  ]),
                ]),
              ),
            ));
    if (confirmed == true && await _save({}, delete: true) && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _slots() async {
    final scoped = _ActivityClient(
        _client,
        _data['venueId']?.toString() ?? widget.venueId,
        _data['categoryId']?.toString() ??
            widget.activity.operateValue['id']?.toString() ??
            '');
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ManageSlotsScreen(client: scoped)));
    if (mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _information() async {
    final values = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => _ActivityInfoPage(
                activity: widget.activity, data: _data, name: _name)));
    if (values != null && mounted) await _save(values);
  }

  Future<void> _upload() async {
    try {
      final currentCount = _images.length;
      if (currentCount >= 12) {
        _message(
            'You can upload a maximum of 12 images. Remove an image before adding more.');
        return;
      }
      final photos = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (photos.isEmpty || !mounted) return;
      if (photos.length > 10) {
        _message('Select up to 10 images at a time.');
        return;
      }
      if (currentCount + photos.length > 12) {
        _message(
            'You can upload ${12 - currentCount} more image${12 - currentCount == 1 ? '' : 's'}.');
        return;
      }
      setState(() => _saving = true);
      final request = http.MultipartRequest(
          'POST',
          Uri.parse(
              '$BASE_URL/venues/activities/${widget.activity.activityId}/images'));
      request.headers.addAll(await _headers());
      request.headers.remove('Content-Type');
      for (final photo in photos) {
        final bytes = await photo.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          throw Exception('Each image must be under 10 MB.');
        }
        request.files.add(http.MultipartFile.fromBytes('images', bytes,
            filename: photo.name));
      }
      _response(await http.Response.fromStream(
          await _client.send(request).timeout(const Duration(seconds: 30))));
      _changed = true;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeImage(String url) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(title: const Text('Remove image?'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove')),
            ]));
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      _response(await _client
          .delete(
              Uri.parse(
                  '$BASE_URL/venues/activities/${widget.activity.activityId}/images'),
              headers: await _headers(),
              body: jsonEncode({'imageUrl': url}))
          .timeout(const Duration(seconds: 15)));
      _changed = true;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _imageManager() => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => _ImagesPage(
              activityName: _name,
              load: () => _images,
              upload: _upload,
              remove: _removeImage,
              imageUrl: _imageUrl)));

  Future<void> _bookSlots() async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => DirectBookSlotScreen(
                  activity: widget.activity,
                  activityData: _data,
                  venueId: _data['venueId']?.toString() ?? widget.venueId,
                  venueName: _data['venueName']?.toString() ??
                      _data['venue']?['name']?.toString() ??
                      _data['venueDetails']?['name']?.toString() ??
                      'Venue',
                  client: _client,
                )));
    if (mounted) await _load();
  }

  void _allBookings() => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => _BookingsPage(
              bookings: _items('bookings'),
              activityName: _name,
              currency: _currency)));

  void _reviews() => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) =>
              _ReviewsPage(activityName: _name, reviews: _items('reviews'))));

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
            backgroundColor: _background,
            body: SafeArea(
                child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 32, 18, 40),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: IconButton(
                                      tooltip: 'Back',
                                      onPressed: _saving
                                          ? null
                                          : () =>
                                              Navigator.pop(context, _changed),
                                      icon: const Icon(Icons.arrow_back,
                                          size: 21))),
                              const SizedBox(width: 20),
                              Expanded(
                                  child: _text('Activity Management',
                                      bold: true, size: 23)),
                            ]),
                            const SizedBox(height: 24),
                            _identity(),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                  child: _stat(
                                      'Total Booking',
                                      _data['bookingCount']?.toString() ?? '0',
                                      Icons.calendar_month_outlined)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _stat(
                                      'Total Earning',
                                      _data['earnings'] == null
                                          ? _currency.format(0)
                                          : _currency.format(num.tryParse(
                                                  _data['earnings']
                                                      .toString()) ??
                                              0),
                                      Icons.home_outlined)),
                            ]),
                            if (_loading)
                              const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: LinearProgressIndicator()),
                            if (_error != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Column(children: [
                                    _text(_error!, color: Colors.red),
                                    TextButton.icon(
                                        onPressed: _load,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'))
                                  ])),
                            const SizedBox(height: 16),
                            _panel(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  _text('Quick Actions', bold: true),
                                  const SizedBox(height: 14),
                                  _action(
                                      'Manage Slot & Pricing',
                                      'Update Slots, Availability & Pricing',
                                      Icons.calendar_today_outlined,
                                      _slots),
                                  _action(
                                      'Book Slots',
                                      'Reserve slots for direct walk-ins',
                                      Icons.lock_outline,
                                      _bookSlots),
                                  _action(
                                      'Manage Images',
                                      'Upload & update activity images',
                                      Icons.image_outlined,
                                      _imageManager),
                                  _action(
                                      'Activity Information',
                                      'Update activity details & Amenities',
                                      Icons.info_outline,
                                      _information),
                                  _action(
                                      'Review & Ratings',
                                      'View customer reviews & Ratings',
                                      Icons.reviews_outlined,
                                      _reviews),
                                ])),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: _text('Recent Bookings',
                                      bold: true, size: 17)),
                              TextButton(
                                  onPressed: _loading || _error != null
                                      ? null
                                      : _allBookings,
                                  child: const Text('View all \u2192',
                                      style: TextStyle(
                                          color: _purple,
                                          fontFamily: 'Satoshi')))
                            ]),
                            if (!_loading &&
                                _error == null &&
                                _items('bookings').isEmpty)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: _text('No bookings yet',
                                      color: Colors.grey)),
                            ..._items('bookings').take(5).map(_booking),
                            const SizedBox(height: 6),
                            _statusPanel(),
                            const SizedBox(height: 16),
                            _deletePanel(),
                          ]),
                    )),
              ),
            ))),
      );

  Widget _activityLogo() => Image.asset(
      activityLogoAsset(_name,
          category: widget.activity.operateValue['categoryName']?.toString()),
      fit: BoxFit.contain);

  Widget _identity() {
    final cover = _data['coverImageUrl']?.toString();
    final photo = cover ?? _images.firstOrNull;
    return _panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
              width: 88,
              height: 88,
              child: photo == null
                  ? _activityLogo()
                  : Image.network(_imageUrl(photo),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _activityLogo()))),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _text(_name, bold: true, size: 17)),
          _badge(
              _active
                  ? 'ACTIV'
                  : _status == 'Inactive'
                      ? 'InACTIV'
                      : _status,
              _active ? Colors.green : _purple)
        ]),
        const SizedBox(height: 5),
        _text(_description, color: Colors.grey, size: 13),
        const SizedBox(height: 14),
        Text.rich(
            TextSpan(text: 'ACTIV ID: ', children: [
              TextSpan(
                  text: widget.activity.activityId,
                  style: const TextStyle(color: Colors.grey))
            ]),
            style: const TextStyle(fontFamily: 'Satoshi', fontSize: 12)),
      ])),
    ]));
  }

  Widget _stat(String title, String value, IconData icon) => Container(
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _text(title, size: 9)),
          Icon(icon, size: 13, color: Colors.greenAccent.shade400)
        ]),
        const SizedBox(height: 10),
        Expanded(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _text(value, size: 18, bold: true))),
      ]));

  Widget _action(
          String title, String subtitle, IconData icon, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: _border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: _saving || _loading || _error != null ? null : onTap,
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: const Color(0xFFEED5FF),
                                borderRadius: BorderRadius.circular(9)),
                            child: Icon(icon, color: _purple, size: 23)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _text(title, bold: true, size: 13),
                              const SizedBox(height: 3),
                              _text(subtitle,
                                  size: 12, color: const Color(0xFF686868)),
                            ])),
                        const Icon(Icons.chevron_right, size: 20),
                      ])))));

  Widget _booking(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'Upcoming';
    final color = switch (status) {
      'Ongoing' => Colors.green,
      'Canceled' => const Color(0xFF7D9291),
      'No Show' => Colors.redAccent,
      'Completed' => _purple,
      _ => Colors.orange
    };
    final date =
        DateTime.tryParse(booking['startsAt']?.toString() ?? '')?.toLocal();
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _bookingDetails(booking),
                child: _panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: _text(
                                booking['customerName']?.toString() ??
                                    'Customer',
                                bold: true)),
                        _badge(status, color)
                      ]),
                      const SizedBox(height: 8),
                      _text(
                          '${booking['activity'] ?? _name}  |  ${date == null ? '0' : DateFormat('dd MMM yyyy  |  hh:mm a').format(date)}',
                          color: Colors.grey,
                          size: 12),
                      const SizedBox(height: 12),
                      _text(
                          '${_currency.format(num.tryParse(booking['amount']?.toString() ?? '') ?? 0)}${booking['participants'] == null ? '' : '  |  ${booking['participants']} persons'}',
                          bold: true,
                          size: 16),
                    ])))));
  }

  void _bookingDetails(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'Upcoming';
    final date =
        DateTime.tryParse(booking['startsAt']?.toString() ?? '')?.toLocal();
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 12, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              title: Row(children: [
                const Expanded(
                    child: Text('Booking details',
                        style: TextStyle(fontFamily: 'Satoshi', fontSize: 20))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              content: SizedBox(
                  width: double.maxFinite,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _detailSection('Customer information', [
                      (
                        'Full Name',
                        booking['customerName']?.toString() ?? 'Customer'
                      ),
                      ('Status', status),
                    ]),
                    const Divider(height: 30),
                    _detailSection('Booking information', [
                      ('Activity', booking['activity']?.toString() ?? _name),
                      (
                        'Date',
                        date == null
                            ? '0'
                            : DateFormat('dd MMM yyyy').format(date)
                      ),
                      (
                        'Time',
                        date == null ? '0' : DateFormat('hh:mm a').format(date)
                      ),
                      ('Persons', booking['participants']?.toString() ?? '0'),
                      (
                        'Amount',
                        _currency.format(
                            num.tryParse(booking['amount']?.toString() ?? '') ??
                                0)
                      ),
                    ]),
                  ])),
            ));
  }

  Widget _detailSection(String title, List<(String, String)> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(title, bold: true, size: 16),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i += 2)
            Padding(
                padding: EdgeInsets.only(bottom: i + 2 < items.length ? 18 : 0),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _detailItem(items[i].$1, items[i].$2)),
                      const SizedBox(width: 28),
                      Expanded(
                          child: i + 1 < items.length
                              ? _detailItem(items[i + 1].$1, items[i + 1].$2)
                              : const SizedBox.shrink()),
                    ])),
        ],
      );

  Widget _detailItem(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _text(label, color: Colors.grey, size: 13),
        const SizedBox(height: 5),
        _text(value, bold: true, size: 15),
      ]);

  Widget _statusPanel() => _panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _text('Activity Status', bold: true)),
          _badge(_active ? 'ACTIV' : _status, _active ? Colors.green : _purple)
        ]),
        const SizedBox(height: 10),
        _text(
            _active
                ? 'This activity is ACTIV and accepting bookings.'
                : _status == 'Inactive'
                    ? 'This activity is InACTIV and not accepting new bookings.'
                    : 'This activity is $_status and is not accepting bookings.',
            size: 12),
        const SizedBox(height: 16),
        if (_active) ...[
          _text('Go InACTIV and temporarily stop accepting bookings.',
              size: 12),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _canControl && !_saving ? _showPauseReasonSheet : null,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
              child: SizedBox(
                  height: 40,
                  child: Row(children: [
                    const Expanded(
                        child: Text('Activity Control',
                            style: TextStyle(fontFamily: 'Satoshi'))),
                    const Icon(Icons.keyboard_arrow_down)
                  ]))),
        ] else if (_canControl)
          _button(_saving ? 'Resuming...' : 'Resume Booking',
              _saving ? null : () => _save({'isActive': true})),
        const SizedBox(height: 26),
        _text('What happens next?', bold: true),
        const SizedBox(height: 20),
        _effect(Icons.calendar_today_outlined,
            'Upcoming bookings will be blocked during inactive period'),
        _effect(Icons.visibility_off_outlined,
            'Venue will be hidden from search & discovery'),
        _effect(
            Icons.notifications_none, 'ACTIV team may reach out if required'),
      ]));

  Future<void> _showPauseReasonSheet() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) => SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(28, 12, 28,
                        22 + MediaQuery.viewInsetsOf(sheetContext).bottom),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 54,
                          height: 5,
                          decoration: BoxDecoration(
                              color: const Color(0xFFDADADA),
                              borderRadius: BorderRadius.circular(99))),
                      const SizedBox(height: 24),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: _text('Select Pause Reason',
                              bold: true, size: 18)),
                      const SizedBox(height: 16),
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(children: [
                            ..._reasons.map((reason) => Semantics(
                                selected: _reason == reason.$1,
                                button: true,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _saving
                                      ? null
                                      : () {
                                          setSheetState(
                                              () => _reason = reason.$1);
                                          setState(() {});
                                        },
                                  child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                          color: _reason == reason.$1
                                              ? const Color(0xFFF3E6FF)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(children: [
                                        Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                                color: _purple,
                                                borderRadius:
                                                    BorderRadius.circular(9)),
                                            child: Icon(reason.$3,
                                                color: Colors.white, size: 27)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              _text(reason.$1,
                                                  bold: true, size: 14),
                                              const SizedBox(height: 2),
                                              _text(reason.$2,
                                                  size: 10,
                                                  color: Colors.grey.shade700),
                                            ])),
                                      ])),
                                ))),
                            if (_reason == 'Other') ...[
                              const SizedBox(height: 8),
                              TextField(
                                  controller: _otherReason,
                                  maxLength: 500,
                                  decoration: InputDecoration(
                                      hintText: 'Enter reason',
                                      counterText: '',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: _border)))),
                            ],
                          ])),
                      const SizedBox(height: 22),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFF8DC),
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size(0, 56),
                                    side: const BorderSide(color: Colors.black),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                child: const Text('Cancel',
                                    style: TextStyle(fontFamily: 'Satoshi')))),
                        const SizedBox(width: 20),
                        Expanded(
                            flex: 2,
                            child: _button(
                                _saving ? 'Pausing...' : 'Pause Booking',
                                _saving
                                    ? null
                                    : () {
                                        Navigator.pop(sheetContext);
                                        _pause();
                                      }))
                      ]),
                    ]),
                  ),
                )));
  }

  Widget _effect(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: const Color(0xFFF1F8E8),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: _text(text, size: 12))
      ]));

  Widget _deletePanel() => Material(
      color: const Color(0xFFFFF6F6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.redAccent)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: _saving || _loading || _error != null ? null : _delete,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 28),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _text('Delete Activity',
                          color: Colors.redAccent, size: 18, bold: true),
                      const SizedBox(height: 12),
                      _text('This will stop new bookings immediately.',
                          size: 13, color: Colors.grey.shade700),
                      const SizedBox(height: 6),
                      _text('Existing bookings will be honored.',
                          size: 13, color: Colors.grey.shade700),
                    ])),
                const Icon(Icons.chevron_right, color: Colors.redAccent),
              ]))));
}

Widget _text(String text,
        {double size = 14,
        bool bold = false,
        Color color = const Color(0xFF303030)}) =>
    Text(text,
        style: TextStyle(
            fontFamily: bold ? 'Satoshi' : 'Satoshi',
            fontSize: size,
            color: color));
Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border)),
    child: child);
Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20)),
    child: _text(text, size: 11, color: color, bold: true));
Widget _button(String label, VoidCallback? onPressed) => SizedBox(
    height: 48,
    width: double.infinity,
    child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: const Color(0xFFD8F34A),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(label,
            style: const TextStyle(fontFamily: 'Satoshi', fontSize: 15))));

class _ActivityInfoPage extends StatefulWidget {
  const _ActivityInfoPage(
      {required this.activity, required this.data, required this.name});

  final ActivityModel activity;
  final Map<String, dynamic> data;
  final String name;

  @override
  State<_ActivityInfoPage> createState() => _ActivityInfoPageState();
}

class _ActivityInfoPageState extends State<_ActivityInfoPage> {
  late final TextEditingController _description;
  late final TextEditingController _totalCourts;
  late final TextEditingController _courtType;
  late Set<String> _playingEnvironment;
  late Set<String> _equipmentAvailable;
  late Set<String> _coachingAvailable;
  late Set<String> _recommendedFor;

  static const _playingOptions = [
    'Indoor',
    'Outdoor',
    'Air Conditioned',
    'Covered',
    'Floodlights',
    'Spectator Seating',
  ];
  static const _equipmentOptions = [
    'Equipment Provided',
    'Rental Equipment',
    'Protective Gear',
    'Training Gear',
  ];
  static const _coachingOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Kids',
    'Personal',
  ];
  static const _recommendedOptions = [
    'Beginners',
    'Casual',
    'Competitive',
    'Kids',
    'Corporate',
  ];

  bool get _isTurfActivity {
    final text = [
      widget.name,
      widget.activity.title,
      widget.activity.operateValue['title'],
      widget.activity.operateValue['type'],
      widget.activity.operateValue['name'],
      widget.data['categoryTitle'],
      widget.data['categoryName'],
      widget.data['name'],
    ]
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase())
        .join(' ');
    return text.contains('cricket') || text.contains('turf');
  }

  String get _totalUnitsLabel =>
      _isTurfActivity ? 'Total Turfs' : 'Total Courts';
  String get _typeLabel => _isTurfActivity ? 'Pitch Type' : 'Court Type';

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
        text:
            _readString('description', fallback: widget.activity.description));
    _totalCourts = TextEditingController(
        text: _readString('numberOfCourt',
            fallback: widget.activity.numberOfCourt));
    _courtType = TextEditingController(
        text: _readString('courtType', fallback: widget.activity.flooringType));
    _playingEnvironment = _readList('playingEnvironment',
        fallback: widget.activity.physicalSetup);
    _equipmentAvailable = _readList('equipmentAvailable',
        fallback: widget.activity.equipmentProvided);
    _coachingAvailable = _readList('coachingAvailable');
    _recommendedFor =
        _readList('recommendedFor', fallback: widget.activity.activitySuited);
  }

  @override
  void dispose() {
    _description.dispose();
    _totalCourts.dispose();
    _courtType.dispose();
    super.dispose();
  }

  String _readString(String key, {String fallback = ''}) {
    final value = widget.data[key]?.toString();
    if (value != null && value.trim().isNotEmpty) return value;
    return fallback;
  }

  Set<String> _readList(String key, {String fallback = ''}) {
    final value = widget.data[key];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    if (fallback.trim().isEmpty) return {};
    return fallback
        .split(RegExp(r'[,|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  void _save() {
    Navigator.pop(context, {
      'description': _description.text.trim(),
      'numberOfCourt': _totalCourts.text.trim(),
      'courtType': _courtType.text.trim(),
      'playingEnvironment': _playingEnvironment.toList(),
      'equipmentAvailable': _equipmentAvailable.toList(),
      'coachingAvailable': _coachingAvailable.toList(),
      'recommendedFor': _recommendedFor.toList(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(children: [
                      Expanded(
                          child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 28, 28, 28),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Material(
                                          color: Colors.white,
                                          shape: const CircleBorder(),
                                          elevation: 2,
                                          child: IconButton(
                                              tooltip: 'Back',
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              icon: const Icon(Icons.arrow_back,
                                                  size: 22))),
                                      const SizedBox(width: 18),
                                      Expanded(
                                          child: _text(
                                              'Update Activity Details',
                                              bold: true,
                                              size: 24)),
                                    ]),
                                    const SizedBox(height: 44),
                                    _text(widget.name, bold: true, size: 26),
                                    const SizedBox(height: 6),
                                    _text('Provide Activity Specific Details',
                                        size: 16),
                                    const SizedBox(height: 28),
                                    _fieldLabel('Activity Description',
                                        required: true),
                                    _input(
                                        controller: _description,
                                        maxLines: 5,
                                        maxLength: 5000),
                                    const SizedBox(height: 22),
                                    _fieldLabel(_totalUnitsLabel),
                                    _input(
                                        controller: _totalCourts,
                                        keyboardType: TextInputType.number),
                                    const SizedBox(height: 22),
                                    _fieldLabel(_typeLabel),
                                    _input(controller: _courtType),
                                    const SizedBox(height: 22),
                                    _fieldLabel('Playing Environment'),
                                    _checkPanel(
                                        options: _playingOptions,
                                        values: _playingEnvironment,
                                        onChanged: (next) => setState(
                                            () => _playingEnvironment = next)),
                                    const SizedBox(height: 22),
                                    _fieldLabel('Equipment Available'),
                                    _checkPanel(
                                        options: _equipmentOptions,
                                        values: _equipmentAvailable,
                                        onChanged: (next) => setState(
                                            () => _equipmentAvailable = next)),
                                    const SizedBox(height: 22),
                                    _fieldLabel('Coaching Available'),
                                    _checkPanel(
                                        options: _coachingOptions,
                                        values: _coachingAvailable,
                                        onChanged: (next) => setState(
                                            () => _coachingAvailable = next)),
                                    const SizedBox(height: 22),
                                    _fieldLabel('Recommended For'),
                                    _checkPanel(
                                        options: _recommendedOptions,
                                        values: _recommendedFor,
                                        onChanged: (next) => setState(
                                            () => _recommendedFor = next)),
                                  ]))),
                      Container(
                          color: _background,
                          padding: EdgeInsets.fromLTRB(28, 16, 28,
                              16 + MediaQuery.paddingOf(context).bottom),
                          child: _button('Save Changes', _save)),
                    ])))),
      );

  Widget _fieldLabel(String label, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
          text: TextSpan(
              text: label,
              style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 15,
                  color: Color(0xFF202020)),
              children: [
            if (required)
              const TextSpan(
                  text: ' *', style: TextStyle(color: Colors.redAccent)),
          ])));

  Widget _input(
          {required TextEditingController controller,
          int maxLines = 1,
          int? maxLength,
          TextInputType? keyboardType}) =>
      TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: 'Satoshi', fontSize: 15),
          decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _purple))));

  Widget _checkPanel(
          {required List<String> options,
          required Set<String> values,
          required ValueChanged<Set<String>> onChanged}) =>
      Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8)),
          child: Column(
              children: options
                  .map((option) => InkWell(
                      onTap: () {
                        final next = {...values};
                        next.contains(option)
                            ? next.remove(option)
                            : next.add(option);
                        onChanged(next);
                      },
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(children: [
                            _checkBox(values.contains(option)),
                            const SizedBox(width: 12),
                            Expanded(child: _text(option, size: 15)),
                          ]))))
                  .toList()));

  Widget _checkBox(bool checked) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
          color: checked ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: checked ? _purple : _border, width: 2)),
      child: checked
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null);
}

// Keep the existing slot and pricing editors while selecting this activity's data.
class _ActivityClient extends http.BaseClient {
  _ActivityClient(this.client, this.venueId, this.categoryId);
  final http.Client client;
  final String venueId, categoryId;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await client.send(request);
    if (request.method != 'GET' ||
        request.url.toString() != MY_APPROVED_VENUES_URL ||
        response.statusCode != 200) {
      return response;
    }
    final body = jsonDecode(await response.stream.bytesToString())
        as Map<String, dynamic>;
    body['data'] = [
      for (final venue in (body['data'] as List).whereType<Map>())
        if (venue['id']?.toString() == venueId)
          {
            ...venue,
            'services': [
              for (final service
                  in (venue['services'] as List? ?? []).whereType<Map>())
                if (service['categoryId']?.toString() == categoryId) service
            ],
            'availability': {
              if ((venue['availability'] as Map?)?.containsKey(categoryId) ==
                  true)
                categoryId: venue['availability'][categoryId]
            },
          }
    ];
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))), 200,
        headers: response.headers);
  }
}

class _BookingsPage extends StatefulWidget {
  const _BookingsPage({
    required this.bookings,
    required this.activityName,
    required this.currency,
  });

  final List<Map<String, dynamic>> bookings;
  final String activityName;
  final NumberFormat currency;

  @override
  State<_BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<_BookingsPage> {
  final _search = TextEditingController();
  String _tab = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    final query = _search.text.trim().toLowerCase();
    return widget.bookings.where((booking) {
      final startsAt =
          DateTime.tryParse(booking['startsAt']?.toString() ?? '')?.toLocal();
      final status = booking['status']?.toString() ?? 'Upcoming';
      final isPast = startsAt != null && startsAt.isBefore(now) ||
          ['Completed', 'Canceled', 'No Show'].contains(status);
      final tabMatch = switch (_tab) {
        'Upcoming' => !isPast,
        'Past' => isPast,
        _ => true,
      };
      if (!tabMatch) return false;
      if (query.isEmpty) return true;
      final haystack = [
        booking['bookingReference'],
        booking['booking_reference'],
        booking['id'],
        booking['customerName'],
        booking['activity'],
        status,
      ].map((item) => item?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();
  }

  int get _completedCount => widget.bookings
      .where((booking) => booking['status']?.toString() == 'Completed')
      .length;

  num get _revenue => widget.bookings.fold<num>(
      0,
      (sum, booking) =>
          sum + (num.tryParse(booking['amount']?.toString() ?? '') ?? 0));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                children: [
                  Row(children: [
                    Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 22))),
                    const SizedBox(width: 18),
                    Expanded(
                        child: _text('Manage bookings', bold: true, size: 22)),
                  ]),
                  const SizedBox(height: 30),
                  Row(children: [
                    Expanded(
                        child: _summaryCard(
                            'Total Bookings',
                            widget.bookings.length.toString(),
                            Icons.calendar_today_outlined)),
                    const SizedBox(width: 18),
                    Expanded(
                        child: _summaryCard(
                            'Total Revenue',
                            widget.currency.format(_revenue),
                            Icons.currency_rupee,
                            iconColor: _purple)),
                  ]),
                  const SizedBox(height: 18),
                  FractionallySizedBox(
                      widthFactor: .5,
                      alignment: Alignment.centerLeft,
                      child: _summaryCard(
                          'Completed',
                          _completedCount.toString(),
                          Icons.check_circle_outline,
                          iconColor: Colors.green)),
                  const SizedBox(height: 24),
                  _tabs(),
                  const SizedBox(height: 18),
                  _searchField(),
                  const SizedBox(height: 56),
                  if (_filtered.isEmpty)
                    Center(
                        child: _text('No bookings found.',
                            color: Colors.grey.shade600, size: 14))
                  else
                    ..._filtered
                        .map((booking) => _bookingCard(context, booking)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _summaryCard(String title, String value, IconData icon,
          {Color iconColor = const Color(0xFF202124)}) =>
      Container(
          height: 124,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _text(title, size: 14)),
              Icon(icon, color: iconColor, size: 22),
            ]),
            const Spacer(),
            _text(value, bold: true, size: 24),
          ]));

  Widget _tabs() => Container(
      height: 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
          children: ['All', 'Upcoming', 'Past']
              .map((tab) => Expanded(
                      child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _tab = tab),
                    child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _tab == tab ? _purple : Colors.transparent,
                            borderRadius: BorderRadius.circular(8)),
                        child: _text(tab,
                            bold: _tab == tab,
                            color: _tab == tab ? Colors.white : Colors.black,
                            size: 15)),
                  )))
              .toList()));

  Widget _searchField() => TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontFamily: 'Satoshi', fontSize: 14),
      decoration: InputDecoration(
          hintText: 'Search by name, booking id...',
          hintStyle: const TextStyle(fontFamily: 'Satoshi', color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _purple))));

  Widget _bookingCard(BuildContext context, Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? 'Upcoming';
    final date =
        DateTime.tryParse(booking['startsAt']?.toString() ?? '')?.toLocal();
    final color = switch (status) {
      'Canceled' => const Color(0xFF7D9291),
      'No Show' => Colors.redAccent,
      'Completed' => _purple,
      _ => Colors.orange,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context, booking),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: _text(
                        booking['customerName']?.toString() ?? 'Customer',
                        bold: true,
                        size: 16)),
                _badge(status, color),
              ]),
              const SizedBox(height: 10),
              _text(
                  '${widget.activityName}  |  ${date == null ? '0' : DateFormat('dd MMM yyyy  |  hh:mm a').format(date)}',
                  color: Colors.grey,
                  size: 13),
              const SizedBox(height: 14),
              _text(
                  '${widget.currency.format(num.tryParse(booking['amount']?.toString() ?? '') ?? 0)}  |  ${booking['participants']?.toString() ?? '0'} persons',
                  bold: true,
                  size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> booking) {
    final date =
        DateTime.tryParse(booking['startsAt']?.toString() ?? '')?.toLocal();
    showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                const Expanded(
                    child: Text('Booking details',
                        style: TextStyle(fontFamily: 'Satoshi', fontSize: 20))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              content: SizedBox(
                  width: double.maxFinite,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _bookingDetailSection('Customer information', [
                      (
                        'Full Name',
                        booking['customerName']?.toString() ?? 'Customer'
                      ),
                      ('Status', booking['status']?.toString() ?? 'Upcoming'),
                    ]),
                    const Divider(height: 30),
                    _bookingDetailSection('Booking information', [
                      (
                        'Booking ID',
                        (booking['bookingReference'] ??
                                booking['booking_reference'] ??
                                booking['id'] ??
                                '')
                            .toString()
                      ),
                      ('Activity', widget.activityName),
                      (
                        'Date',
                        date == null
                            ? '0'
                            : DateFormat('dd MMM yyyy').format(date)
                      ),
                      (
                        'Time',
                        date == null ? '0' : DateFormat('hh:mm a').format(date)
                      ),
                      ('Persons', booking['participants']?.toString() ?? '0'),
                      (
                        'Amount',
                        widget.currency.format(
                            num.tryParse(booking['amount']?.toString() ?? '') ??
                                0)
                      ),
                    ]),
                  ])),
            ));
  }

  Widget _bookingDetailSection(String title, List<(String, String)> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _text(title, bold: true, size: 16),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i += 2)
          Padding(
              padding: EdgeInsets.only(bottom: i + 2 < items.length ? 18 : 0),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _bookingDetailItem(items[i].$1, items[i].$2)),
                const SizedBox(width: 28),
                Expanded(
                    child: i + 1 < items.length
                        ? _bookingDetailItem(items[i + 1].$1, items[i + 1].$2)
                        : const SizedBox.shrink()),
              ])),
      ]);

  Widget _bookingDetailItem(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _text(label, size: 13, color: Colors.grey),
        const SizedBox(height: 5),
        _text(value, bold: true, size: 15),
      ]);
}

class _ReviewsPage extends StatelessWidget {
  const _ReviewsPage({required this.activityName, required this.reviews});

  final String activityName;
  final List<Map<String, dynamic>> reviews;

  double get rating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<num>(
        0,
        (sum, review) =>
            sum + (num.tryParse(review['rating']?.toString() ?? '') ?? 0));
    return total / reviews.length;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                children: [
                  Row(children: [
                    Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 24))),
                    const SizedBox(width: 22),
                    Expanded(
                        child:
                            _text('Reviews & Ratings', bold: true, size: 28)),
                  ]),
                  const SizedBox(height: 28),
                  _text(activityName, bold: true, size: 20),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: _panel(
                            child: Column(children: [
                      _text(rating.toStringAsFixed(1), bold: true, size: 44),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                              5,
                              (i) => Icon(
                                  i < rating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: const Color(0xFFD8F34A)))),
                      const SizedBox(height: 8),
                      _text('(${reviews.length} Review)', size: 14),
                    ]))),
                    const SizedBox(width: 18),
                    Expanded(child: _ratingBars()),
                  ]),
                  const SizedBox(height: 24),
                  if (reviews.isEmpty)
                    Center(child: _text('No reviews yet', color: Colors.grey))
                  else
                    ...reviews.map(_reviewCard),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _ratingBars() => Column(
        children: [
          for (var star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                    width: 24, child: _text('$star', bold: true, size: 18)),
                const Icon(Icons.star, size: 14, color: Color(0xFF202124)),
                const SizedBox(width: 6),
                Expanded(
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            minHeight: 7,
                            value: reviews.isEmpty ? 0 : .2,
                            backgroundColor: Colors.white,
                            color: const Color(0xFFD8F34A)))),
              ]),
            )
        ],
      );

  Widget _reviewCard(Map<String, dynamic> review) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
                backgroundColor: Color(0xFFD9D9D9),
                child: Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: _text(review['name']?.toString() ?? 'Customer',
                    bold: true, size: 16)),
            _text(review['createdAgo']?.toString() ?? '',
                size: 10, color: Colors.black87),
          ]),
          const SizedBox(height: 8),
          Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                      i <
                              (num.tryParse(
                                      review['rating']?.toString() ?? '') ??
                                  0)
                          ? Icons.star
                          : Icons.star_border,
                      color: const Color(0xFFD8F34A),
                      size: 16))),
          const SizedBox(height: 8),
          _text(review['body']?.toString() ?? '', size: 13),
        ])),
      );
}

class _ImagesPage extends StatefulWidget {
  const _ImagesPage(
      {required this.activityName,
      required this.load,
      required this.upload,
      required this.remove,
      required this.imageUrl});
  final String activityName;
  final List<String> Function() load;
  final Future<void> Function() upload;
  final Future<void> Function(String) remove;
  final String Function(String) imageUrl;
  @override
  State<_ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<_ImagesPage> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _background,
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
            child: SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  children: [
                    SizedBox(
                      height: 52,
                      child: Stack(alignment: Alignment.center, children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 2,
                                child: IconButton(
                                    tooltip: 'Back',
                                    onPressed: _busy
                                        ? null
                                        : () => Navigator.pop(context),
                                    icon: const Icon(Icons.arrow_back,
                                        size: 24)))),
                        Center(
                            child:
                                _text('Update Images', bold: true, size: 28)),
                      ]),
                    ),
                    const SizedBox(height: 36),
                    Row(children: [
                      Expanded(
                          child:
                              _text(widget.activityName, bold: true, size: 30)),
                      Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: IconButton(
                              tooltip: 'Upload images',
                              onPressed:
                                  _busy ? null : () => _run(widget.upload),
                              icon: const Icon(Icons.add,
                                  color: _purple, size: 30))),
                    ]),
                    const SizedBox(height: 8),
                    _text("Upload this activity's images", size: 17),
                    const SizedBox(height: 8),
                    _text(
                        '${widget.load().length} / 12 Images Uploaded'
                        '${widget.load().length > 12 ? ' - remove ${widget.load().length - 12}' : ''}',
                        size: 15,
                        color: widget.load().length > 12
                            ? Colors.redAccent
                            : _purple),
                    const SizedBox(height: 34),
                    if (widget.load().isEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(
                              child:
                                  _text('No images yet', color: Colors.grey)))
                    else
                      GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 18,
                                  childAspectRatio: .78),
                          itemCount: widget.load().length,
                          itemBuilder: (_, i) {
                            final url = widget.load()[i];
                            return _imageSlot(url);
                          }),
                  ],
                ))),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: _button('Save Changes',
                    _busy ? null : () => Navigator.pop(context)))),
      ]));

  Widget _imageSlot(String url) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE1E7D2)),
                ),
                child: Image.network(
                  widget.imageUrl(url),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 34,
                      color: Color(0xFF202124),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: const Color(0xFF7450B6),
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                tooltip: 'Remove image',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  fixedSize: const Size.square(42),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _busy ? null : () => _run(() => widget.remove(url)),
                icon: const Icon(Icons.delete_outline, size: 24),
              ),
            ),
          ),
        ],
      );
}
