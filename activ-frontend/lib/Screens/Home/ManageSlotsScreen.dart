import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../../Utills/common_utilities.dart';
import '../StringExtensions.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _TimeSlot {
  String openTime;
  String closeTime;
  TextEditingController capacity;
  double price;

  _TimeSlot({this.openTime = '09:00 AM', this.closeTime = '07:00 PM', String capacity = '', this.price = 0})
      : capacity = TextEditingController(text: capacity);

  void dispose() => capacity.dispose();
}

class _DayData {
  final String label;
  bool selected;
  List<_TimeSlot> slots;

  _DayData({required this.label, this.selected = false, required this.slots});

  String get fullName => const {
        'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
        'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday', 'Sun': 'Sunday',
      }[label]!;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ManageSlotsScreen extends StatefulWidget {
  const ManageSlotsScreen({super.key});

  @override
  State<ManageSlotsScreen> createState() => _State();
}

class _State extends State<ManageSlotsScreen> {
  late List<_DayData> _days;
  bool _loading = true;
  bool _saving = false;
  String _venueId = '';
  List<String> _categoryIds = [];

  static const _dayLabelMap = {
    'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed',
    'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat', 'sunday': 'Sun',
  };

  static const List<String> _timeOptions = [
    '12:00 AM', '01:00 AM', '02:00 AM', '03:00 AM', '04:00 AM', '05:00 AM',
    '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM', '11:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
        .map((l) => _DayData(label: l, selected: false, slots: []))
        .toList();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      final res = await http.get(
        Uri.parse(MY_APPROVED_VENUES_URL),
        headers: {'Authorization': 'Bearer $token'},
      );
      CommonUtilities.showLog('ManageSlots availability: ${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final List venues = (body['data'] is List) ? body['data'] : [];
        if (venues.isEmpty) { if (mounted) setState(() => _loading = false); return; }

        _venueId = venues.last['id']?.toString() ?? '';
        // Merge slots from all categories by day
        final Map<String, List<_TimeSlot>> merged = {};
        final Map availability = venues.last['availability'] ?? {};
        _categoryIds = availability.keys.map((k) => k.toString()).toList();
        for (final categorySlots in availability.values) {
          for (final dayEntry in (categorySlots as List)) {
            final String day = (dayEntry['day'] ?? '').toString().toLowerCase();
            final String? label = _dayLabelMap[day];
            if (label == null) continue;
            merged.putIfAbsent(label, () => []);
            for (final slot in (dayEntry['slots'] as List? ?? [])) {
              final cap = slot['capacity'];
              final capStr = cap != null ? cap.toString() : '0';
              final price = (slot['price'] as num?)?.toDouble() ?? 0;
              merged[label]!.add(_TimeSlot(
                openTime: slot['openTime']?.toString() ?? '09:00 AM',
                closeTime: slot['closeTime']?.toString() ?? '07:00 PM',
                capacity: capStr,
                price: price,
              ));
            }
          }
        }

        if (!mounted) return;
        setState(() {
          for (final day in _days) {
            if (merged.containsKey(day.label)) {
              day.selected = true;
              day.slots = merged[day.label]!;
            }
          }
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      CommonUtilities.showLog('_loadAvailability error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final d in _days) {
      for (final s in d.slots) { s.dispose(); }
    }
    super.dispose();
  }

  void _copyToAll(int fromDayIndex) {
    final src = _days[fromDayIndex];
    setState(() {
      for (int i = 0; i < _days.length; i++) {
        if (i == fromDayIndex || !_days[i].selected) continue;
        for (final s in _days[i].slots) { s.dispose(); }
        _days[i].slots = src.slots.map((s) => _TimeSlot(
          openTime: s.openTime,
          closeTime: s.closeTime,
          capacity: s.capacity.text,
          price: s.price,
        )).toList();
      }
    });
  }

  void _onSaveTap() {
    for (final day in _days) {
      if (!day.selected) continue;
      for (int i = 0; i < day.slots.length; i++) {
        final cap = int.tryParse(day.slots[i].capacity.text.trim()) ?? 0;
        if (cap <= 0) {
          CommonUtilities.createSnackBar(context,
              'Capacity for ${day.fullName} Slot ${i + 1} must be greater than 0.');
          return;
        }
      }
    }
    _showConfirmDialog();
  }

  Future<void> _saveSlots() async {
    if (_venueId.isEmpty) return;
    setState(() => _saving = true);
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));

      // Build day-wise slots map
      final Map<String, dynamic> daySlots = {};
      final fullDayNames = {
        'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
        'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday', 'Sun': 'Sunday',
      };
      for (final day in _days) {
        if (!day.selected) continue;
        daySlots[fullDayNames[day.label]!] = day.slots.map((s) => {
          'open': s.openTime,
          'close': s.closeTime,
          'capacity': int.tryParse(s.capacity.text) ?? 0,
          'price': s.price,
        }).toList();
      }

      // Apply same day slots to all categories
      final Map<String, dynamic> venueTiming = {};
      for (final catId in _categoryIds) {
        venueTiming[catId] = daySlots;
      }

      final res = await http.patch(
        Uri.parse('$BASE_URL/venues/$_venueId/availability'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'venue_timing': venueTiming}),
      );
      CommonUtilities.showLog('saveSlots: ${res.statusCode} ${res.body}');
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        CommonUtilities.createSnackBar(context, 'Slots updated successfully.');
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to update slots';
        CommonUtilities.createSnackBar(context, msg is List ? msg.first : msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog('_saveSlots error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
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
                        style: TextStyle(fontSize: 18, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF1F1F1F)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. This will update the venue availability.',
                style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF3F3F3F)),
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
                  "Note: Updating your venue availability won't affect ongoing sessions or existing bookings. New timings will apply only to future bookings.",
                  style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, color: Color(0xFF9D38EB)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1F1F1F)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _saveSlots();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9D38EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text("Yes, I'm sure",
                          style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Colors.white)),
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
                    const SizedBox(height: 24),
                    const Text('Day Wise Timings',
                        style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                    const SizedBox(height: 14),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF1F1F1F)),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Manage slots',
              style: TextStyle(fontSize: 18, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
        ],
      ),
    );
  }

  Widget _buildDayChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mark Operating Days',
            style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_days.length, (i) {
            final d = _days[i];
            return InkWell(
              onTap: () {
                if (d.selected) {
                  final selectedCount = _days.where((x) => x.selected).length;
                  if (selectedCount <= 1) {
                    CommonUtilities.createSnackBar(context, 'At least one operating day must be selected.');
                    return;
                  }
                  setState(() {
                    for (final s in d.slots) { s.dispose(); }
                    d.slots.clear();
                    d.selected = false;
                  });
                } else {
                  setState(() {
                    d.selected = true;
                    if (d.slots.isEmpty) d.slots.add(_TimeSlot());
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: d.selected ? const Color(0xFFEDE9FE) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: d.selected ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB),
                    width: d.selected ? 1.5 : 1,
                  ),
                ),
                child: Text(d.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w600,
                        color: d.selected ? const Color(0xFF1F1F1F) : const Color(0xFF9E9E9E),
                        decoration: d.selected ? null : TextDecoration.lineThrough,
                        decorationColor: const Color(0xFF9E9E9E))),
              ),
            );
          }),
        ),
      ],
    );
  }

  List<Widget> _buildDaySections() {
    final widgets = <Widget>[];
    final selectedDays = _days.where((d) => d.selected).toList();
    for (int di = 0; di < selectedDays.length; di++) {
      final day = selectedDays[di];
      final dayIdx = _days.indexOf(day);
      widgets.add(_buildDaySection(dayIdx));
      if (di < selectedDays.length - 1) {
        widgets.add(const Divider(height: 28, color: Color(0xFFE5E7EB)));
      }
    }
    return widgets;
  }

  Widget _buildDaySection(int dayIdx) {
    final day = _days[dayIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(day.fullName,
                style: const TextStyle(fontSize: 14, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
            const Spacer(),
            InkWell(
              onTap: () => _copyToAll(dayIdx),
              child: const Row(
                children: [
                  Icon(Icons.copy_outlined, size: 14, color: Color(0xFF9D38EB)),
                  SizedBox(width: 4),
                  Text('Copy to all', style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF9D38EB))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(day.slots.length, (si) => _buildSlotRow(dayIdx, si)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => day.slots.add(_TimeSlot())),
          child: const Row(
            children: [
              Icon(Icons.add, size: 16, color: Color(0xFF9D38EB)),
              SizedBox(width: 4),
              Text('Add time slot',
                  style: TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFF9D38EB))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlotRow(int dayIdx, int slotIdx) {
    final slot = _days[dayIdx].slots[slotIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _slotLabel('Open Time'),
                  const SizedBox(height: 4),
                  _timeDropdown(slot.openTime, (v) => setState(() => slot.openTime = v!)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _slotLabel('Close Time'),
                  const SizedBox(height: 4),
                  _timeDropdown(slot.closeTime, (v) => setState(() => slot.closeTime = v!)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: InkWell(
                onTap: () {
                  final day = _days[dayIdx];
                  if (day.slots.length > 1) {
                    // Just remove this slot
                    setState(() {
                      slot.dispose();
                      day.slots.removeAt(slotIdx);
                    });
                  } else {
                    // Last slot — deselect the day, but only if at least 1 other day stays selected
                    final selectedCount = _days.where((d) => d.selected).length;
                    if (selectedCount <= 1) {
                      CommonUtilities.createSnackBar(context, 'At least one operating day must be selected.');
                      return;
                    }
                    setState(() {
                      slot.dispose();
                      day.slots.clear();
                      day.selected = false;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: const Icon(Icons.delete_outline, size: 22, color: Color(0xFF7F7F7F)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _slotLabel('Capacity'),
        const SizedBox(height: 4),
        TextFormField(
          controller: slot.capacity,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', fontWeight: FontWeight.w500, color: Color(0xFF1F1F1F)),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF9D38EB))),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _slotLabel(String text) {
    return Text.rich(TextSpan(children: [
      TextSpan(text: text, style: const TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w600, color: Color(0xFF3F3F3F))),
      const TextSpan(text: '*', style: TextStyle(color: Color(0xFFFE6B6B))),
    ]));
  }

  Widget _timeDropdown(String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeOptions.contains(value) ? value : _timeOptions.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF1F1F1F)),
          style: const TextStyle(fontSize: 13, fontFamily: 'Satoshi', color: Color(0xFF1F1F1F)),
          items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
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
          decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
          child: const Center(
            child: Text('Save Changes',
                style: TextStyle(fontSize: 15, fontFamily: 'Satoshi', fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
          ),
        ),
      ),
    );
  }
}
