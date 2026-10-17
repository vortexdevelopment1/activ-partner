import 'package:flutter/material.dart';

Future<bool> confirmCopyTimingsToAllDays(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Copy to all selected days?'),
        content: const Text(
          'This change will replace the timings for all selected days with these timings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('OK'),
          ),
        ],
      ),
    ) ??
    false;
