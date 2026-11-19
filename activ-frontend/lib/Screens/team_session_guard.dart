import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'LoginScreen.dart';

/// Keeps removed staff out of every route, including screens left idle.
class TeamSessionGuard extends StatefulWidget {
  const TeamSessionGuard({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.client,
    this.signOut,
  });

  static const checkInterval = Duration(seconds: 10);
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final http.Client? client;
  final Future<void> Function()? signOut;

  @override
  State<TeamSessionGuard> createState() => _TeamSessionGuardState();
}

class _TeamSessionGuardState extends State<TeamSessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (mounted && (state == null || state == AppLifecycleState.resumed)) _start();
    });
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(TeamSessionGuard.checkInterval, (_) => _check());
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      if (await SharedPreference.readStr('user_type') != 'team_member') return;
      final token = await SharedPreference.readStr('jwt_token');
      if (token == null || token.isEmpty) return;
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(AUTH_PROFILE_URL),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      // Permission errors/outages do not prove that this login was revoked.
      if (!mounted || response.statusCode != 401 ||
          await SharedPreference.readStr('jwt_token') != token ||
          await SharedPreference.readStr('user_type') != 'team_member') {
        return;
      }

      try {
        await (widget.signOut?.call() ?? FirebaseAuth.instance.signOut())
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        CommonUtilities.showLog('Firebase sign-out unavailable for revoked team session.');
      }
      // Ignore a verdict for an earlier login if the account changed in flight.
      if (!mounted || await SharedPreference.readStr('jwt_token') != token ||
          await SharedPreference.readStr('user_type') != 'team_member') {
        return;
      }
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      await SharedPreference.clearSF();
      if (!mounted || !navigator.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => LoginScreen(client: widget.client)),
        (_) => false,
      );
      CommonUtilities.createSnackBar(navigator.context,
          'Your team session is no longer valid. Please sign in again.');
    } catch (_) {
      // Connectivity failures retain the session and retry on the next check.
      CommonUtilities.showLog('Team session check unavailable; will retry.');
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
