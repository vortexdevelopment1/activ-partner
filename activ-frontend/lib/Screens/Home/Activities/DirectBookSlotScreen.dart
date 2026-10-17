import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../Beans/activity_model.dart';
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
  _BookableSlot? _selectedSlot;
  bool _saving = false;
  bool _loadingSlots = false;
  String? _slotError;
  List<_BookableSlot>? _serverSlots;

  String get _activityName =>
      widget.activityData['name']?.toString() ?? widget.activity.title;

  String get _serviceId =>
      widget.activityData['id']?.toString() ??
      widget.activityData['activityId']?.toString() ??
      widget.activity.activityId;

  List<String> get _courts {
    final count = int.tryParse(widget.activity.numberOfCourt) ??
        int.tryParse(widget.activityData['numberOfCourt']?.toString() ?? '') ??
        int.tryParse(widget.activityData['number_of_court']?.toString() ?? '') ??
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

  bool get _hasAvailableSlot => _slots.any((slot) => slot.isAvailable);

  Future<void> _loadSlots() async {
    if (!mounted || _serviceId.isEmpty || widget.venueId.isEmpty) return;
    setState(() {
      _loadingSlots = true;
      _slotError = null;
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
      final response = await (widget.client?.get ?? http.get)(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Unable to load slots.');
      }
      final data = body['data'] is Map ? body['data'] as Map : const {};
      final slots = data['slots'] is List ? data['slots'] as List : const [];
      if (!mounted) return;
      setState(() {
        _serverSlots = slots
            .whereType<Map>()
            .where((slot) => slot['status']?.toString() != 'not_operational')
            .map((slot) => _BookableSlot.fromStatus(Map<String, dynamic>.from(slot)))
            .toList();
        _selectedSlot = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverSlots = null;
        _slotError = error.toString().replaceFirst('Exception: ', '');
        _selectedSlot = null;
      });
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  dynamic _readTimingForSelectedActivity() {
    final categoryId = widget.activityData['categoryId']?.toString() ??
        widget.activity.operateValue['id']?.toString();
    final availability = widget.activityData['availability'];
    if (availability is Map && categoryId != null) {
      final scoped = availability[categoryId] ?? availability[categoryId.toString()];
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
        if (_slotFromMap(slot) != null)
          _slotFromMap(slot)!
    ];
  }

  _BookableSlot? _slotFromMap(Map slot) {
    final open = slot['openTime'] ?? slot['open'] ?? slot['startTime'];
    final close = slot['closeTime'] ?? slot['close'] ?? slot['endTime'];
    if (open == null || close == null) return null;
    final startTime = _toApiTime(open.toString());
    final endTime = _toApiTime(close.toString());
    return _BookableSlot(
      label: '${_normalTime(open.toString())} - ${_normalTime(close.toString())}',
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
                  decoration: const InputDecoration(labelText: 'Email optional'),
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
                        style:
                            TextStyle(fontFamily: 'Satoshi', fontSize: 16)),
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
      _selectedSlot = null;
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
        _selectedSlot = null;
      });
      await _loadSlots();
    }
  }

  Future<void> _reserve() async {
    if (_selectedSlot == null || !_selectedSlot!.isAvailable) {
      _message('Please select a slot.');
      return;
    }

    final participant = await _participantDetails();
    if (participant == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final token = await SharedPreference.readStr('jwt_token');
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await (widget.client?.post ?? http.post)(
              Uri.parse(
                  '$BASE_URL/venues/${widget.venueId}/activities/${widget.activity.activityId}/walk-in'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'court': _selectedCourt,
                'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                'slots': [
                  {
                    'startTime': _selectedSlot!.startTime,
                    'endTime': _selectedSlot!.endTime,
                  }
                ],
                ...participant,
              }))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        _message('Slot booked successfully.');
        Navigator.pop(context);
      } else if (response.statusCode == 409) {
        await _loadSlots();
        throw Exception('That slot is already reserved. Please choose another slot.');
      } else {
        throw Exception(_errorMessage(response.body));
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      if (slots.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _label('Select Slot', required: true),
                        const SizedBox(height: 10),
                        if (_loadingSlots)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(),
                          ),
                        if (_slotError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(_slotError!,
                                style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 13,
                                    color: Color(0xFFFF6B6B))),
                          ),
                        ...slots.map(_slotTile),
                      ] else ...[
                        const SizedBox(height: 26),
                        Text(
                            _loadingSlots
                                ? 'Loading slots...'
                                : 'No slots available for this date.',
                            style: const TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 15,
                                color: Color(0xFF686868))),
                      ],
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
                        onPressed:
                            _saving || !_hasAvailableSlot ? null : _reserve,
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

  Widget _slotTile(_BookableSlot slot) {
    final selected = slot.label == _selectedSlot?.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: !slot.isAvailable
            ? const Color(0xFFF3F3F3)
            : selected
                ? const Color(0xFFF6EBFF)
                : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: selected
                  ? _purple
                  : slot.isAvailable
                      ? _border
                      : const Color(0xFFD0D0D0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: slot.isAvailable
              ? () => setState(() => _selectedSlot = slot)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Text(slot.label,
                    style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 15,
                        color: slot.isAvailable
                            ? const Color(0xFF202124)
                            : const Color(0xFF8A8A8A))),
              ),
              if (!slot.isAvailable) ...[
                Text(slot.statusLabel,
                    style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        color: Color(0xFF8A8A8A))),
                const SizedBox(width: 8),
              ],
              if (slot.price != null && slot.price!.isNotEmpty)
                Text('\u20b9 ${slot.price}',
                    style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        color: Color(0xFF202124))),
              const SizedBox(width: 8),
              Icon(
                  !slot.isAvailable
                      ? Icons.block
                      : selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                  size: 22,
                  color: !slot.isAvailable
                      ? const Color(0xFF9A9A9A)
                      : selected
                          ? _purple
                          : const Color(0xFFB9BFC4)),
            ]),
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
              fontFamily: 'Satoshi',
              fontSize: 18,
              color: Color(0xFF202124)),
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
                fontFamily: 'Satoshi',
                fontSize: 16,
                color: Color(0xFF202124))),
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
          onTap: _saving ? null : onTap,
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
        _ => 'Unavailable',
      };

  factory _BookableSlot.fromStatus(Map<String, dynamic> json) {
    final start = json['startTime']?.toString() ?? '';
    final end = json['endTime']?.toString() ?? '';
    return _BookableSlot(
      label: '$start - $end',
      startTime: start,
      endTime: end,
      status: json['status']?.toString() ?? 'available',
    );
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
                      color: selected
                          ? const Color(0xFFF6E7FF)
                          : Colors.white,
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 22),
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
