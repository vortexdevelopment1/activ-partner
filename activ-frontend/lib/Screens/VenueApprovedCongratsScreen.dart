import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

                // Center Celebration Graphic with 3D Orbiting Emojis
                Center(
                  child: _AnimatedCelebrationGraphic(isCompact: isCompact),
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

/// Renders the 3D center celebration certificate with 8 orbiting sport activity emojis
/// continuously rotating clockwise around it with 3D depth, realistic shadows, and scale perspective.
class _AnimatedCelebrationGraphic extends StatefulWidget {
  final bool isCompact;

  const _AnimatedCelebrationGraphic({required this.isCompact});

  @override
  State<_AnimatedCelebrationGraphic> createState() =>
      _AnimatedCelebrationGraphicState();
}

class _AnimatedCelebrationGraphicState
    extends State<_AnimatedCelebrationGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 8 activity emoji assets in clockwise order starting from 12 o'clock (top):
  // 1. Tennis (top / 12:00)
  // 2. Badminton (top-right / 1:30)
  // 3. Gym (right / 3:00)
  // 4. Basketball (bottom-right / 4:30)
  // 5. Martial Arts (bottom / 6:00)
  // 6. Cricket (bottom-left / 7:30)
  // 7. Football (left / 9:00)
  // 8. Yoga (top-left / 10:30)
  static const List<String> _activityAssets = [
    'assets/activities/tennis.png',
    'assets/activities/badminton.png',
    'assets/activities/gym.png',
    'assets/activities/basketball.png',
    'assets/activities/martial-arts.png',
    'assets/activities/cricket.png',
    'assets/activities/football.png',
    'assets/activities/yoga.png',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.isCompact;
    final double areaWidth = isCompact ? 240 : 270;
    final double areaHeight = isCompact ? 210 : 240;

    final double cardWidth = isCompact ? 122 : 140;
    final double cardHeight = isCompact ? 84 : 96;

    final double radiusX = isCompact ? 96 : 108;
    final double radiusY = isCompact ? 78 : 88;

    final double emojiBaseSize = isCompact ? 32 : 36;
    final double centerX = areaWidth / 2;
    final double centerY = areaHeight / 2;

    return SizedBox(
      width: areaWidth,
      height: areaHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Compute positions, depth, and scales for all 8 emojis
          final emojiWidgets = <_OrbitItem>[];

          for (int i = 0; i < _activityAssets.length; i++) {
            // Clockwise rotation starting from top (-pi / 2)
            final double baseAngle =
                -math.pi / 2 + (i * 2 * math.pi / _activityAssets.length);
            final double angle =
                baseAngle + (_controller.value * 2 * math.pi);

            final double x = centerX + radiusX * math.cos(angle);
            final double y = centerY + radiusY * math.sin(angle);

            // 3D Depth effect: objects in foreground (sin(angle) > 0, bottom) are larger with longer shadows;
            // objects in background (sin(angle) < 0, top) are slightly smaller.
            final double depthNorm =
                (math.sin(angle) + 1.0) / 2.0; // 0.0 at top (back), 1.0 at bottom (front)
            final double scale = 0.90 + (0.22 * depthNorm);
            final double shadowBlur = 4.0 + (5.0 * depthNorm);
            final double shadowY = 2.0 + (3.5 * depthNorm);
            final double shadowAlpha = 0.16 + (0.12 * depthNorm);
            final double tilt =
                math.sin(angle * 2) * 0.06; // subtle organic floating tilt

            emojiWidgets.add(_OrbitItem(
              zIndex: depthNorm,
              widget: Positioned(
                left: x - (emojiBaseSize / 2),
                top: y - (emojiBaseSize / 2),
                child: Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: emojiBaseSize,
                      height: emojiBaseSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: shadowAlpha),
                            blurRadius: shadowBlur,
                            offset: Offset(0, shadowY),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        _activityAssets[i],
                        width: emojiBaseSize,
                        height: emojiBaseSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ));
          }

          // Separate background emojis (back half, depthNorm < 0.5) and foreground emojis (depthNorm >= 0.5)
          // so the center certificate card sits naturally in the 3D space between them
          final backEmojis = emojiWidgets
              .where((e) => e.zIndex < 0.5)
              .map((e) => e.widget)
              .toList();
          final frontEmojis = emojiWidgets
              .where((e) => e.zIndex >= 0.5)
              .map((e) => e.widget)
              .toList();

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ...backEmojis,
              // Center Certificate Card
              _CertificateCard(
                width: cardWidth,
                height: cardHeight,
                isCompact: isCompact,
              ),
              ...frontEmojis,
            ],
          );
        },
      ),
    );
  }
}

class _OrbitItem {
  final double zIndex;
  final Widget widget;

  _OrbitItem({required this.zIndex, required this.widget});
}

class _CertificateCard extends StatelessWidget {
  final double width;
  final double height;
  final bool isCompact;

  const _CertificateCard({
    required this.width,
    required this.height,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ScallopedCertificatePainter(isCompact: isCompact),
      ),
    );
  }
}

class _ScallopedCertificatePainter extends CustomPainter {
  final bool isCompact;

  _ScallopedCertificatePainter({required this.isCompact});

  @override
  void paint(Canvas canvas, Size size) {
    final double r = isCompact ? 5.0 : 6.0;

    final int countX = (size.width / (2 * r)).round();
    final double stepX = size.width / countX;
    final int countY = (size.height / (2 * r)).round();
    final double stepY = size.height / countY;

    // 1. Scalloped Outer Frame Path
    final path = Path();
    path.moveTo(0, 0);

    // Top edge (left to right)
    for (int i = 0; i < countX; i++) {
      final double x1 = i * stepX;
      final double x2 = (i + 1) * stepX;
      final double xm = (x1 + x2) / 2;
      path.quadraticBezierTo(xm, -r * 0.9, x2, 0);
    }
    // Right edge (top to bottom)
    for (int i = 0; i < countY; i++) {
      final double y1 = i * stepY;
      final double y2 = (i + 1) * stepY;
      final double ym = (y1 + y2) / 2;
      path.quadraticBezierTo(size.width + r * 0.9, ym, size.width, y2);
    }
    // Bottom edge (right to left)
    for (int i = 0; i < countX; i++) {
      final double x1 = size.width - (i * stepX);
      final double x2 = size.width - ((i + 1) * stepX);
      final double xm = (x1 + x2) / 2;
      path.quadraticBezierTo(xm, size.height + r * 0.9, x2, size.height);
    }
    // Left edge (bottom to top)
    for (int i = 0; i < countY; i++) {
      final double y1 = size.height - (i * stepY);
      final double y2 = size.height - ((i + 1) * stepY);
      final double ym = (y1 + y2) / 2;
      path.quadraticBezierTo(-r * 0.9, ym, 0, y2);
    }
    path.close();

    // Frame shadow
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.18),
      12.0,
      false,
    );

    // Frame Gold Gradient Fill
    final goldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFD568),
          Color(0xFFF5B738),
          Color(0xFFDC921E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, goldPaint);

    // 2. Inner Parchment Paper
    final double inset = isCompact ? 7.0 : 8.5;
    final innerRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );
    final innerRRect =
        RRect.fromRectAndRadius(innerRect, const Radius.circular(6));

    final paperPaint = Paint()..color = const Color(0xFFFFFDF8);
    canvas.drawRRect(innerRRect, paperPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFF3E2C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(innerRRect, borderPaint);

    // 3. Golden 5-point Star (Top Center)
    final double starY = innerRect.top + (isCompact ? 12 : 14);
    final double starX = size.width / 2;
    final double outerR = isCompact ? 6.5 : 8.0;
    final double innerR = outerR * 0.42;

    final starPath = Path();
    for (int i = 0; i < 10; i++) {
      final double rad = -math.pi / 2 + (i * math.pi / 5);
      final double radius = (i % 2 == 0) ? outerR : innerR;
      final double sx = starX + radius * math.cos(rad);
      final double sy = starY + radius * math.sin(rad);
      if (i == 0) {
        starPath.moveTo(sx, sy);
      } else {
        starPath.lineTo(sx, sy);
      }
    }
    starPath.close();

    final starPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFCA3A), Color(0xFFE8981A)],
      ).createShader(
          Rect.fromCircle(center: Offset(starX, starY), radius: outerR));
    canvas.drawShadow(starPath, const Color(0x33000000), 2.0, false);
    canvas.drawPath(starPath, starPaint);

    // 4. Four Amber Rounded Lines
    final double startY = starY + outerR + (isCompact ? 7 : 9);
    final double lineHeight = isCompact ? 3.0 : 3.5;
    final double lineSpacing = isCompact ? 4.0 : 4.5;
    final double maxLineWidth = innerRect.width * 0.68;

    final lineWidths = [
      maxLineWidth * 0.60,
      maxLineWidth * 0.95,
      maxLineWidth * 0.95,
      maxLineWidth * 0.50,
    ];

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF3A738), Color(0xFFE58B1C)],
      ).createShader(innerRect);

    for (int i = 0; i < lineWidths.length; i++) {
      final double y = startY + i * (lineHeight + lineSpacing);
      final double w = lineWidths[i];
      final lineRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(starX, y), width: w, height: lineHeight),
        Radius.circular(lineHeight / 2),
      );
      canvas.drawRRect(lineRRect, linePaint);
    }

    // 5. Rosette Ribbon Award Medal (Bottom Right Corner)
    final double medalX = size.width - inset - (isCompact ? 4 : 6);
    final double medalY = size.height - inset - (isCompact ? 2 : 4);

    final ribbonPaint = Paint()..color = const Color(0xFF262626);
    final double ribbonW = isCompact ? 5.5 : 7.0;
    final double ribbonL = isCompact ? 14.0 : 18.0;

    // Left ribbon (angled slightly left)
    final leftRibbon = Path()
      ..moveTo(medalX - 3, medalY + 2)
      ..lineTo(medalX - 9, medalY + ribbonL)
      ..lineTo(medalX - 9 + (ribbonW / 2), medalY + ribbonL - 3)
      ..lineTo(medalX - 9 + ribbonW, medalY + ribbonL)
      ..lineTo(medalX + 1, medalY + 2)
      ..close();
    canvas.drawPath(leftRibbon, ribbonPaint);

    // Right ribbon (angled slightly right)
    final rightRibbon = Path()
      ..moveTo(medalX - 1, medalY + 2)
      ..lineTo(medalX + 3, medalY + ribbonL)
      ..lineTo(medalX + 3 + (ribbonW / 2), medalY + ribbonL - 3)
      ..lineTo(medalX + 3 + ribbonW, medalY + ribbonL)
      ..lineTo(medalX + 4, medalY + 2)
      ..close();
    canvas.drawPath(rightRibbon, ribbonPaint);

    // Rosette circular seal (16-point scalloped star badge)
    final double rosetteR = isCompact ? 10.5 : 13.0;
    final double rosetteInnerR = rosetteR * 0.88;
    final rosettePath = Path();
    for (int i = 0; i < 32; i++) {
      final double rad = i * math.pi / 16;
      final double r = (i % 2 == 0) ? rosetteR : rosetteInnerR;
      final double rx = medalX + r * math.cos(rad);
      final double ry = medalY + r * math.sin(rad);
      if (i == 0) {
        rosettePath.moveTo(rx, ry);
      } else {
        rosettePath.lineTo(rx, ry);
      }
    }
    rosettePath.close();

    canvas.drawShadow(
        rosettePath, Colors.black.withValues(alpha: 0.25), 3.0, false);

    final rosettePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFDF68), Color(0xFFEAA120)],
      ).createShader(
          Rect.fromCircle(center: Offset(medalX, medalY), radius: rosetteR));
    canvas.drawPath(rosettePath, rosettePaint);

    // Rosette Inner Rings
    final ringPaint = Paint()
      ..color = const Color(0xFFCA8210)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(medalX, medalY), rosetteR * 0.65, ringPaint);

    final centerDotPaint = Paint()..color = const Color(0xFFFFD568);
    canvas.drawCircle(Offset(medalX, medalY), rosetteR * 0.40, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _ScallopedCertificatePainter oldDelegate) =>
      oldDelegate.isCompact != isCompact;
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
