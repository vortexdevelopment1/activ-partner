import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'ReviewSignAgreement.dart';

const _editColor = Color(0xFF7C3AED);

class ReviewVenueDetailsScreen extends StatefulWidget {
  const ReviewVenueDetailsScreen({super.key});

  @override
  State<ReviewVenueDetailsScreen> createState() => _State();
}

class _State extends State<ReviewVenueDetailsScreen> {
  int currentStep = 10;
  final int totalSteps = totalSetup;

  // Owner / partner
  String ownerFullName = '';
  String ownerEmail = '';
  String ownerMobileNumber = '';
  String contactNumber = '';

  // Venue
  String venueName = '';
  String venueDescription = '';
  String venueAddress = '';
  String venueCity = '';
  double? venueLat;
  double? venueLon;

  // Activities — list of {id, title, description?}
  List<Map<String, dynamic>> activities = [];

  // Amenities
  List<String> amenities = [];

  // Commission
  double commissionPct = 10;
  bool commissionLoading = true;

  bool isProfileComplete = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // ── Owner details ──────────────────────────────────────────────────────
    final ownerName =
        checkString(await SharedPreference.readStr('owner_full_name'));
    final ownerEmailStr =
        checkString(await SharedPreference.readStr('owner_email'));
    final ownerPhone =
        checkString(await SharedPreference.readStr('owner_mobile_number'));
    final sameChecked = checkString(
        await SharedPreference.readStr('same_as_owner_number_checked'));
    final sameNum =
        checkString(await SharedPreference.readStr('same_as_owner_number'));
    final contactNum = sameChecked == 'true' ? ownerPhone : sameNum;

    // ── Venue details ──────────────────────────────────────────────────────
    final venueDetailsStr =
        checkString(await SharedPreference.readStr('venue_details'));
    String vName = '', vDesc = '', vAddr = '', vCity = '';
    if (venueDetailsStr.isNotEmpty) {
      final v = jsonDecode(venueDetailsStr) as Map<String, dynamic>;
      vName = v['venue_name']?.toString() ?? '';
      vDesc = v['venue_description']?.toString() ?? '';
      vCity = v['venue_city']?.toString() ?? '';
      final latRaw = v['venue_latitude'];
      final lonRaw = v['venue_longitude'];
      if (latRaw != null) venueLat = (latRaw as num).toDouble();
      if (lonRaw != null) venueLon = (lonRaw as num).toDouble();
      vAddr = [
        v['venue_address'],
        v['venue_area'],
        v['venue_city'],
        v['venue_state'],
        v['venue_pin_code'],
      ]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .join(', ');
    }

    // ── Activity type ──────────────────────────────────────────────────────
    final operateStr =
        checkString(await SharedPreference.readStr('operate_value'));
    List<Map<String, dynamic>> activitiesList = [];
    if (operateStr.isNotEmpty) {
      final decoded = jsonDecode(operateStr);
      if (decoded is List) {
        activitiesList = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map) {
        // Old format: single {id, title}
        activitiesList = [decoded.cast<String, dynamic>()];
      }
    }

    // ── Amenities ──────────────────────────────────────────────────────────
    final placeOfferStr =
        checkString(await SharedPreference.readStr('place_offer'));
    List<String> amenitiesList = [];
    if (placeOfferStr.isNotEmpty) {
      final po = jsonDecode(placeOfferStr) as Map<String, dynamic>;
      final list = (po['place_offer'] as List<dynamic>?) ?? [];
      amenitiesList =
          list.map((e) => (e as Map)['title']?.toString() ?? '').toList();
    }

    final profileComplete =
        checkString(await SharedPreference.readStr('is_profile_complete')) == 'true';

    if (!mounted) return;
    setState(() {
      ownerFullName = ownerName;
      ownerEmail = ownerEmailStr;
      ownerMobileNumber = ownerPhone;
      contactNumber = contactNum;
      venueName = vName;
      venueDescription = vDesc;
      venueAddress = vAddr;
      venueCity = vCity;
      activities = activitiesList;
      amenities = amenitiesList;
      isProfileComplete = profileComplete;
    });

    // Fetch commission after city is known
    if (vCity.isNotEmpty) {
      _fetchCommission(vCity);
    } else {
      setState(() => commissionLoading = false);
    }
  }

  Future<void> _fetchCommission(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$COMMISSION_BY_CITY_URL/${Uri.encodeComponent(city)}'),
        headers: {'accept': '*/*'},
      );
      CommonUtilities.showLog('Commission status: ${response.statusCode}');
      CommonUtilities.showLog('Commission body: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final pct = (body['data']?['commissionPercentage'] as num?)?.toDouble() ?? 10;
        if (mounted) setState(() => commissionPct = pct);
      }
    } catch (e) {
      CommonUtilities.showLog('Commission fetch error: $e');
    } finally {
      if (mounted) setState(() => commissionLoading = false);
    }
  }

  // ─── Section card ─────────────────────────────────────────────────────────

  Widget _card({
    required String title,
    VoidCallback? onEdit,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppSize.size_16,
                    fontFamily: 'FontSemiBold',
                    color: AppColors.darkBlack,
                    height: 1,
                  ),
                ),
                if (onEdit != null)
                  InkWell(
                    onTap: onEdit,
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined, size: 15, color: _editColor),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: AppSize.size_13,
                            fontFamily: 'FontMedium',
                            color: _editColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.gray),
          content,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppSize.size_12,
              fontFamily: 'FontRegular',
              color: AppColors.hintColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.darkBlack,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Venue Partner Details ─────────────────────────────────────────────────

  Widget _buildPartnerDetails() {
    return _card(
      title: 'Venue Partner Details',
      onEdit: () {},
      content: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Full Name', ownerFullName),
            _detailRow('Email Address', ownerEmail),
            _detailRow('Phone Number',
                ownerMobileNumber.isNotEmpty ? '+91 $ownerMobileNumber' : '-'),
            const Divider(height: 12, color: AppColors.gray),
            const SizedBox(height: 8),
            const Text(
              "Venue's primary contact number",
              style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
            _detailRow('Phone Number',
                contactNumber.isNotEmpty ? '+91 $contactNumber' : '-'),
          ],
        ),
      ),
    );
  }

  // ─── Venue Details ────────────────────────────────────────────────────────

  Widget _buildVenueDetails() {
    return _card(
      title: 'Venue Details',
      onEdit: () {},
      content: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Venue Name', venueName),
            _detailRow('Description', venueDescription),
            _detailRow('Address', venueAddress),
            if (venueLat != null && venueLon != null) _buildVenueMap(),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueMap() {
    final position = LatLng(venueLat!, venueLon!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: position, zoom: 17),
          markers: {
            Marker(
              markerId: const MarkerId('venue'),
              position: position,
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }

  // ─── Commission Structure ─────────────────────────────────────────────────

  Widget _buildCommissionCard() {
    final city = venueCity.isNotEmpty ? venueCity : 'your city';
    final netAmount = (100 - commissionPct).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ACTIV's Commission Structure",
                  style: TextStyle(
                    fontSize: AppSize.size_16,
                    fontFamily: 'FontSemiBold',
                    color: AppColors.darkBlack,
                    height: 1,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'IMPORTANT',
                    style: TextStyle(
                      fontSize: AppSize.size_11,
                      fontFamily: 'FontSemiBold',
                      color: AppColors.red,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.gray),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: city — percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For your venue in $city',
                          style: const TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: 'FontMedium',
                            color: AppColors.darkBlack,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Standard rate',
                          style: TextStyle(
                            fontSize: AppSize.size_12,
                            fontFamily: 'FontRegular',
                            color: AppColors.hintColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        commissionLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                '${commissionPct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: AppSize.size_20,
                                  fontFamily: 'FontSemiBold',
                                  color: AppColors.darkBlack,
                                  height: 1,
                                ),
                              ),
                        const SizedBox(height: 3),
                        const Text(
                          'Per booking',
                          style: TextStyle(
                            fontSize: AppSize.size_12,
                            fontFamily: 'FontRegular',
                            color: AppColors.hintColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.gray),
                const SizedBox(height: 12),

                // Row: earnings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your earnings',
                          style: const TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: 'FontMedium',
                            color: AppColors.darkBlack,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Example: For every ₹100 booking',
                          style: TextStyle(
                            fontSize: AppSize.size_12,
                            fontFamily: 'FontRegular',
                            color: AppColors.hintColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        commissionLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                '₹$netAmount',
                                style: const TextStyle(
                                  fontSize: AppSize.size_20,
                                  fontFamily: 'FontSemiBold',
                                  color: AppColors.darkBlack,
                                  height: 1,
                                ),
                              ),
                        const SizedBox(height: 3),
                        const Text(
                          'Net amount',
                          style: TextStyle(
                            fontSize: AppSize.size_12,
                            fontFamily: 'FontRegular',
                            color: AppColors.hintColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _editColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _editColor.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'Note: Commission rates vary by city to ensure pricing and operational coverage across India.',
                    style: TextStyle(
                      fontSize: AppSize.size_12,
                      fontFamily: 'FontRegular',
                      color: AppColors.darkBlack,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Amenities ────────────────────────────────────────────────────────────

  Widget _buildAmenities() {
    return _card(
      title: 'Amenities',
      onEdit: () {},
      content: amenities.isEmpty
          ? const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Text(
                'No amenities selected.',
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.hintColor,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: amenities.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gray, width: 1),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: AppSize.size_13,
                        fontFamily: 'FontMedium',
                        color: AppColors.darkBlack,
                        height: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ─── Activities ───────────────────────────────────────────────────────────

  // Maps lowercase activity keywords → Material icon
  static const Map<String, IconData> _activityIcons = {
    'badminton': Icons.sports_tennis,
    'tennis': Icons.sports_tennis,
    'cricket': Icons.sports_cricket,
    'football': Icons.sports_soccer,
    'soccer': Icons.sports_soccer,
    'basketball': Icons.sports_basketball,
    'swimming': Icons.pool,
    'gym': Icons.fitness_center,
    'yoga': Icons.self_improvement,
    'squash': Icons.sports_tennis,
    'table tennis': Icons.sports_tennis,
    'cycling': Icons.directions_bike,
    'boxing': Icons.sports_kabaddi,
    'volleyball': Icons.sports_volleyball,
    'hockey': Icons.sports_hockey,
    'golf': Icons.golf_course,
  };

  IconData _iconForActivity(String title) {
    final lower = title.toLowerCase();
    for (final entry in _activityIcons.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.sports;
  }

  Widget _buildActivities() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'Activities',
              style: TextStyle(
                fontSize: AppSize.size_16,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
                height: 1,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.gray),

          // Subtitle
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              "You can always add more activities or update activity details later, once venue is approved.",
              style: TextStyle(
                fontSize: AppSize.size_13,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
                height: 1.4,
              ),
            ),
          ),

          // One card per activity
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Text(
                'No activities selected.',
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.hintColor,
                ),
              ),
            )
          else
            ...activities.asMap().entries.map((entry) {
              final i = entry.key;
              final act = entry.value;
              final title = act['title']?.toString() ?? '';
              final description = act['description']?.toString() ?? '';
              final isLast = i == activities.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, isLast ? 14 : 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gray, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Icon in yellow circle
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.yellowTop,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _iconForActivity(title),
                              size: 24,
                              color: AppColors.darkBlack,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title + description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: AppSize.size_14,
                                    fontFamily: 'FontSemiBold',
                                    color: AppColors.darkBlack,
                                    height: 1.2,
                                  ),
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: AppSize.size_12,
                                      fontFamily: 'FontRegular',
                                      color: AppColors.hintColor,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Edit button
                          InkWell(
                            onTap: () {},
                            child: Row(
                              children: const [
                                Icon(Icons.edit_outlined,
                                    size: 15, color: _editColor),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: AppSize.size_13,
                                    fontFamily: 'FontMedium',
                                    color: _editColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1,
                        color: AppColors.gray,
                        indent: 14,
                        endIndent: 14),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    double progress = currentStep / totalSteps;

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(height: 100, color: AppColors.yellowTop),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(height: 100, color: AppColors.white),
        ),
        SafeArea(
          top: true,
          bottom: true,
          left: false,
          right: false,
          child: Scaffold(
            body: Container(
              decoration: context.getYellowGradient,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          child: SvgPicture.asset('assets/activ_tm.svg'),
                        ),
                        getStepBarCount(progress, currentStep, totalSteps),
                        Container(
                          margin: const EdgeInsets.only(top: 25),
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Review Venue Details',
                            style: TextStyle(
                              fontSize: AppSize.size_25,
                              fontFamily: 'FontSemiBold',
                              color: AppColors.darkBlack,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                          child: const Text(
                            "Review your venue's details for a final confirmation",
                            style: TextStyle(
                              fontSize: AppSize.size_16,
                              fontFamily: 'FontRegular',
                              color: AppColors.black1,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (!isProfileComplete) _buildPartnerDetails(),
                        _buildVenueDetails(),
                        _buildCommissionCard(),
                        _buildAmenities(),
                        _buildActivities(),
                      ],
                    ),
                  ),

                  // Bottom bar
                  Column(
                    children: [
                      bottomBarShadow(),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              child: getBackButton(
                                  context, 'Back', 'reviewVenueDetails'),
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: InkWell(
                              onTap: () => CommonUtilities.NavigateWithPush(
                                  context, const ReviewSignAgreement()),
                              child: getButtonBlack(
                                  context, 'Confirm', 'reviewVenueDetails'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
