import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:no_context_navigation/no_context_navigation.dart';

import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'Home/HomeScreen.dart';

class VenueApprovedCongratsScreen extends StatefulWidget {
  final String venueId;
  final String? venueReference;
  final String? venueName;
  final http.Client? client;

  const VenueApprovedCongratsScreen({
    super.key,
    required this.venueId,
    this.venueReference,
    this.venueName,
    this.client,
  });

  @override
  State<VenueApprovedCongratsScreen> createState() =>
      _VenueApprovedCongratsScreenState();
}

class _VenueApprovedCongratsScreenState
    extends State<VenueApprovedCongratsScreen> {
  bool _isLoading = false;

  String get _displayVenueReference {
    final ref = (widget.venueReference ?? '').trim();
    if (ref.isNotEmpty) {
      return ref.startsWith('#') ? ref.substring(1) : ref;
    }
    final id = widget.venueId.trim();
    if (id.isNotEmpty) {
      final clean = id.replaceAll('-', '');
      return clean.length >= 6
          ? clean.substring(0, 6).toUpperCase()
          : clean.toUpperCase();
    }
    return '123456';
  }

  Future<void> _onLetsBeginPressed() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final venueId = widget.venueId.trim();
      final displayRef = _displayVenueReference;
      if (venueId.isNotEmpty) {
        // Mark both ID-based and reference-based keys to ensure it is never shown again
        await SharedPreference.addStringToSF(
            "venue_approved_seen_$venueId", "true");
        if (displayRef.isNotEmpty) {
          await SharedPreference.addStringToSF(
              "venue_approved_seen_$displayRef", "true");
          await SharedPreference.addStringToSF(
              "venue_approved_seen_#$displayRef", "true");
        }
        await SharedPreference.addStringToSF(
            "venue_approved_welcome_seen", "true");
        await SharedPreference.addStringToSF("venue_id", venueId);
        if (widget.venueName != null && widget.venueName!.trim().isNotEmpty) {
          await SharedPreference.addStringToSF(
              "venue_name", widget.venueName!.trim());
        }

        final token = await SharedPreference.readStr("jwt_token");
        if (token != null && token.isNotEmpty) {
          try {
            await (widget.client?.patch ?? http.patch)(
              Uri.parse(MARK_WELCOME_SEEN_URL(venueId)),
              headers: {
                'accept': '*/*',
                'Authorization': 'Bearer $token',
              },
            );
          } catch (e) {
            CommonUtilities.showLog("Error marking welcome screen seen: $e");
          }
        }
      }
    } catch (e) {
      CommonUtilities.showLog("Error in VenueApprovedCongratsScreen: $e");
    } finally {
      VenueApprovalService.isShowingCongrats = false;
    }

    if (!mounted) return;
    CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
      context,
      HomeScreen(client: widget.client),
    );
  }

  @override
  void dispose() {
    VenueApprovalService.isShowingCongrats = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.yellowTop,
              AppColors.yellowBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Top Logo
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: isCompact ? 110 : 130,
                    height: isCompact ? 48 : 56,
                    fit: BoxFit.contain,
                    semanticLabel: 'ACTIV Partner Logo',
                  ),
                ),
                const Spacer(flex: 2),

                // Center Celebration Graphic
                Center(
                  child: Image.asset(
                    'assets/venue_approved_celebration.png',
                    width: isCompact ? 200 : 240,
                    fit: BoxFit.contain,
                    semanticLabel: 'Venue approved celebration illustration',
                  ),
                ),

                const SizedBox(height: 28),

                // Heading
                Text(
                  '🥳 Congratulations! Your\nvenue has been approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 20 : 24,
                    height: 1.25,
                    color: AppColors.darkBlack,
                  ),
                ),

                const SizedBox(height: 14),

                // Subtitle
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w500,
                      fontSize: isCompact ? 13 : 14,
                      height: 1.45,
                      color: const Color(0xFF555555),
                    ),
                    children: [
                      const TextSpan(text: 'Your venue '),
                      TextSpan(
                        text: '#$_displayVenueReference',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlack,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' is live \u2014 Let\'s do some checks\nand welcome your first members.',
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom Button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: media.padding.bottom > 0 ? 12 : 24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onLetsBeginPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.black,
                        disabledBackgroundColor:
                            AppColors.black.withValues(alpha: 0.7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.yellow,
                                ),
                              ),
                            )
                          : const Text(
                              'Let\'s Begin',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.yellow,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VenueApprovalService {
  static bool _isChecking = false;
  static bool isShowingCongrats = false;
  static Timer? _pollTimer;
  static http.Client? _activeClient;

  /// Checks MY_APPROVED_VENUES_URL for any approved venue that hasn't seen the welcome screen.
  static Future<Map<String, dynamic>?> checkUnseenApprovedVenue({
    String? token,
    http.Client? client,
  }) async {
    try {
      final jwt = token ?? await SharedPreference.readStr("jwt_token");
      if (jwt == null || jwt.trim().isEmpty) return null;

      final httpClient = client ?? _activeClient;
      final response = await (httpClient?.get ?? http.get)(
        Uri.parse(MY_APPROVED_VENUES_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer ${jwt.trim()}',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final list = (body['data'] is List) ? body['data'] as List : [];
        for (final item in list) {
          if (item is Map) {
            final venueMap = Map<String, dynamic>.from(item);
            final venueId = venueMap['id']?.toString() ?? '';
            final venueRef = venueMap['publicReference']?.toString() ??
                venueMap['venueReference']?.toString() ??
                '';
            final bool hasSeenBackend = venueMap['hasSeenWelcome'] == true;
            final seenById = venueId.isNotEmpty
                ? await SharedPreference.readStr('venue_approved_seen_$venueId')
                : null;
            final seenByRef = venueRef.isNotEmpty
                ? await SharedPreference.readStr('venue_approved_seen_$venueRef')
                : null;
            final seenByHashRef = venueRef.isNotEmpty
                ? await SharedPreference.readStr('venue_approved_seen_#$venueRef')
                : null;

            // If already marked seen on backend or locally, skip this venue completely
            if (hasSeenBackend ||
                seenById == 'true' ||
                seenByRef == 'true' ||
                seenByHashRef == 'true') {
              continue;
            }
            if (venueId.isNotEmpty) {
              return venueMap;
            }
          }
        }
      }
    } catch (e) {
      CommonUtilities.showLog('VenueApprovalService check error: $e');
    }
    return null;
  }

  /// Checks if there is an unseen approved venue and immediately shows the congrats screen.
  static Future<bool> checkAndShowCongrats({
    BuildContext? context,
    http.Client? client,
  }) async {
    if (_isChecking || isShowingCongrats) return false;
    _isChecking = true;
    try {
      final unseenVenue = await checkUnseenApprovedVenue(client: client);
      if (unseenVenue != null) {
        if (isShowingCongrats) return false;

        final venueId = unseenVenue['id']?.toString() ?? '';
        final venueRef = unseenVenue['publicReference']?.toString() ??
            unseenVenue['venueReference']?.toString() ??
            (venueId.length >= 6
                ? venueId.replaceAll('-', '').substring(0, 6).toUpperCase()
                : venueId);
        final venueName = unseenVenue['name']?.toString();

        await SharedPreference.addStringToSF("is_active", "true");
        if (venueId.isNotEmpty) {
          await SharedPreference.addStringToSF("venue_id", venueId);
        }
        if (venueName != null && venueName.isNotEmpty) {
          await SharedPreference.addStringToSF("venue_name", venueName);
        }

        isShowingCongrats = true;
        final target = VenueApprovedCongratsScreen(
          venueId: venueId,
          venueReference: venueRef,
          venueName: venueName,
          client: client ?? _activeClient,
        );

        if (context != null && context.mounted) {
          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
            context,
            target,
          );
          return true;
        }

        final navState = NavigationService.navigationKey.currentState;
        if (navState != null) {
          await navState.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => target),
            (_) => false,
          );
          return true;
        }
      }
    } catch (e) {
      CommonUtilities.showLog('VenueApprovalService show error: $e');
    } finally {
      _isChecking = false;
    }
    return false;
  }

  /// Starts polling every [interval] while the app is in foreground.
  static void startPolling({
    http.Client? client,
    Duration interval = const Duration(seconds: 3),
  }) {
    if (client != null) _activeClient = client;
    _pollTimer?.cancel();
    checkAndShowCongrats(client: client);
    _pollTimer = Timer.periodic(interval, (_) {
      checkAndShowCongrats(client: client);
    });
  }

  /// Stops polling.
  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resets checking and congratulation state (primarily for tests).
  static void resetState() {
    _isChecking = false;
    isShowingCongrats = false;
    stopPolling();
  }
}

/// Global widget that listens for app lifecycle changes and actively polls
/// for venue approval while the app is running.
class VenueApprovalWatcher extends StatefulWidget {
  final Widget? child;
  final http.Client? client;

  const VenueApprovalWatcher({super.key, this.child, this.client});

  @override
  State<VenueApprovalWatcher> createState() => _VenueApprovalWatcherState();
}

class _VenueApprovalWatcherState extends State<VenueApprovalWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startWatcher();
  }

  void _startWatcher() {
    _timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _check();
    });
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _check();
    });
  }

  Future<void> _check() async {
    final token = await SharedPreference.readStr("jwt_token");
    if (token != null && token.isNotEmpty) {
      await VenueApprovalService.checkAndShowCongrats(client: widget.client);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}
