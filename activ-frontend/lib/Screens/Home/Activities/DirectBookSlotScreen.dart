import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../Beans/activity_model.dart';
import 'WalkInBookingSuccessScreen.dart';
import '../../../api_calling/api_constant.dart';
import '../../../api_calling/api_request.dart';

const _background = Color(0xFFF0F6D2);
const _purple = Color(0xFFA536F5);
const _border = Color(0xFFDCE2E5);
const _lime = Color(0xFFD8F34A);

class DirectBookSlotScreen extends StatefulWidget {
  const DirectBookSlotScreen({
    super.key,
    required this.activity,
    required this.activityData,
    required this.venueId,
    required this.venueName,
    this.client,
  });

  final ActivityModel activity;
  final Map<String, dynamic> activityData;
  final String venueId;
  final String venueName;
  final http.Client? client;

  @override
  State<DirectBookSlotScreen> createState() => _DirectBookSlotScreenState();
}

class _DirectBookSlotScreenState extends State<DirectBookSlotScreen> {
  late DateTime _selectedDate;
  late String _selectedCourt;
  final List<_BookableSlot> _selectedSlots = [];
  bool _saving = false;
  bool _loadingSlots = false;
  String? _slotError;
  List<_BookableSlot>? _serverSlots;
  List<String>? _serverCourts;
  int _slotLoadGeneration = 0;

  String get _activityName =>
      widget.activityData['name']?.toString() ?? widget.activity.title;

  String get _serviceId =>
      widget.activityData['id']?.toString() ??
      widget.activityData['activityId']?.toString() ??
      widget.activity.activityId;

  List<String> get _courts {
    if (_serverCourts != null && _serverCourts!.isNotEmpty)
      return _serverCourts!;
    final count = int.tryParse(widget.activity.numberOfCourt) ??
        int.tryParse(widget.activityData['numberOfCourt']?.toString() ?? '') ??
        int.tryParse(
            widget.activityData['number_of_court']?.toString() ?? '') ??
        1;
    return List.generate(count < 1 ? 1 : count,
        (index) => 'Court ${(index + 1).toString().padLeft(2, '0')}');
  }

  List<_BookableSlot> get _slots {
    if (_serverSlots != null) return _serverSlots!;
    final day = DateFormat('EEEE').format(_selectedDate).toLowerCase();
    final raw = _readTimingForSelectedActivity();
    final matches = <_BookableSlot>[];

    if (raw is Map) {
      matches.addAll(_slotsFromDayMap(raw, day));
    } else if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        if (entry['day']?.toString().toLowerCase() == day) {
          matches.addAll(_slotsFromList(entry['slots']));
        }
      }
    }

    return matches;
  }

  List<_BookableSlot> _slotsFromDayMap(Map value, String day) {
    final directDay = value.entries
        .where((entry) => entry.key.toString().toLowerCase() == day)
        .expand((entry) => _slotsFromList(entry.value))
        .toList();
    if (directDay.isNotEmpty) return directDay;

    return value.values
        .whereType<Map>()
        .expand((nested) => _slotsFromDayMap(nested, day))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedCourt = _courts.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  Future<http.Response> _getSlotsResponse(Uri uri, String token) async {
    final get = widget.client?.get ?? http.get;
    final headers = {'Authorization': 'Bearer $token'};
    var response =
        await get(uri, headers: headers).timeout(const Duration(seconds: 15));
    // Availability reads can be retried safely after a temporary server failure.
    // Reservation POST requests are never retried here.
    if (response.statusCode >= 500) {
      response =
          await get(uri, headers: headers).timeout(const Duration(seconds: 15));
    }
    return response;
  }

  Future<void> _loadSlots() async {
    if (!mounted || _serviceId.isEmpty || widget.venueId.isEmpty) return;
    final generation = ++_slotLoadGeneration;
    setState(() {
      _loadingSlots = true;
      _slotError = null;
      _serverSlots = [];
      _selectedSlots.clear();
    });
    try {
      final token = await SharedPreference.readStr('jwt_token');
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }
      final uri = Uri.parse(
              '$BASE_URL/venues/${widget.venueId}/activities/$_serviceId/slots')
          .replace(queryParameters: {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'court': _selectedCourt,
      });
      final response = await _getSlotsResponse(uri, token);
      if (response.statusCode >= 500) {
        throw Exception('Unable to load slot availability. Please retry.');
      }
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Unable to load slots.');
      }
      final data = body['data'] is Map ? body['data'] as Map : const {};
      final slots = data['slots'] is List ? data['slots'] as List : const [];
      final courts = data['courts'] is List
          ? (data['courts'] as List)
              .map((court) => court.toString())
              .where((court) => court.isNotEmpty)
              .toList()
          : const <String>[];
      if (!mounted || generation != _slotLoadGeneration) return;
      setState(() {
        if (courts.isNotEmpty) _serverCourts = courts;
        _serverSlots = slots
            .whereType<Map>()
            .where((slot) => slot['status']?.toString() != 'not_operational')
            .map((slot) =>
                _BookableSlot.fromStatus(Map<String, dynamic>.from(slot)))
            .toList();
        _selectedSlots.clear();
      });
    } catch (error) {
      if (!mounted || generation != _slotLoadGeneration) return;
      setState(() {
        _serverSlots = [];
        _slotError = error.toString().replaceFirst('Exception: ', '');
        _selectedSlots.clear();
      });
    } finally {
      if (mounted && generation == _slotLoadGeneration) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Future<List<_BookableSlot>> _loadSlotsForDate(DateTime date) async {
    final token = await SharedPreference.readStr('jwt_token');
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again.');
    }
    final uri = Uri.parse(
            '$BASE_URL/venues/${widget.venueId}/activities/$_serviceId/slots')
        .replace(queryParameters: {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'court': _selectedCourt,
    });
    final response = await _getSlotsResponse(uri, token);
    if (response.statusCode >= 500) {
      throw Exception('Unable to load slot availability. Please retry.');
    }
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Unable to load slots.');
    }
    final data = body['data'] is Map ? body['data'] as Map : const {};
    final slots = data['slots'] is List ? data['slots'] as List : const [];
    return slots
        .whereType<Map>()
        .map(
            (slot) => _BookableSlot.fromStatus(Map<String, dynamic>.from(slot)))
        .toList();
  }

  dynamic _readTimingForSelectedActivity() {
    final categoryId = widget.activityData['categoryId']?.toString() ??
        widget.activity.operateValue['id']?.toString();
    final availability = widget.activityData['availability'];
    if (availability is Map && categoryId != null) {
      final scoped =
          availability[categoryId] ?? availability[categoryId.toString()];
      if (scoped != null) return scoped;
    }
    if (widget.activityData['venueTiming'] != null) {
      return widget.activityData['venueTiming'];
    }
    if (widget.activityData['venue_timing'] != null) {
      return widget.activityData['venue_timing'];
    }
    return widget.activity.venueTiming;
  }

  List<_BookableSlot> _slotsFromList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final slot in value.whereType<Map>())
        if (_slotFromMap(slot) != null) _slotFromMap(slot)!
    ];
  }

  _BookableSlot? _slotFromMap(Map slot) {
    final open = slot['openTime'] ?? slot['open'] ?? slot['startTime'];
    final close = slot['closeTime'] ?? slot['close'] ?? slot['endTime'];
    if (open == null || close == null) return null;
    final startTime = _toApiTime(open.toString());
    final endTime = _toApiTime(close.toString());
    return _BookableSlot(
      label:
          '${_normalTime(open.toString())} - ${_normalTime(close.toString())}',
      startTime: startTime,
      endTime: endTime,
      price: slot['discountedPrice']?.toString() ??
          slot['discounted_price']?.toString() ??
          slot['price']?.toString(),
    );
  }

  String _toApiTime(String value) {
    final trimmed = value.trim();
    if (!trimmed.contains('AM') && !trimmed.contains('PM')) {
      final parts = trimmed.split(':');
      if (parts.length < 2) return trimmed;
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }

    final parts = trimmed.split(' ');
    final clock = parts.first.split(':');
    var hour = int.tryParse(clock.first) ?? 0;
    final minute = clock.length > 1 ? int.tryParse(clock[1]) ?? 0 : 0;
    final suffix = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>?> _participantDetails() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final form = GlobalKey<FormState>();

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SafeArea(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Participant Details',
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 20,
                        color: Color(0xFF202124))),
                const SizedBox(height: 18),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter participant name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixText: '+91 ',
                    counterText: '',
                  ),
                  validator: (value) {
                    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (digits.isEmpty) return 'Enter phone number';
                    if (digits.length != 10) {
                      return 'Enter a valid 10 digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email optional'),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      final phoneDigits =
                          phone.text.replaceAll(RegExp(r'\D'), '');
                      Navigator.pop(context, {
                        'participantName': name.text.trim(),
                        'participantPhone': '+91$phoneDigits',
                        if (email.text.trim().isNotEmpty)
                          'participantEmail': email.text.trim(),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F1F1F),
                      foregroundColor: _lime,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reserve Slot',
                        style: TextStyle(fontFamily: 'Satoshi', fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      phone.dispose();
      email.dispose();
    });
  }

  String _normalTime(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('AM') || trimmed.contains('PM')) return trimmed;
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _selectedDate = date;
      _selectedSlots.clear();
    });
    await _loadSlots();
  }

  Future<void> _pickCourt() async {
    final court = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CourtPickerSheet(
        courts: _courts,
        selectedCourt: _selectedCourt,
      ),
    );
    if (court != null && mounted) {
      setState(() {
        _selectedCourt = court;
        _selectedSlots.clear();
      });
      await _loadSlots();
    }
  }

  Future<void> _reserve() async {
    if (_selectedSlots.isEmpty) {
      _message('Please select at least one slot.');
      return;
    }

    final details = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _WalkInParticipantScreen(
          slots: _selectedSlots.map((slot) => slot.label).toList(),
        ),
      ),
    );
    if (details == null || !mounted) return;
    final participant = <String, String>{
      'participantName': details['participantName']!,
      'participantPhone': details['participantPhone']!,
      if (details['participantEmail']?.isNotEmpty == true)
        'participantEmail': details['participantEmail']!,
    };
    final payment = <String, String>{
      'paymentMethod': details['paymentMethod']!,
      'paymentStatus': details['paymentStatus']!,
      if (details['amountPaise']?.isNotEmpty == true)
        'amountPaise': details['amountPaise']!,
      if (details['notes']?.isNotEmpty == true) 'notes': details['notes']!,
    };

    final idempotencyKey =
        '${DateTime.now().microsecondsSinceEpoch}-${_selectedSlots.first.startTime}';
    final booking = <String, dynamic>{
      'court': _selectedCourt,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'slots': _selectedSlots
          .map((slot) => {
                'startTime': slot.startTime,
                'endTime': slot.endTime,
              })
          .toList(),
      'idempotencyKey': idempotencyKey,
      ...payment,
      ...participant,
    };
    final payload = jsonEncode(booking);
    final body = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _WalkInReviewScreen(
          venueName: widget.venueName,
          activityName: _activityName,
          court: _selectedCourt,
          date: _selectedDate,
          slots: _selectedSlots.map((slot) => slot.label).toList(),
          participant: participant,
          payment: payment,
          onConfirm: () async {
            final token = await SharedPreference.readStr('jwt_token');
            if (token == null || token.isEmpty) {
              throw Exception('Please sign in again.');
            }
            var checkSavedBooking = true;
            try {
              final response = await (widget.client?.post ?? http.post)(
                Uri.parse(
                    '$BASE_URL/venues/${widget.venueId}/activities/$_serviceId/walk-in'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json'
                },
                body: payload,
              ).timeout(const Duration(seconds: 30), onTimeout: () {
                throw Exception(
                    'Confirmation timed out. Retry to check this booking safely.');
              });
              if (response.statusCode == 409) {
                throw Exception(
                    'That slot is already reserved. Go back and choose another slot.');
              }
              if (response.statusCode >= 400 && response.statusCode < 500) {
                checkSavedBooking = false;
              }
              if (response.statusCode >= 500) {
                throw Exception(
                    'Unable to confirm this booking. Please retry.');
              }
              if (response.statusCode < 200 || response.statusCode >= 300) {
                throw Exception(_errorMessage(response.body));
              }
              final decoded = jsonDecode(response.body);
              if (decoded is! Map ||
                  decoded['data'] is! Map ||
                  decoded['data']['id'] == null) {
                throw Exception(
                    'Booking confirmation was not received. Please retry.');
              }
              return Map<String, dynamic>.from(decoded);
            } catch (_) {
              if (checkSavedBooking) {
                final saved = await _recoverConfirmedWalkIn(booking, token);
                if (saved != null) return {'data': saved};
              }
              rethrow;
            }
          },
        ),
      ),
    );
    if (body == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final bookAnother = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => WalkInBookingSuccessScreen(
                    venueName: widget.venueName,
                    date:
                        DateFormat('dd MMMM yyyy, EEEE').format(_selectedDate),
                    slots: _selectedSlots.map((slot) => slot.label).toList(),
                    court: _selectedCourt,
                    participantName: participant['participantName']!,
                    participantPhone: participant['participantPhone']!,
                    participantEmail: participant['participantEmail'],
                  )));
      if (!mounted) return;
      if (bookAnother == true) {
        _selectedSlots.clear();
        await _loadSlots();
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Map<String, dynamic>?> _recoverConfirmedWalkIn(
      Map<String, dynamic> booking, String token) async {
    try {
      final uri = Uri.parse(
              '$BASE_URL/venues/${widget.venueId}/activities/$_serviceId/walk-in')
          .replace(queryParameters: {'date': booking['date'].toString()});
      final response = await (widget.client?.get ?? http.get)(uri,
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final records = jsonDecode(response.body)['data'];
      if (records is! List) return null;
      final matches = records
          .whereType<Map>()
          .where((record) =>
              record['idempotencyKey'] == booking['idempotencyKey'] &&
              record['venueId'] == widget.venueId &&
              record['venueServiceId'] == _serviceId &&
              record['date'] == booking['date'] &&
              record['court'] == booking['court'] &&
              record['participantPhone'] == booking['participantPhone'] &&
              record['status'] == 'reserved' &&
              record['id'] != null)
          .toList();
      if (matches.isEmpty) return null;
      final savedSlots = <String>{
        for (final record in matches)
          if (record['slots'] is List)
            for (final slot in (record['slots'] as List).whereType<Map>())
              '${slot['startTime']}|${slot['endTime']}',
      };
      final expected = (booking['slots'] as List)
          .whereType<Map>()
          .map((slot) => '${slot['startTime']}|${slot['endTime']}')
          .toSet();
      if (expected.length != savedSlots.length ||
          !savedSlots.containsAll(expected)) return null;
      return Map<String, dynamic>.from(matches.first);
    } catch (_) {
      // An unsuccessful lookup must never be treated as a confirmed booking.
      return null;
    }
  }

  Future<void> _continueToSlotSelection() async {
    if (_loadingSlots || _slotError != null || _slots.isEmpty) {
      _message('No slots are available for this date.');
      return;
    }
    final selected = await Navigator.push<List<_BookableSlot>>(
      context,
      MaterialPageRoute(
        builder: (_) => _WalkInSlotSelectionScreen(
          date: _selectedDate,
          slots: _slots,
          selectedSlots: _selectedSlots,
          loadSlots: _loadSlotsForDate,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedSlots
        ..clear()
        ..addAll(selected);
    });
    if (_selectedSlots.isNotEmpty) await _reserve();
  }

  Future<Map<String, String>?> _paymentDetails() async {
    var method = 'Cash';
    var status = 'PAID';
    final notes = TextEditingController();
    final amount = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Payment details'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                      value: method,
                      decoration:
                          const InputDecoration(labelText: 'Payment method'),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => method = value ?? method)),
                  DropdownButtonFormField<String>(
                      value: status,
                      decoration:
                          const InputDecoration(labelText: 'Payment status'),
                      items: const [
                        DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                        DropdownMenuItem(
                            value: 'PENDING', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'PARTIAL', child: Text('Partially paid')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status)),
                  TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Total amount (₹, optional)')),
                  TextField(
                      controller: notes,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                            'paymentMethod': method,
                            'paymentStatus': status,
                            if (amount.text.trim().isNotEmpty)
                              'amountPaise':
                                  ((int.tryParse(amount.text.trim()) ?? 0) *
                                          100)
                                      .toString(),
                            if (notes.text.trim().isNotEmpty)
                              'notes': notes.text.trim()
                          }),
                      child: const Text('Continue'))
                ],
              )),
    );
    notes.dispose();
    amount.dispose();
    return result;
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['message']?.toString() ??
          'Unable to book this slot. Please try again.';
    } catch (_) {
      return 'Unable to book this slot. Please try again.';
    }
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 96),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
                    children: [
                      Row(children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 24),
                          ),
                        ),
                        const SizedBox(width: 28),
                        const Expanded(
                          child: Text('Book Slots',
                              style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 28,
                                  color: Color(0xFF202124))),
                        ),
                      ]),
                      const SizedBox(height: 64),
                      _label('Venue'),
                      _readonly(widget.venueName),
                      const SizedBox(height: 24),
                      _label('Activity'),
                      _readonly(_activityName),
                      const SizedBox(height: 24),
                      _label('Select Court', required: true),
                      _picker(_selectedCourt, Icons.chevron_right, _pickCourt),
                      const SizedBox(height: 24),
                      _label('Select Date', required: true),
                      _picker(DateFormat('dd MMMM yyyy').format(_selectedDate),
                          Icons.calendar_today_outlined, _pickDate,
                          iconColor: _purple),
                      if (_loadingSlots)
                        const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: LinearProgressIndicator(),
                        ),
                      if (_slotError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_slotError!,
                                  style: const TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 13,
                                      color: Color(0xFFFF6B6B))),
                              TextButton(
                                  onPressed: _loadSlots,
                                  child: const Text('Retry')),
                            ],
                          ),
                        ),
                      if (!_loadingSlots && _slotError == null && slots.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: Text('No slots available for this date.',
                              style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 15,
                                  color: Color(0xFF686868))),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
                    child: SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ||
                                _loadingSlots ||
                                !slots.any((slot) => slot.isAvailable)
                            ? null
                            : _continueToSlotSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F1F1F),
                          disabledBackgroundColor: Colors.grey.shade500,
                          disabledForegroundColor: const Color(0xFF6F6F6F),
                          foregroundColor: _lime,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_saving ? 'Booking...' : 'Next',
                            style: const TextStyle(
                                fontFamily: 'Satoshi', fontSize: 18)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                  text: ' *', style: TextStyle(color: Color(0xFFFF6B6B))),
          ]),
          style: const TextStyle(
              fontFamily: 'Satoshi', fontSize: 18, color: Color(0xFF202124)),
        ),
      );

  Widget _readonly(String value) => Container(
        height: 36,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE4E4E8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Satoshi', fontSize: 16, color: Color(0xFF202124))),
      );

  Widget _picker(String value, IconData icon, VoidCallback onTap,
          {Color iconColor = const Color(0xFF202124)}) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: (_saving || _loadingSlots) ? null : onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Expanded(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        color: Color(0xFF202124))),
              ),
              Icon(icon, color: iconColor, size: 27),
            ]),
          ),
        ),
      );
}

class _WalkInParticipantScreen extends StatefulWidget {
  const _WalkInParticipantScreen({required this.slots});

  final List<String> slots;

  @override
  State<_WalkInParticipantScreen> createState() =>
      _WalkInParticipantScreenState();
}

class _WalkInParticipantScreenState extends State<_WalkInParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  String _paymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _amount = TextEditingController();
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFD4D8B8))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFD4D8B8))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: _purple, width: 1.5)),
      );

  void _review() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    Navigator.pop(context, {
      'participantName': _name.text.trim(),
      'participantPhone': '+91$digits',
      'participantEmail': _email.text.trim(),
      'paymentMethod': _paymentMethod,
      'paymentStatus': 'PAID',
      'amountPaise': _amount.text.trim().isEmpty
          ? ''
          : ((int.tryParse(_amount.text.trim()) ?? 0) * 100).toString(),
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back)),
                  ),
                  const SizedBox(width: 18),
                  const Text('Participant Details',
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 25,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.slots.length} slot(s) selected',
                                style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...widget.slots.map((slot) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(slot,
                                    style: const TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 15,
                                        color: Color(0xFF666666))))),
                          ]),
                    ),
                    const SizedBox(height: 22),
                    const Text('Customer Name',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF5F6064))),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _name,
                        decoration: _input('Enter full name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter customer name'
                                : null),
                    const SizedBox(height: 18),
                    const Text('Mobile Number',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF5F6064))),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10)
                        ],
                        decoration: _input('10-digit mobile')
                            .copyWith(prefixText: '+91 ', counterText: ''),
                        validator: (value) => (value ?? '').length == 10
                            ? null
                            : 'Enter a valid 10 digit mobile number'),
                    const SizedBox(height: 18),
                    const Text('Email (optional)',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF5F6064))),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _input('Email address')),
                    const SizedBox(height: 22),
                    const Text('Payment Method',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF5F6064))),
                    ...[
                      'Cash',
                      'UPI',
                      'Card',
                      'Other'
                    ].map((method) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.black,
                        title: Text(method),
                        value: method,
                        groupValue: _paymentMethod,
                        onChanged: (value) => setState(
                            () => _paymentMethod = value ?? _paymentMethod))),
                    TextFormField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _input('Amount (₹, optional)')),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _notes,
                        decoration: _input('Notes (optional)'),
                        maxLines: 2),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                foregroundColor: const Color(0xFF5F6064),
                                side:
                                    const BorderSide(color: Color(0xFFD4D8B8)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28))),
                            child: const Text('Back'))),
                    const SizedBox(width: 14),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: _review,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: const Color(0xFF1F1F1F),
                                foregroundColor: _lime,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28))),
                            child: const Text('Review'))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _WalkInSlotSelectionScreen extends StatefulWidget {
  const _WalkInSlotSelectionScreen({
    required this.date,
    required this.slots,
    required this.selectedSlots,
    required this.loadSlots,
  });

  final DateTime date;
  final List<_BookableSlot> slots;
  final List<_BookableSlot> selectedSlots;
  final Future<List<_BookableSlot>> Function(DateTime date) loadSlots;

  @override
  State<_WalkInSlotSelectionScreen> createState() =>
      _WalkInSlotSelectionScreenState();
}

class _WalkInSlotSelectionScreenState
    extends State<_WalkInSlotSelectionScreen> {
  late DateTime _date = widget.date;
  late List<_BookableSlot> _slots = [...widget.slots];
  late final List<_BookableSlot> _selectedSlots = [...widget.selectedSlots];
  bool _loadingDate = false;

  Future<void> _changeDate(int days) async {
    final next = DateTime(_date.year, _date.month, _date.day + days);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isBefore(todayOnly) || _loadingDate) return;
    setState(() => _loadingDate = true);
    try {
      final slots = await widget.loadSlots(next);
      if (!mounted) return;
      setState(() {
        _date = next;
        _slots = slots;
        _selectedSlots.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _loadingDate = false);
    }
  }

  String _sectionFor(_BookableSlot slot) {
    final hour = int.tryParse(slot.startTime.split(':').first) ?? 0;
    if (hour < 12) return 'Morning';
    if (hour < 16) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }

  Color _statusColor(_BookableSlot slot) {
    if (slot.isAvailable) return const Color(0xFF39B54A);
    if (slot.status == 'walk_in_reserved') return Colors.orange;
    if (slot.status == 'activ_booking') return const Color(0xFF1687FF);
    return const Color(0xFFFF5B5B);
  }

  void _toggle(_BookableSlot slot) {
    if (!slot.isAvailable) return;
    setState(() {
      final index = _selectedSlots.indexWhere((item) =>
          item.startTime == slot.startTime && item.endTime == slot.endTime);
      if (index >= 0) {
        _selectedSlots.removeAt(index);
      } else {
        _selectedSlots.add(slot);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const sections = ['Morning', 'Afternoon', 'Evening', 'Night'];
    final visibleSlots = _slots
        .where((slot) => slot.status != 'not_operational')
        .toList();
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back)),
              ),
              const SizedBox(width: 18),
              const Text('Select Slot',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124))),
            ]),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: _loadingDate ? null : () => _changeDate(-1),
                icon: const Icon(Icons.chevron_left, size: 28)),
            SizedBox(
              width: 230,
              child: Text(DateFormat('dd MMMM yyyy, EEEE').format(_date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124))),
            ),
            IconButton(
                onPressed: _loadingDate ? null : () => _changeDate(1),
                icon: const Icon(Icons.chevron_right, size: 28)),
          ]),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
              children: [
                if (visibleSlots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No operating slots for this date. Choose another date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Satoshi', color: Color(0xFF686868))),
                  ),
                for (final section in sections)
                  if (visibleSlots.any((slot) => _sectionFor(slot) == section)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                      child: Row(children: [
                        Icon(
                          section == 'Morning'
                              ? Icons.wb_sunny_outlined
                              : section == 'Afternoon'
                                  ? Icons.wb_sunny
                                  : section == 'Evening'
                                      ? Icons.wb_twilight
                                      : Icons.nightlight_round,
                          color: _purple,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(section,
                            style: const TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    ...visibleSlots
                        .where((slot) => _sectionFor(slot) == section)
                        .map((slot) => _slotCard(slot)),
                  ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: const Color(0xFF202124),
                        side: const BorderSide(color: Color(0xFF202124)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedSlots.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedSlots),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF1F1F1F),
                        foregroundColor: _lime,
                        disabledBackgroundColor: Colors.grey.shade500,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Next'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _slotCard(_BookableSlot slot) {
    final selected = _selectedSlots.any((item) =>
        item.startTime == slot.startTime && item.endTime == slot.endTime);
    final statusColor = _statusColor(slot);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: slot.isAvailable
            ? selected
                ? const Color(0xFFF5E9FF)
                : Colors.white
            : const Color(0xFFE4E5E9),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: slot.isAvailable ? () => _toggle(slot) : null,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: selected ? _purple : const Color(0xFFD6E0E3))),
            child: Row(children: [
              Icon(
                  selected
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  color: selected ? _purple : const Color(0xFFCFDDE1),
                  size: 25),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(slot.label,
                      style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 15,
                          color: Color(0xFF555555)))),
              Text(slot.isAvailable ? 'Available' : slot.statusLabel,
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _WalkInReviewScreen extends StatefulWidget {
  const _WalkInReviewScreen({
    required this.venueName,
    required this.activityName,
    required this.court,
    required this.date,
    required this.slots,
    required this.participant,
    required this.payment,
    required this.onConfirm,
  });

  final String venueName;
  final String activityName;
  final String court;
  final DateTime date;
  final List<String> slots;
  final Map<String, String> participant;
  final Map<String, String> payment;
  final Future<Map<String, dynamic>> Function() onConfirm;

  @override
  State<_WalkInReviewScreen> createState() => _WalkInReviewScreenState();
}

class _WalkInReviewScreenState extends State<_WalkInReviewScreen> {
  bool _confirming = false;
  String? _error;

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (!mounted) return;
      setState(() => _confirming = false);
      Navigator.pop(context, result);
    } catch (error) {
      if (mounted)
        setState(() {
          _confirming = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
    }
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: child,
      );

  Text _line(String label, String value, {bool bold = false}) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: '),
          TextSpan(
              text: value,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : null)),
        ]),
        style: const TextStyle(
            fontFamily: 'Satoshi', fontSize: 17, color: Color(0xFF202124)),
      );

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_confirming,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
              child: Row(children: [
                Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                        onPressed:
                            _confirming ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back))),
                const SizedBox(width: 18),
                const Text('Review Booking',
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 27,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
                children: [
                  const Text('Review Walk-In Booking',
                      style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  _card(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line('Venue', widget.venueName),
                          const SizedBox(height: 8),
                          _line('Activity', widget.activityName),
                          const SizedBox(height: 8),
                          _line('Court', widget.court),
                          const SizedBox(height: 8),
                          _line(
                              'Date',
                              DateFormat('dd MMMM yyyy, EEEE')
                                  .format(widget.date)),
                          const Divider(height: 28),
                          ...widget.slots.map((slot) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(slot,
                                  style: const TextStyle(
                                      fontFamily: 'Satoshi', fontSize: 17)))),
                          const Divider(height: 28),
                          _line('Customer',
                              widget.participant['participantName']!,
                              bold: true),
                          const SizedBox(height: 14),
                          _line(
                              'Phone', widget.participant['participantPhone']!),
                          if (widget.participant['participantEmail']
                                  ?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 14),
                            _line('Email',
                                widget.participant['participantEmail']!),
                          ],
                          const SizedBox(height: 14),
                          _line('Payment method',
                              widget.payment['paymentMethod']!.toUpperCase()),
                          if (widget.payment['amountPaise']?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 8),
                            _line('Amount',
                                '₹ ${(int.parse(widget.payment['amountPaise']!) / 100).toStringAsFixed(0)}'),
                          ],
                          if (widget.payment['notes']?.isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            _line('Notes', widget.payment['notes']!),
                          ],
                        ]),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFB3261E)),
                          textAlign: TextAlign.center),
                    ),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _confirming
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                foregroundColor: const Color(0xFF5F6064),
                                side:
                                    const BorderSide(color: Color(0xFFD4D8B8)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28))),
                            child: const Text('Edit'))),
                    const SizedBox(width: 14),
                    Expanded(
                        flex: 2,
                        child: ElevatedButton(
                            onPressed: _confirming ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: const Color(0xFF1F1F1F),
                                foregroundColor: _lime,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28))),
                            child: _confirming
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: _lime)),
                                        SizedBox(width: 8),
                                        Flexible(
                                            child: Text('Confirming...',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontFamily: 'Satoshi'))),
                                      ])
                                : Text(_error == null
                                    ? 'Confirm'
                                    : 'Retry confirmation'))),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ));
}

class _BookableSlot {
  const _BookableSlot({
    required this.label,
    required this.startTime,
    required this.endTime,
    this.price,
    this.status = 'available',
  });

  final String label;
  final String startTime;
  final String endTime;
  final String? price;
  final String status;

  bool get isAvailable => status == 'available';

  String get statusLabel => switch (status) {
        'walk_in_reserved' => 'Reserved',
        'activ_booking' => 'Booked',
        'not_operational' => 'Not Operational',
        _ => 'Unavailable',
      };

  factory _BookableSlot.fromStatus(Map<String, dynamic> json) {
    final start = json['startTime']?.toString() ?? '';
    final end = json['endTime']?.toString() ?? '';
    return _BookableSlot(
      label: '${_displayTime(start)} - ${_displayTime(end)}',
      startTime: start,
      endTime: end,
      status: json['status']?.toString() ?? 'available',
    );
  }

  static String _displayTime(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('AM') || trimmed.contains('PM')) return trimmed;
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _CourtPickerSheet extends StatelessWidget {
  const _CourtPickerSheet({
    required this.courts,
    required this.selectedCourt,
  });

  final List<String> courts;
  final String selectedCourt;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .58,
          ),
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Select Court',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 20,
                      color: Color(0xFF202124))),
              const SizedBox(height: 18),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: courts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final court = courts[index];
                    final selected = court == selectedCourt;
                    return Material(
                      color: selected ? const Color(0xFFF6E7FF) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selected ? _purple : _border,
                          width: selected ? 1.2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, court),
                        child: SizedBox(
                          height: 58,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Row(children: [
                              Expanded(
                                child: Text(court,
                                    style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 16,
                                        color: selected
                                            ? _purple
                                            : const Color(0xFF202124))),
                              ),
                              if (selected)
                                const Icon(Icons.check,
                                    color: _purple, size: 24),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
