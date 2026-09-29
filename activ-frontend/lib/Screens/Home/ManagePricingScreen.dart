import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../../Utills/common_utilities.dart';
import '../StringExtensions.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _SlotData {
  TimeOfDay openTime;
  TimeOfDay closeTime;
  TextEditingController basePrice;
  TextEditingController dynamicPrice;
  int capacity;
  bool dynamicEnabled;
  bool expanded;

  _SlotData({
    required this.openTime,
    required this.closeTime,
    String basePrice = '',
    String dynamicPrice = '',
    this.capacity = 0,
    this.dynamicEnabled = false,
    this.expanded = false,
  })  : basePrice = TextEditingController(text: basePrice),
        dynamicPrice = TextEditingController(text: dynamicPrice);

  void dispose() {
    basePrice.dispose();
    dynamicPrice.dispose();
  }

}

class _DayData {
  final String label;
  bool selected;
  List<_SlotData> slots;

  _DayData({required this.label, this.selected = false, required this.slots});

  String get fullName => const {
        'Mon': 'Monday',
        'Tue': 'Tuesday',
        'Wed': 'Wednesday',
        'Thu': 'Thursday',
        'Fri': 'Friday',
        'Sat': 'Saturday',
        'Sun': 'Sunday',
      }[label]!;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ManagePricingScreen extends StatefulWidget {
  const ManagePricingScreen({super.key});

  @override
  State<ManagePricingScreen> createState() => _State();
}

class _State extends State<ManagePricingScreen> {
  bool _showErrors = false;
  late List<_DayData> _days;
  double _commissionPct = 15.0;
  String _venueId = '';
  List<String> _categoryIds = [];
  bool _saving = false;

  bool _loading = true;

  static const _dayLabelMap = {
    'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed',
    'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat', 'sunday': 'Sun',
  };

  @override
  void initState() {
    super.initState();
    _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        .map((l) => _DayData(label: l, selected: false, slots: []))
        .toList();
    _loadData();
  }

  TimeOfDay _parseTime(String t) {
    try {
      final parts = t.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    for (final d in _days) {
      for (final s in d.slots) { s.dispose(); }
    }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $p';
  }

  Future<void> _pickTime(TimeOfDay initial, ValueChanged<TimeOfDay> onPicked) async {
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) onPicked(t);
  }

  Future<void> _loadData() async {
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final res = await http.get(
        Uri.parse(MY_APPROVED_VENUES_URL),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final List venues = (body['data'] is List) ? body['data'] : [];
        if (venues.isNotEmpty) {
          final venue = venues.last;

          // Commission + venue id
          final pct = double.tryParse(venue['commission']?.toString() ?? '') ?? 15.0;
          final venueId = venue['id']?.toString() ?? '';

          // Availability → merge slots by day across all categories
          final Map availability = venue['availability'] ?? {};
          final catIds = availability.keys.map((k) => k.toString()).toList();
          final Map<String, List<_SlotData>> merged = {};
          for (final categorySlots in availability.values) {
            for (final dayEntry in (categorySlots as List)) {
              final String day = (dayEntry['day'] ?? '').toString().toLowerCase();
              final String? label = _dayLabelMap[day];
              if (label == null) continue;
              merged.putIfAbsent(label, () => []);
              for (final slot in (dayEntry['slots'] as List? ?? [])) {
                final price = slot['price'];
                merged[label]!.add(_SlotData(
                  openTime: _parseTime(slot['openTime']?.toString() ?? '09:00 AM'),
                  closeTime: _parseTime(slot['closeTime']?.toString() ?? '07:00 PM'),
                  capacity: (slot['capacity'] as num?)?.toInt() ?? 0,
                  basePrice: price != null ? price.toString() : '0',
                  expanded: merged[label]!.isEmpty,
                ));
              }
            }
          }

          if (!mounted) return;
          setState(() {
            _commissionPct = pct;
            _venueId = venueId;
            _categoryIds = catIds;
            for (final day in _days) {
              if (merged.containsKey(day.label)) {
                day.selected = true;
                day.slots = merged[day.label]!;
              }
            }
            _loading = false;
          });
          return;
        }
      }
    } catch (e) {
      CommonUtilities.showLog('ManagePricing _loadData error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _copyToAll(int fromDayIndex) {
    final src = _days[fromDayIndex];
    setState(() {
      for (int i = 0; i < _days.length; i++) {
        if (i == fromDayIndex || !_days[i].selected) continue;
        for (final s in _days[i].slots) { s.dispose(); }
        _days[i].slots = src.slots.map((s) => _SlotData(
          openTime: s.openTime,
          closeTime: s.closeTime,
          basePrice: s.basePrice.text,
          dynamicPrice: s.dynamicPrice.text,
          dynamicEnabled: s.dynamicEnabled,
          expanded: s.expanded,
        )).toList();
      }
    });
  }

  bool _hasEmptyPrices() {
    for (final d in _days) {
      if (!d.selected) continue;
      for (final s in d.slots) {
        if (s.basePrice.text.trim().isEmpty) return true;
      }
    }
    return false;
  }

  Future<void> _savePricing() async {
    if (_venueId.isEmpty) return;
    setState(() => _saving = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      const fullDayNames = {
        'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
        'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday', 'Sun': 'Sunday',
      };
      // Build day map with selected days having slot data, others marked closed
      final Map<String, dynamic> daySlots = {};
      for (final day in _days) {
        final dayName = fullDayNames[day.label]!;
        if (!day.selected || day.slots.isEmpty) {
          daySlots[dayName] = [{'open': '-', 'close': '-'}];
        } else {
          daySlots[dayName] = day.slots.map((s) => {
            'open': _fmt(s.openTime),
            'close': _fmt(s.closeTime),
            'capacity': s.capacity,
            'price': double.tryParse(s.basePrice.text) ?? 0,
          }).toList();
        }
      }
      // Wrap per category
      final Map<String, dynamic> venueTiming = {};
      for (final catId in _categoryIds) {
        venueTiming[catId] = daySlots;
      }
      final res = await http.patch(
        Uri.parse('$BASE_URL/venues/$_venueId/availability'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'venue_timing': venueTiming}),
      );
      CommonUtilities.showLog('savePricing: ${res.statusCode} ${res.body}');
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        CommonUtilities.createSnackBar(context, 'Pricing updated successfully.');
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to update pricing';
        CommonUtilities.createSnackBar(context, msg is List ? msg.first : msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog('_savePricing error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onSaveTap() {
    setState(() => _showErrors = true);
    if (_hasEmptyPrices()) return;
    for (final day in _days) {
      if (!day.selected) continue;
      for (int i = 0; i < day.slots.length; i++) {
        final price = double.tryParse(day.slots[i].basePrice.text.trim()) ?? 0;
        if (price <= 0) {
          CommonUtilities.createSnackBar(context,
              'Base price for ${day.fullName} Slot ${i + 1} must be greater than 0.');
          return;
        }
      }
    }
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Are you sure?',
                        style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1F1F))),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF1F1F1F)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. This will update the pricing strategy for your venue.',
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF3F3F3F)),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9D38EB)),
                ),
                child: const Text(
                  "Note: This update won't change prices for any ongoing or confirmed bookings. The new pricing will take effect on upcoming slots.",
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9D38EB)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1F1F1F)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F1F1F))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _savePricing();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9D38EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text("Yes, I'm sure",
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5E8),
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D38EB)))
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    _buildDayChips(),
                    const SizedBox(height: 20),
                    _buildPricesHeader(),
                    const SizedBox(height: 16),
                    ..._buildDaySections(),
                  ],
                ),
              ),
              if (!_loading) _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1F1F1F)),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Manage pricing',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ],
      ),
    );
  }

  // ── Day chips ──────────────────────────────────────────────────────────────

  Widget _buildDayChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Operating Days',
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F1F1F))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_days.length, (i) {
            final d = _days[i];
            return InkWell(
              onTap: null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: d.selected ? const Color(0xFFEDE9FE) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: d.selected ? const Color(0xFFEDE9FE) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w600,
                    color: d.selected ? const Color(0xFF1F1F1F) : const Color(0xFF9E9E9E),
                    decoration: d.selected ? null : TextDecoration.lineThrough,
                    decorationColor: const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Prices header ──────────────────────────────────────────────────────────

  Widget _buildPricesHeader() {
    return Row(
      children: [
        const Text('Add prices per slot',
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F1F1F))),
        const Spacer(),
        InkWell(
          onTap: () {
            final first = _days.indexWhere((d) => d.selected);
            if (first >= 0) _copyToAll(first);
          },
          child: const Row(
            children: [
              Icon(Icons.copy_outlined, size: 14, color: Color(0xFF9D38EB)),
              SizedBox(width: 4),
              Text('Copy to all',
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9D38EB))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Day sections ───────────────────────────────────────────────────────────

  List<Widget> _buildDaySections() {
    final widgets = <Widget>[];
    for (int d = 0; d < _days.length; d++) {
      final day = _days[d];
      if (!day.selected) continue;
      widgets.add(Text(day.fullName,
          style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F))));
      widgets.add(const SizedBox(height: 8));
      for (int s = 0; s < day.slots.length; s++) {
        widgets.add(_buildSlotCard(d, s));
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _buildSlotCard(int dayIdx, int slotIdx) {
    final slot = _days[dayIdx].slots[slotIdx];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => slot.expanded = !slot.expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text('Slot ${slotIdx + 1}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F1F1F))),
                  const Spacer(),
                  Icon(slot.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF1F1F1F)),
                ],
              ),
            ),
          ),
          if (slot.expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSlotBody(dayIdx, slotIdx),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotBody(int dayIdx, int slotIdx) {
    final slot = _days[dayIdx].slots[slotIdx];
    final hasError = _showErrors && slot.basePrice.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time row
        Row(
          children: [
            Expanded(child: _buildTimeField('Open Time', slot.openTime, (t) => setState(() => slot.openTime = t))),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeField('Close Time', slot.closeTime, (t) => setState(() => slot.closeTime = t))),
          ],
        ),
        const SizedBox(height: 14),
        // Base price
        _buildLabel('Base Price (₹)*'),
        const SizedBox(height: 6),
        _buildPriceField(slot.basePrice, hasError: hasError, onChange: () => setState(() {})),
        if (hasError) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Color(0xFFFE6B6B)),
              SizedBox(width: 4),
              Text('Please enter a base price to save changes.',
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFFE6B6B))),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 14),
        // You earn
        _buildEarnRow(slot),
      ],
    );
  }

  Widget _buildTimeField(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickTime(time, onChanged),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(_fmt(time),
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F1F1F))),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceField(TextEditingController ctrl,
      {bool hasError = false, required VoidCallback onChange}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => onChange(),
      style: const TextStyle(
          fontSize: 13,
          fontFamily: 'Satoshi',
          fontWeight: FontWeight.w500,
          color: Color(0xFF1F1F1F)),
      decoration: InputDecoration(
        prefixText: ctrl.text.isNotEmpty ? '₹' : null,
        prefixStyle: const TextStyle(
            fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF1F1F1F)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasError ? const Color(0xFFFE6B6B) : const Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasError ? const Color(0xFFFE6B6B) : const Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasError ? const Color(0xFFFE6B6B) : const Color(0xFF9D38EB))),
      ),
    );
  }

  Widget _buildEarnRow(_SlotData slot) {
    final base = double.tryParse(slot.basePrice.text) ?? 0;
    final comm = base * (_commissionPct / 100);
    final earn = base - comm;
    final pctLabel = _commissionPct == _commissionPct.truncateToDouble()
        ? _commissionPct.toInt().toString()
        : _commissionPct.toStringAsFixed(1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You earn',
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1F1F))),
              Text("ACTIV's commission ($pctLabel%)",
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7F7F7F))),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(earn > 0 ? '₹${earn.toStringAsFixed(0)}' : '₹0',
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9D38EB))),
            Text(comm > 0 ? '₹${comm.toStringAsFixed(0)}' : '₹0',
                style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF7F7F7F))),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w600,
            color: Color(0xFF3F3F3F)));
  }

  Widget _buildSaveButton() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: InkWell(
        onTap: _onSaveTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Save Changes',
                style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFD700))),
          ),
        ),
      ),
    );
  }
}
