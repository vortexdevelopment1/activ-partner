import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'CommonCode.dart';
import 'onboarding_widgets.dart';

const _purple = Color(0xFF850FC6);
const _border = Color(0xFFDDDFDA);
const activityInputStyle = TextStyle(
    fontFamily: 'Satoshi', fontSize: 16, color: Colors.black, height: 1.25);

double activityDetailsGutter(BuildContext context) =>
    15;

String activityQuestionPlaceholder(
    String activity, String label, String configured) {
  if (configured.isNotEmpty) return configured;
  final name = activity.toLowerCase();
  if (label.toLowerCase().contains('description')) {
    if (name.contains('yoga')) {
      return 'Our yoga studio offers a calm space to stretch, move, and improve balance and flexibility. Sessions may include guided breathing, relaxation, and yoga practices for different experience levels.';
    }
    if (name.contains('gym')) {
      return 'Our gym offers a range of strength and cardio equipment for people with different fitness goals. Members can work out independently, follow their own training plans, and ask our team about available guidance. Suitable for beginners and experienced fitness enthusiasts.';
    }
  }
  if (label.toLowerCase() == 'studio area size') return '1200';
  if (name.contains('yoga') && label.toLowerCase() == 'floor type') {
    return 'Wooden mat flooring';
  }
  return '';
}

String activityBookingLabel(String name, {String? type}) {
  const labels = {
    'single_booking': 'Single booking',
    'court_booking': 'Court booking',
    'turf_booking': 'Turf booking',
    'table_booking': 'Table booking',
    'cricket_nets_booking': 'Cricket Nets booking'
  };
  if (labels.containsKey(type)) return labels[type]!;
  final lower = name.toLowerCase();
  if (lower.contains('cricket net')) return 'Cricket Nets booking';
  if (lower == 'pool' ||
      ['table tennis', 'pool table', 'snooker', 'teqball', 'billiard']
          .any(lower.contains)) {
    return 'Table booking';
  }
  if (['turf', 'hockey', 'paintball', 'frisbee', 'box cricket']
      .any(lower.contains)) {
    return 'Turf booking';
  }
  if ([
    'badminton',
    'tennis',
    'pickleball',
    'padel',
    'squash',
    'basketball',
    'volleyball',
    'padbol'
  ].any(lower.contains)) {
    return 'Court booking';
  }
  return 'Single booking';
}

String activityStepperSuffix(String label) {
  final lower = label.toLowerCase();
  for (final entry in <String, String>{
    'reformer': 'reformers',
    'trampoline': 'trampolines',
    'ground': 'grounds',
    'horse': 'horses',
    'climber': 'climbers',
    'archer': 'archers',
    'shooter': 'shooters',
    'swimmer': 'swimmers',
    'skater': 'skaters',
    'player': 'players',
    'participant': 'participants',
    'batch': 'per batch',
    'class': 'per batch',
    'capacity': 'people',
    'people': 'people',
    'court': 'courts',
    'turf': 'turfs',
    'table': 'tables',
    'net': 'nets',
    'lane': 'lanes',
    'arena': 'arenas'
  }.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return '';
}

List<String> activityUnits(String unit) => switch (unit) {
      'sq ft' || 'sq m' => ['sq ft', 'sq m'],
      'meters' || 'm' || 'ft' => ['m', 'ft'],
      'mins' || 'min' || 'hours' => ['mins', 'hours'],
      _ => [unit],
    };

num activityConvertUnit(num value, String from, String to) {
  if (from == to) return value;
  if (from == 'sq ft' && to == 'sq m') return value * 0.09290304;
  if (from == 'sq m' && to == 'sq ft') return value / 0.09290304;
  if ((from == 'meters' || from == 'm') && to == 'ft') return value / 0.3048;
  if ((to == 'meters' || to == 'm') && from == 'ft') return value * 0.3048;
  if (from == 'mins' && to == 'hours') return value / 60;
  if (from == 'hours' && to == 'mins') return value * 60;
  return value;
}

/// Shared screen frame for onboarding, adding, and editing activity details.
class ActivityDetailsLayout extends StatelessWidget {
  const ActivityDetailsLayout(
      {super.key,
      required this.child,
      required this.onContinue,
      required this.buttonLabel,
      this.saving = false,
      this.currentStep,
      this.totalSteps,
      this.onBack});
  final Widget child;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final String buttonLabel;
  final bool saving;
  final int? currentStep;
  final int? totalSteps;

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    child: Column(children: [
      if (currentStep != null && totalSteps != null) Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: getStepBarCount(currentStep! / totalSteps!, currentStep!, totalSteps!),
      ),
      const SizedBox(height: 24),
      Expanded(child: child),
      bottomBarShadow(),
      Row(children: [
        Expanded(flex: 3, child: Tooltip(message: 'Back', child: InkWell(
          onTap: saving ? null : onBack ?? () => Navigator.maybePop(context),
          child: getBackButton(context, 'Back', 'activityDetails'),
        ))),
        Expanded(flex: 7, child: Semantics(button: true, enabled: !saving && onContinue != null,
          child: InkWell(onTap: saving ? null : onContinue,
            child: Opacity(opacity: onContinue == null && !saving ? .5 : 1,
              child: getButtonBlack(context, saving ? 'Saving...' : buttonLabel, 'activityDetails'))))),
      ]),
    ]),
  );
}

class ActivityDetailsHeading extends StatelessWidget {
  const ActivityDetailsHeading(
      {super.key, required this.name, this.bookingType});
  final String name;
  final String? bookingType;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: Colors.black)),
        const SizedBox(height: 5),
        const Text('Provide Activity Specific Details',
            style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 16,
                height: 1.4,
                color: Color(0xFF55594D))),
      ]));
}

class ActivityDetailsLabel extends StatelessWidget {
  const ActivityDetailsLabel(
      {super.key, required this.label, this.required = false});
  final String label;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Flexible(
            child: Text(label,
                style:
                    activityInputStyle.copyWith(fontWeight: FontWeight.w500))),
        if (required)
          Text(' *',
              style:
                  activityInputStyle.copyWith(color: const Color(0xFFE84949))),
      ]));
}

/// Uses API-provided labels, options, placeholders and validation metadata.
class ActivityQuestionInput extends StatelessWidget {
  const ActivityQuestionInput(
      {super.key,
      required this.label,
      required this.type,
      required this.inputKey,
      this.controller,
      this.answer,
      this.onChanged,
      this.required = false,
      this.options = const [],
      this.placeholder = '',
      this.helper = '',
      this.maxLength,
      this.minLength,
      this.unit = '',
      this.selectedUnit,
      this.onUnitChanged});
  final String label, type, placeholder, helper, unit;
  final Key inputKey;
  final TextEditingController? controller;
  final dynamic answer;
  final ValueChanged<dynamic>? onChanged;
  final bool required;
  final List<String> options;
  final int? maxLength, minLength;
  final String? selectedUnit;
  final ValueChanged<String>? onUnitChanged;

  InputDecoration get decoration => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        hintText: placeholder.isNotEmpty
            ? placeholder
            : type == 'textarea'
                ? 'Describe this activity...'
                : 'Enter ${label.toLowerCase()}',
        hintStyle: activityInputStyle.copyWith(color: const Color(0xFF8A8C91)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _purple)),
      );

  String? validate(String? value) {
    final text = value?.trim() ?? '';
    if (required && text.isEmpty) return 'Please answer this question';
    if (text.isNotEmpty && minLength != null && text.length < minLength!) {
      return 'Enter at least $minLength characters';
    }
    if (type == 'number' &&
        text.isNotEmpty &&
        (num.tryParse(text) == null || num.parse(text) < 0)) {
      return 'Enter a valid number';
    }
    return null;
  }

  Widget textField() {
    final limit = maxLength ?? (type == 'textarea' ? 150 : null);
    final field = TextFormField(
        key: inputKey,
        controller: controller,
        style: activityInputStyle,
        minLines: type == 'textarea' ? 3 : 1,
        maxLines: type == 'textarea' ? 4 : 1,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : type == 'textarea'
                ? TextInputType.multiline
                : TextInputType.text,
        inputFormatters: [
          if (limit != null) LengthLimitingTextInputFormatter(limit),
          if (type == 'number')
            TextInputFormatter.withFunction((old, next) =>
                RegExp(r'^\d*\.?\d*$').hasMatch(next.text) ? next : old)
        ],
        onChanged: onChanged,
        validator: validate,
        decoration: decoration.copyWith(
            contentPadding: type == 'textarea'
                ? const EdgeInsets.fromLTRB(18, 13, 18, 32)
                : null));
    if (type == 'textarea' && controller != null) {
      return Stack(children: [
        field,
        Positioned(
            right: 12,
            bottom: 7,
            child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (_, value, __) => Text(
                    '${value.text.characters.length}/$limit',
                    style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        color: Color(0xFF83868B)))))
      ]);
    }
    if (unit.isEmpty) return field;
    final currentUnit = selectedUnit ?? unit;
    return TextFormField(
        key: inputKey,
        controller: controller,
        style: activityInputStyle,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: validate,
        onChanged: onChanged,
        inputFormatters: [
          TextInputFormatter.withFunction((old, next) =>
              RegExp(r'^\d*\.?\d*$').hasMatch(next.text) ? next : old)
        ],
        decoration: decoration.copyWith(
            suffixIconConstraints:
                const BoxConstraints(minWidth: 100, maxWidth: 120),
            suffixIcon: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: _border))),
                child: _UnitPicker(
                  currentUnit: currentUnit,
                  units: activityUnits(unit),
                  onChanged: onUnitChanged,
                ))));
  }

  Widget stepper() {
    final value = int.tryParse('$answer') ??
        (label.toLowerCase().contains('batch') ||
                label.toLowerCase().contains('capacity')
            ? 25
            : 1);
    final suffix = activityStepperSuffix(label);
    return Row(children: [
      Container(
          width: 200,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(9)),
          child: Row(children: [
            _stepButton(Icons.remove, 'Decrease $label',
                value > 1 ? () => onChanged?.call(value - 1) : null),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$value', style: activityInputStyle),
                    if (suffix.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        suffix,
                        style: activityInputStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64685B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _stepButton(
                Icons.add, 'Increase $label', () => onChanged?.call(value + 1)),
          ])),
    ]);
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? callback) =>
      IconButton(
          tooltip: tooltip,
          onPressed: callback,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 44),
          icon: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: Color(0xFFF0E5FB), shape: BoxShape.circle),
              child: Icon(icon,
                  size: 23, color: callback == null ? Colors.grey : _purple)));

  Widget radio() => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(9)),
      child: LayoutBuilder(
          builder: (context, constraints) =>
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final option in options)
                  SizedBox(
                      width: options.length <= 2
                          ? (constraints.maxWidth - 8 * (options.length - 1)) /
                              options.length
                          : constraints.maxWidth,
                      child: Semantics(
                          checked: answer == option,
                          inMutuallyExclusiveGroup: true,
                          button: true,
                          child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => onChanged?.call(option),
                              child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                      color: answer == option
                                          ? const Color(0xFFEDE0FC)
                                          : Colors.white,
                                      border: Border.all(
                                          color: answer == option
                                              ? const Color(0xFFEDE0FC)
                                              : _border),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Row(children: [
                                    Icon(
                                        answer == option
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: answer == option
                                            ? _purple
                                            : const Color(0xFFCCCED0),
                                        size: 23),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(option,
                                            style: activityInputStyle.copyWith(
                                                color: answer == option
                                                    ? _purple
                                                    : Colors.black)))
                                  ])))))
              ])));

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ActivityDetailsLabel(label: label, required: required),
        if (type == 'number_stepper')
          stepper()
        else if (type == 'radio')
          radio()
        else if (type == 'select')
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
              hoverColor: const Color(0xFFF7F7F7),
              highlightColor: const Color(0xFFF7F7F7),
              splashColor: Colors.transparent,
              buttonTheme: const ButtonThemeData(alignedDropdown: true),
            ),
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButtonFormField<String>(
                key: inputKey,
                initialValue:
                    options.contains(answer) ? answer as String : null,
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(9),
                elevation: 3,
                focusColor: Colors.transparent,
                menuMaxHeight: 250,
                style: activityInputStyle,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 24, color: Color(0xFF222222)),
                decoration: decoration.copyWith(hintText: null),
                hint: Text(placeholder.isNotEmpty ? placeholder : 'Select',
                    style: activityInputStyle.copyWith(
                        color: const Color(0xFF8A8C91))),
                items: options
                    .map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option, style: activityInputStyle)))
                    .toList(),
                onChanged: options.isEmpty ? null : onChanged,
                validator: (value) => required && value == null
                    ? 'Please answer this question'
                    : null),
            ),
          )
        else if (type == 'checkbox' || type == 'multiselect')
          Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _border),
                  borderRadius: BorderRadius.circular(9)),
              child: Column(children: [
                for (final option in options)
                  Builder(builder: (context) {
                    final selected =
                        answer is List && (answer as List).contains(option);
                    void update(bool? checked) {
                      final next = answer is List
                          ? List<String>.from(answer)
                          : <String>[];
                      checked == true ? next.add(option) : next.remove(option);
                      onChanged?.call(next);
                    }

                    return InkWell(
                        onTap: () => update(!selected),
                        child: Row(children: [
                          Checkbox(
                              value: selected,
                              activeColor: _purple,
                              onChanged: update),
                          Expanded(
                              child: Text(option, style: activityInputStyle)),
                          const SizedBox(width: 12),
                        ]));
                  })
              ]))
        else
          textField(),
        if (helper.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(helper,
                  style: activityInputStyle.copyWith(
                      fontSize: 12, color: Colors.grey))),
      ]));
}

class _UnitPicker extends StatelessWidget {
  const _UnitPicker({
    required this.currentUnit,
    required this.units,
    required this.onChanged,
  });

  final String currentUnit;
  final List<String> units;
  final ValueChanged<String>? onChanged;

  void _showUnitMenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final translation = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;

    final estimatedMenuHeight = units.length * 48.0 + 16.0;
    final bottomBarThreshold = screenHeight - (media.padding.bottom + 100.0);
    final openUpwards =
        (translation.dy + size.height + estimatedMenuHeight) > bottomBarThreshold;

    final RelativeRect position;
    if (openUpwards) {
      position = RelativeRect.fromLTRB(
        translation.dx,
        0,
        screenWidth - translation.dx - size.width,
        screenHeight - translation.dy + 4,
      );
    } else {
      position = RelativeRect.fromLTRB(
        translation.dx,
        translation.dy + size.height + 4,
        screenWidth - translation.dx - size.width,
        0,
      );
    }

    final selected = await showMenu<String>(
      context: context,
      position: position,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      color: Colors.white,
      items: units
          .map((u) => PopupMenuItem<String>(
                value: u,
                height: 44,
                child: Text(u, style: activityInputStyle),
              ))
          .toList(),
    );

    if (selected != null) {
      onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: units.length > 1 ? () => _showUnitMenu(context) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              currentUnit,
              style: activityInputStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down,
              size: 22, color: Color(0xFF222222)),
        ],
      ),
    );
  }
}

