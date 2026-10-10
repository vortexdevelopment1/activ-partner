import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../onboarding_widgets.dart';

class _Slot {
  String open, close;
  final TextEditingController capacity, price, discount;
  _Slot(
      {this.open = '09:00 AM',
      this.close = '07:00 PM',
      String capacity = '',
      String price = '',
      String discount = '0'})
      : capacity = TextEditingController(text: capacity),
        price = TextEditingController(text: price),
        discount = TextEditingController(text: discount);
  void dispose() {
    capacity.dispose();
    price.dispose();
    discount.dispose();
  }

  _Slot copy() => _Slot(
      open: open,
      close: close,
      capacity: capacity.text,
      price: price.text,
      discount: discount.text);
}

class ManageSlotsScreen extends StatefulWidget {
  const ManageSlotsScreen({super.key, this.client});
  final http.Client? client;
  @override
  State<ManageSlotsScreen> createState() => _State();
}

class _State extends State<ManageSlotsScreen> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  static const _purple = Color(0xFF9D38EB);
  final _schedules = <String, Map<String, List<_Slot>>>{};
  final _names = <String, String>{};
  String _venueId = '';
  String? _category, _error;
  bool _loading = true, _saving = false;
  Map<String, List<_Slot>> get _current => _schedules[_category]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final schedule in _schedules.values) {
      for (final slots in schedule.values) {
        for (final slot in slots) {
          slot.dispose();
        }
      }
    }
    super.dispose();
  }

  String _normalTime(String time) {
    if (time.contains('AM') || time.contains('PM')) return time;
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    return '${(hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0')}:${parts[1]} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  int _minutes(String time) {
    final parts = time.split(' '), clock = parts[0].split(':');
    return (int.parse(clock[0]) % 12 + (parts[1] == 'PM' ? 12 : 0)) * 60 +
        int.parse(clock[1]);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token');
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }
      final response = await (widget.client?.get ?? http.get)(
              Uri.parse(MY_APPROVED_VENUES_URL),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception('Unable to load slots. Please try again.');
      }
      final venues = jsonDecode(response.body)['data'] as List;
      if (venues.isEmpty) return;
      final venue = venues.last;
      final availability = venue['availability'] as Map? ?? {};
      _venueId = venue['id'].toString();
      for (final service in venue['services'] as List? ?? []) {
        if (service['status'] == 'approved' && service['categoryId'] != null) {
          _names[service['categoryId'].toString()] =
              service['name']?.toString() ?? 'Activity';
        }
      }
      for (final key in availability.keys) {
        _names.putIfAbsent(key.toString(), () => 'Activity');
      }
      for (final category in _names.keys) {
        final schedule = <String, List<_Slot>>{};
        for (final entry in availability[category] as List? ?? []) {
          final day = _days
              .where((day) =>
                  day.toLowerCase() == entry['day'].toString().toLowerCase())
              .firstOrNull;
          if (day == null) continue;
          schedule[day] = [
            for (final slot in entry['slots'] as List? ?? [])
              _Slot(
                  open: _normalTime(slot['openTime'].toString()),
                  close: _normalTime(slot['closeTime'].toString()),
                  capacity: slot['capacity']?.toString() ?? '',
                  price: slot['price']?.toString() ?? '',
                  discount: slot['discountedPrice']?.toString() ?? '0')
          ];
        }
        _schedules[category] = schedule;
      }
      _category = _names.keys.firstOrNull;
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to load slots. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
    ));
  }

  Future<void> _save() async {
    if (_saving || _category == null) return;
    if (_current.isEmpty) {
      _message('Select at least one operating day.');
      return;
    }
    for (final entry in _current.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final slot = entry.value[i],
            capacity = int.tryParse(entry.value[i].capacity.text);
        final price = double.tryParse(slot.price.text),
            discount = slot.discount.text.trim().isEmpty
                ? 0.0
                : double.tryParse(slot.discount.text);
        if (capacity == null || capacity <= 0) {
          _message('Maximum users must be a positive whole number.');
          return;
        }
        if (price == null || !price.isFinite || price <= 0) {
          _message('Slot price must be greater than 0.');
          return;
        }
        if (discount == null ||
            !discount.isFinite ||
            discount < 0 ||
            discount > price) {
          _message('Discounted price must be between 0 and the slot price.');
          return;
        }
        final start = _minutes(slot.open), end = _minutes(slot.close);
        if (end - start < 60) {
          _message('Close time must be at least one hour after open time.');
          return;
        }
        if (entry.value.take(i).any((other) =>
            start < _minutes(other.close) && end > _minutes(other.open))) {
          _message('Time ranges for ${entry.key} cannot overlap.');
          return;
        }
      }
    }
    setState(() => _saving = true);
    try {
      final token = await SharedPreference.readStr('jwt_token');
      final timing = {
        for (final entry in _current.entries)
          entry.key: [
            for (final slot in entry.value)
              {
                'open': slot.open,
                'close': slot.close,
                'capacity': int.parse(slot.capacity.text),
                'price': double.parse(slot.price.text),
                'discountedPrice': slot.discount.text.trim().isEmpty
                    ? 0.0
                    : double.parse(slot.discount.text),
              }
          ]
      };
      final response = await (widget.client?.patch ?? http.patch)(
          Uri.parse('$BASE_URL/venues/$_venueId/availability'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'venue_timing': {_category!: timing}
          })).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      _message(response.statusCode == 200 || response.statusCode == 201
          ? 'Slots and pricing updated successfully.'
          : 'Unable to save slots. Your changes are still here.');
    } catch (_) {
      if (mounted) {
        _message('Unable to save slots. Your changes are still here.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TextStyle get _heading => OnboardingStyles.heading.copyWith(fontSize: 18);
  Widget _label(String label,
          {bool required = true,
          bool heading = false,
          bool currency = false}) =>
      Text.rich(
          TextSpan(children: [
            TextSpan(text: label),
            if (currency) ...[
              const TextSpan(text: ' ('),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.currency_rupee, size: 18),
              ),
              const TextSpan(text: ')'),
            ],
            if (required)
              const TextSpan(
                  text: ' *', style: TextStyle(color: Color(0xFFFE6B6B)))
          ]),
          style: (heading
              ? _heading
              : OnboardingStyles.body.copyWith(fontSize: 15)));
  Widget _input(TextEditingController controller, Key key,
          {bool money = false, String? hint}) =>
      TextField(
        key: key,
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.numberWithOptions(decimal: money),
        inputFormatters: [
          money
              ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
              : FilteringTextInputFormatter.digitsOnly
        ],
        style: OnboardingStyles.body.copyWith(fontSize: 16),
        decoration: OnboardingStyles.inputDecoration(hintText: hint).copyWith(
            prefixIcon:
                money ? const Icon(Icons.currency_rupee, size: 18) : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _purple))),
      );
  Widget _time(String value, ValueChanged<String?> change) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: OnboardingStyles.inputDecoration(),
        style: OnboardingStyles.body,
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: [
          for (var hour = 0; hour < 24; hour++)
            DropdownMenuItem(
                value: _normalTime('${hour.toString().padLeft(2, '0')}:00'),
                child:
                    Text(_normalTime('${hour.toString().padLeft(2, '0')}:00'))),
          if (!value.endsWith(':00 AM') && !value.endsWith(':00 PM'))
            DropdownMenuItem(value: value, child: Text(value)),
        ],
        onChanged: _saving ? null : change,
      );

  Widget _day(String day) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(day, style: _heading)),
          TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        for (final other in _current.keys.toList()) {
                          if (other == day) continue;
                          for (final slot in _current[other]!) {
                            slot.dispose();
                          }
                          _current[other] = _current[day]!
                              .map((slot) => slot.copy())
                              .toList();
                        }
                      }),
              icon: const Icon(Icons.copy_outlined, size: 19),
              label: Text('Copy to all',
                  style: OnboardingStyles.body.copyWith(color: _purple)),
              style: TextButton.styleFrom(
                  foregroundColor: _purple, textStyle: OnboardingStyles.body)),
        ]),
        for (var index = 0; index < _current[day]!.length; index++)
          _slot(day, index),
        TextButton.icon(
            onPressed: _saving
                ? null
                : () => setState(() => _current[day]!.add(_Slot())),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add time slot',
                style: OnboardingStyles.body.copyWith(color: _purple)),
            style: TextButton.styleFrom(foregroundColor: _purple)),
        const SizedBox(height: 20),
      ]);

  Widget _slot(String day, int index) {
    final slot = _current[day]![index];
    return Padding(
        key: ObjectKey(slot),
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _label('Open Time'),
                  const SizedBox(height: 8),
                  _time(
                      slot.open, (value) => setState(() => slot.open = value!))
                ])),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _label('Close Time'),
                  const SizedBox(height: 8),
                  _time(slot.close,
                      (value) => setState(() => slot.close = value!))
                ])),
            SizedBox(
                width: 32,
                child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete time slot',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              slot.dispose();
                              _current[day]!.removeAt(index);
                              if (_current[day]!.isEmpty) _current.remove(day);
                            }),
                    icon: const Icon(Icons.delete_outline))),
          ]),
          const SizedBox(height: 14),
          _label('Max Users allowed per 1-Hour Slot'),
          const SizedBox(height: 8),
          _input(slot.capacity, Key('slot-capacity-$day-$index')),
          const SizedBox(height: 10),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD5DDDF))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Slot Price', heading: true, currency: true),
                    const SizedBox(height: 14),
                    _input(slot.price, Key('slot-price-$day-$index'),
                        money: true, hint: '500'),
                    const SizedBox(height: 20),
                    _label('Discounted Slot Price',
                        required: false, heading: true, currency: true),
                    const SizedBox(height: 14),
                    _input(slot.discount, Key('slot-discount-$day-$index'),
                        money: true, hint: '0'),
                  ])),
        ]));
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              IconButton.filledTonal(
                  tooltip: 'Back',
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Manage Slots & Pricing',
                      style: _heading.copyWith(fontSize: 23))),
            ])),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!),
                        TextButton(
                            onPressed: _load, child: const Text('Retry')),
                      ]))
                    : _category == null
                        ? const Center(
                            child: Text('No approved activities found.'))
                        : ListView(
                            key: const Key('manage-slots-scroll'),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            children: [
                                if (_names.length > 1) ...[
                                  DropdownButtonFormField<String>(
                                      initialValue: _category,
                                      decoration:
                                          OnboardingStyles.inputDecoration(
                                              hintText: 'Activity'),
                                      items: [
                                        for (final entry in _names.entries)
                                          DropdownMenuItem(
                                              value: entry.key,
                                              child: Text(entry.value))
                                      ],
                                      onChanged: _saving
                                          ? null
                                          : (value) => setState(
                                              () => _category = value)),
                                  const SizedBox(height: 20)
                                ],
                                Text('Mark Operating Days', style: _heading),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                    builder: (context, constraints) => Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              for (final day in _days)
                                                SizedBox(
                                                    width: (constraints.maxWidth -
                                                            36) /
                                                        4,
                                                    height: 54,
                                                    child: OutlinedButton(
                                                        style: OutlinedButton.styleFrom(
                                                            padding:
                                                                EdgeInsets.zero,
                                                            backgroundColor: _current
                                                                    .containsKey(
                                                                        day)
                                                                ? const Color(
                                                                    0xFFF6F0FC)
                                                                : Colors.white,
                                                            foregroundColor:
                                                                Colors.black,
                                                            side: BorderSide(
                                                                color: _current.containsKey(day)
                                                                    ? Colors
                                                                        .black
                                                                    : const Color(
                                                                        0xFFD5DDDF)),
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(8))),
                                                        onPressed: _saving
                                                            ? null
                                                            : () => setState(() {
                                                                  if (_current
                                                                      .containsKey(
                                                                          day)) {
                                                                    for (final slot
                                                                        in _current
                                                                            .remove(day)!) {
                                                                      slot.dispose();
                                                                    }
                                                                  } else {
                                                                    _current[
                                                                        day] = [
                                                                      _Slot()
                                                                    ];
                                                                  }
                                                                }),
                                                        child: Text(day.substring(0, 3), style: OnboardingStyles.body.copyWith(fontSize: 16)))),
                                            ])),
                                const SizedBox(height: 28),
                                Text('Day Wise Timings', style: _heading),
                                const SizedBox(height: 12),
                                for (final day in _days)
                                  if (_current.containsKey(day)) _day(day),
                              ])),
        if (!_loading && _error == null && _category != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: OnboardingButton(
                  label: 'Save Changes',
                  loading: _saving,
                  onPressed: _saving ? null : _save)),
      ]));
}
