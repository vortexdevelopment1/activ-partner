import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      if (venueId.isNotEmpty) {
        await SharedPreference.addStringToSF(
            "venue_approved_seen_$venueId", "true");
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
    }

    if (!mounted) return;
    CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
      context,
      HomeScreen(client: widget.client),
    );
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
