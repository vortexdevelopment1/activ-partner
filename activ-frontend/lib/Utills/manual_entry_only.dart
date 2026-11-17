import 'package:flutter/material.dart';

/// Disables clipboard shortcuts while leaving normal editing available.
class ManualEntryOnly extends StatelessWidget {
  const ManualEntryOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
        actions: <Type, Action<Intent>>{
          CopySelectionTextIntent: DoNothingAction(),
          PasteTextIntent: DoNothingAction(),
        },
        child: child,
      );
}
