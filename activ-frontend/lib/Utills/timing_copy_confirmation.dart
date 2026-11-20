import 'package:flutter/material.dart';

Future<bool> confirmCopyTimingsToAllDays(
  BuildContext context, {
  String sourceDay = 'this day',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF4FBD7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Copy schedule to all days',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        content: Text(
          'This will replace the time slots, capacity, and prices for every other selected day with $sourceDay\'s schedule.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 14,
            height: 1.35,
            color: Colors.black87,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontFamily: 'Satoshi')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFD7FF35),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text('Confirm',
                      style: TextStyle(fontFamily: 'Satoshi')),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;
