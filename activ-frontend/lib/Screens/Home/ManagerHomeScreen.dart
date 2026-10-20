import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ManageBookingsScreen.dart';

/// The dedicated home screen for partner team managers.
///
/// Managers intentionally enter the booking dashboard directly. The partner
/// dashboard (HomeScreen) is never used for this account type.
class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key, this.client});

  final http.Client? client;

  @override
  Widget build(BuildContext context) {
    return ManageBookingsScreen(client: client, managerLayout: true);
  }
}
