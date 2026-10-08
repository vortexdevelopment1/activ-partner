import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../Beans/activity_model.dart';
import '../../../api_calling/api_constant.dart';
import '../../../api_calling/api_request.dart';
import '../ManagePricingScreen.dart';
import '../ManageSlotsScreen.dart';

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
  bool _loading = true, _saving = false, _expanded = false, _changed = false;
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
      setState(() => _expanded = false);
      _message('Bookings paused. Existing bookings are preserved.');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete Activity?'),
              content: const Text(
                  'New bookings will stop immediately. Existing bookings will be honored.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete Activity',
                        style: TextStyle(color: Colors.red)))
              ],
            ));
    if (confirmed == true && await _save({}, delete: true) && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _slots() async {
    final mode = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Manage Slots'),
                  onTap: () => Navigator.pop(context, 'slots')),
              ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Manage Pricing'),
                  onTap: () => Navigator.pop(context, 'pricing')),
            ])));
    if (mode == null || !mounted) return;
    final scoped = _ActivityClient(
        _client,
        _data['venueId']?.toString() ?? widget.venueId,
        _data['categoryId']?.toString() ??
            widget.activity.operateValue['id']?.toString() ??
            '');
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => mode == 'slots'
                ? ManageSlotsScreen(client: scoped)
                : ManagePricingScreen(client: scoped)));
    if (mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _information() async {
    final name = TextEditingController(text: _name);
    final description = TextEditingController(text: _description);
    final amenities = TextEditingController(
        text: (_data['amenities'] as List? ??
                widget.activity.placeOffer
                    .whereType<Map>()
                    .map((e) => e['title'])
                    .toList())
            .join(', '));
    final form = GlobalKey<FormState>();
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SafeArea(
            child: SingleChildScrollView(
                child: Form(
                    key: form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _text('Activity Information', size: 20, bold: true),
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: name,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                  labelText: 'Activity name'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter an activity name'
                                      : null),
                          TextFormField(
                              controller: description,
                              maxLines: 3,
                              maxLength: 5000,
                              decoration: const InputDecoration(
                                  labelText: 'Description')),
                          TextFormField(
                              controller: amenities,
                              decoration: const InputDecoration(
                                  labelText: 'Amenities',
                                  hintText: 'Parking, WiFi')),
                          const SizedBox(height: 20),
                          _button('Save Changes', () {
                            if (form.currentState!.validate()) {
                              Navigator.pop(context, {
                                'name': name.text.trim(),
                                'description': description.text.trim(),
                                'amenities': amenities.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList(),
                              });
                            }
                          }),
                        ])))),
      ),
    );
    // Modal fields remain mounted until the closing animation finishes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    description.dispose();
    amenities.dispose();
    if (values != null && mounted) await _save(values);
  }

  Future<void> _upload() async {
    try {
      final photos = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (photos.isEmpty || !mounted) return;
      if (photos.length > 10) {
        _message('Select up to 10 images at a time.');
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
              load: () => _images,
              upload: _upload,
              remove: _removeImage,
              imageUrl: _imageUrl)));

  void _allBookings() => _sheet('Recent Bookings',
      _items('bookings').map(_booking).toList(), 'No bookings yet');
  void _reviews() => _sheet(
      'Review & Ratings',
      _items('reviews')
          .map((review) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(review['name']?.toString() ?? 'Customer', bold: true),
                    Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                i < (review['rating'] as num? ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 20,
                                color: Colors.amber))),
                    _text(review['body']?.toString() ?? '', color: Colors.grey),
                  ])))
          .toList(),
      'No reviews yet');

  void _sheet(String title, List<Widget> children, String empty) =>
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .8,
                  child: Column(children: [
                    ListTile(
                        title: _text(title, size: 20, bold: true),
                        trailing: IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context))),
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.all(20),
                            children:
                                children.isEmpty ? [_text(empty)] : children)),
                  ]))));

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
                                      _data['bookingCount']?.toString() ??
                                          '\u2014',
                                      Icons.calendar_month_outlined)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _stat(
                                      'Total Earning',
                                      _data['earnings'] == null
                                          ? '\u2014'
                                          : _currency.format(num.tryParse(
                                                  _data['earnings']
                                                      .toString()) ??
                                              0),
                                      Icons.home_outlined)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _stat(
                                      'Occupancy',
                                      _data['occupancy'] == null
                                          ? '\u2014'
                                          : '${_data['occupancy']}%',
                                      Icons.meeting_room_outlined)),
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
                                          fontFamily: 'FontRegular')))
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
                  ? Image.asset('assets/ic_cock.png')
                  : Image.network(_imageUrl(photo),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('assets/ic_cock.png')))),
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
            style: const TextStyle(fontFamily: 'FontRegular', fontSize: 12)),
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
        child: _panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: _text(booking['customerName']?.toString() ?? 'Customer',
                    bold: true)),
            _badge(status, color)
          ]),
          const SizedBox(height: 8),
          _text(
              '${booking['activity'] ?? _name}  |  ${date == null ? '\u2014' : DateFormat('dd MMM yyyy  |  hh:mm a').format(date)}',
              color: Colors.grey,
              size: 12),
          const SizedBox(height: 12),
          _text(
              '${_currency.format(num.tryParse(booking['amount']?.toString() ?? '') ?? 0)}${booking['participants'] == null ? '' : '  |  ${booking['participants']} persons'}',
              bold: true,
              size: 16),
        ])));
  }

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
              onPressed: _canControl && !_saving
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
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
                            style: TextStyle(fontFamily: 'FontRegular'))),
                    Icon(_expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down)
                  ]))),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3))
                    ]),
                child: Column(children: [
                  ..._reasons.map((reason) => Semantics(
                      selected: _reason == reason.$1,
                      button: true,
                      child: InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _reason = reason.$1),
                        child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: _reason == reason.$1
                                    ? const Color(0xFFF6EBFF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(children: [
                              Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                      color: _purple,
                                      borderRadius: BorderRadius.circular(7)),
                                  child: Icon(reason.$3,
                                      color: Colors.white, size: 21)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    _text(reason.$1, bold: true, size: 12),
                                    _text(reason.$2,
                                        size: 10, color: Colors.grey.shade700),
                                  ])),
                            ])),
                      ))),
                  if (_reason == 'Other')
                    TextField(
                        controller: _otherReason,
                        maxLength: 500,
                        decoration: const InputDecoration(labelText: 'Reason')),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _expanded = false),
                            style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFF8DC),
                                foregroundColor: Colors.black,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            child: const Text('Cancel',
                                style: TextStyle(fontFamily: 'FontBold')))),
                    const SizedBox(width: 14),
                    Expanded(
                        flex: 2,
                        child: _button(_saving ? 'Pausing...' : 'Pause Booking',
                            _saving ? null : _pause))
                  ]),
                  const SizedBox(height: 10),
                ])),
          ],
        ] else if (_canControl)
          _button(_saving ? 'Resuming...' : 'Resume Booking',
              _saving ? null : () => _save({'isActive': true})),
        const SizedBox(height: 26),
        _text('What happens next?', bold: true),
        const SizedBox(height: 20),
        _effect(Icons.calendar_today_outlined,
            'New bookings will be blocked during the inactive period'),
        _effect(Icons.visibility_off_outlined,
            'Activity will be hidden from search & discovery'),
        _effect(
            Icons.notifications_none, 'ACTIV team may reach out if required'),
      ]));

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
            fontFamily: bold ? 'FontBold' : 'FontRegular',
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
            style: const TextStyle(fontFamily: 'FontBold', fontSize: 15))));

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

class _ImagesPage extends StatefulWidget {
  const _ImagesPage(
      {required this.load,
      required this.upload,
      required this.remove,
      required this.imageUrl});
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
      appBar: AppBar(
          title: const Text('Manage Images'), backgroundColor: _background),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
            child: widget.load().isEmpty
                ? const Center(child: Text('No images yet'))
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12),
                    itemCount: widget.load().length,
                    itemBuilder: (_, i) {
                      final url = widget.load()[i];
                      return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(fit: StackFit.expand, children: [
                            Image.network(widget.imageUrl(url),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined)),
                            Positioned(
                                right: 4,
                                top: 4,
                                child: IconButton.filled(
                                    tooltip: 'Remove image',
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() => widget.remove(url)),
                                    icon: const Icon(Icons.delete_outline))),
                          ]));
                    })),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: _button(_busy ? 'Uploading...' : 'Upload Images',
                    _busy ? null : () => _run(widget.upload)))),
      ]));
}
