import 'package:flutter/material.dart';

import '../Style/onboarding_styles.dart';

Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppTimePicker(initialTime: initialTime),
  );
}

class _AppTimePicker extends StatefulWidget {
  const _AppTimePicker({required this.initialTime});
  final TimeOfDay initialTime;

  @override
  State<_AppTimePicker> createState() => _AppTimePickerState();
}

class _AppTimePickerState extends State<_AppTimePicker> {
  late int _hour, _minute, _period;
  late final FixedExtentScrollController _hours, _minutes, _periods;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hourOfPeriod == 0
        ? 12
        : widget.initialTime.hourOfPeriod;
    _minute = widget.initialTime.minute;
    _period = widget.initialTime.period == DayPeriod.am ? 0 : 1;
    _hours = FixedExtentScrollController(initialItem: _hour - 1);
    _minutes = FixedExtentScrollController(initialItem: _minute);
    _periods = FixedExtentScrollController(initialItem: _period);
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _periods.dispose();
    super.dispose();
  }

  Widget _label(String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(label,
            textAlign: TextAlign.center,
            style: OnboardingStyles.body.copyWith(
                color: const Color(0xFF69706A), fontWeight: FontWeight.w600)),
      );

  Widget _wheel(
          {required FixedExtentScrollController controller,
          required int itemCount,
          required String Function(int) label,
          required ValueChanged<int> onChanged}) =>
      ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) => Center(
              child: Text(label(index),
                  style: OnboardingStyles.body.copyWith(fontSize: 18))),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4FBD7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFF8F9690),
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                      child: Text('Select Time',
                          style:
                              OnboardingStyles.heading.copyWith(fontSize: 22))),
                  IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _label('Hour')),
                  Expanded(child: _label('Minute')),
                  Expanded(child: _label('AM / PM')),
                ]),
                const SizedBox(height: 4),
                SizedBox(
                    height: 180,
                    child: Row(children: [
                      Expanded(
                          child: _wheel(
                              controller: _hours,
                              itemCount: 12,
                              label: (index) =>
                                  (index + 1).toString().padLeft(2, '0'),
                              onChanged: (index) =>
                                  setState(() => _hour = index + 1))),
                      Expanded(
                          child: _wheel(
                              controller: _minutes,
                              itemCount: 60,
                              label: (index) =>
                                  index.toString().padLeft(2, '0'),
                              onChanged: (index) =>
                                  setState(() => _minute = index))),
                      Expanded(
                          child: _wheel(
                              controller: _periods,
                              itemCount: 2,
                              label: (index) => index == 0 ? 'AM' : 'PM',
                              onChanged: (index) =>
                                  setState(() => _period = index))),
                    ])),
                const SizedBox(height: 8),
                Text(
                    'Selected: ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')} ${_period == 0 ? 'AM' : 'PM'}',
                    style: OnboardingStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black26),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(
                              context,
                              TimeOfDay(
                                  hour: _hour % 12 + _period * 12,
                                  minute: _minute)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: const Color(0xFFD7FF35),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Confirm'))),
                ]),
              ]),
            )),
      );
}
