import 'package:flutter/material.dart';
import 'onboarding_widgets.dart';

/// Shared field layout for activity onboarding and editing existing activities.
class ActivityDetailsField extends StatelessWidget {
  const ActivityDetailsField({super.key, required this.label,
    required this.child, this.isRequired = false, this.helperText = ''});
  final String label;
  final Widget child;
  final bool isRequired;
  final String helperText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label${isRequired ? ' *' : ''}',
          style: OnboardingStyles.body.copyWith(
              fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      child,
      if (helperText.isNotEmpty) Text(helperText),
    ]),
  );
}

class ActivityDetailsOptions extends StatelessWidget {
  const ActivityDetailsOptions({super.key, required this.options,
    required this.values, required this.onChanged});
  final List<String> options;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) => Column(children: [
    for (final option in options)
      Builder(builder: (context) {
        final selected = values.contains(option);
        void update(bool? checked) {
          final next = List<String>.from(values);
          if (checked == true) {
            if (!next.contains(option)) next.add(option);
          } else {
            next.remove(option);
          }
          onChanged(next);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => update(!selected),
          child: Row(children: [
            Checkbox(value: selected, onChanged: update),
            Expanded(child: Text(option,
                style: OnboardingStyles.body.copyWith(fontSize: 14))),
          ]),
        );
      }),
  ]);
}
