import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'AddActivityDetailsScreen.dart';

class AddSelectedVenueFormScreen extends StatelessWidget {
  const AddSelectedVenueFormScreen({
    super.key,
    this.activityId = '',
    this.activityIdFuture,
    this.onActivityReady,
    this.initialActivity,
    this.initialQuestions,
    this.client,
    this.isEdit = false,
  });

  final String activityId;
  final Future<String>? activityIdFuture;
  final Future<void> Function(String activityId)? onActivityReady;
  final Map<String, dynamic>? initialActivity;
  final List<Map<String, dynamic>>? initialQuestions;
  final http.Client? client;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    if (activityId.isEmpty && activityIdFuture != null) {
      return FutureBuilder<String>(
        future: activityIdFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFFF7F8F3),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF9D38EB)),
              ),
            );
          }
          final resolvedId = snapshot.data!;
          if (onActivityReady != null) {
            onActivityReady!(resolvedId);
          }
          return AddActivityDetailsScreen(
            activityId: resolvedId,
            initialActivity: initialActivity,
            initialQuestions: initialQuestions,
            client: client,
            isEdit: isEdit,
          );
        },
      );
    }

    if (onActivityReady != null && activityId.isNotEmpty) {
      onActivityReady!(activityId);
    }

    return AddActivityDetailsScreen(
      activityId: activityId,
      initialActivity: initialActivity,
      initialQuestions: initialQuestions,
      client: client,
      isEdit: isEdit,
    );
  }
}
