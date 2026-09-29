import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';
import '../StringExtensions.dart';

class VenueInfoScreen extends StatefulWidget {
  const VenueInfoScreen({super.key});

  @override
  State<VenueInfoScreen> createState() => _VenueInfoScreenState();
}

class _VenueInfoScreenState extends State<VenueInfoScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _venue = {};

  @override
  void initState() {
    super.initState();
    _loadVenue();
  }

  Future<void> _loadVenue() async {
    final token = checkString(await SharedPreference.readStr("jwt_token"));

    try {
      final response = await http.get(
        Uri.parse(MY_APPROVED_VENUES_URL),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      CommonUtilities.showLog("VenueInfoScreen status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final List data = body['data'] is List ? body['data'] : [];
        if (data.isNotEmpty) {
          _venue = Map<String, dynamic>.from(data.first);
        }
      } else {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Failed to load venue details.');
      }
    } catch (e) {
      CommonUtilities.showLog("VenueInfoScreen error: $e");
      if (!mounted) return;
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
                  _buildToolbar(context),
                  _isLoading
                      ? const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.black,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _venue.isEmpty
                          ? const Expanded(
                              child: Center(
                                child: Text(
                                  'No venue data found.',
                                  style: TextStyle(
                                    fontSize: AppSize.size_14,
                                    fontFamily: 'FontMedium',
                                    color: AppColors.black1,
                                  ),
                                ),
                              ),
                            )
                          : Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(15, 5, 15, 30),
                                children: [
                                  _buildBasicInfo(),
                                  _buildLocationInfo(),
                                  _buildCategories(),
                                  _buildAmenities(),
                                  _buildAvailability(),
                                  _buildServices(),
                                ],
                              ),
                            ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── TOOLBAR ──────────────────────────────────────────────────────────────────

  Widget _buildToolbar(BuildContext context) {
    return SizedBox(
      height: AppSize.toolTabSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                child: SvgPicture.asset('assets/ic_back.svg'),
              ),
            ),
          ),
          getTitleText(context, 'Venue Details', 'Venue_Details'),
        ],
      ),
    );
  }

  // ── SECTION HEADER ───────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'FontSemiBold',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  // ── FIELD ROW ────────────────────────────────────────────────────────────────

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppSize.size_12,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gray2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
          ),
        ),
      ],
    );
  }

  // ── BASIC INFO ───────────────────────────────────────────────────────────────

  Widget _buildBasicInfo() {
    final status = (_venue['status']?.toString() ?? '').toUpperCase();
    final bookingAccept = _venue['bookingAccept'] == true;
    final commission = _venue['commission']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Basic Information'),
        _field('Venue Name', _venue['name']?.toString() ?? ''),
        _field('Description', _venue['description']?.toString() ?? ''),
        _field('Commission', commission.isNotEmpty ? '$commission%' : '—'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _statusChip('Status', status,
                  status == 'APPROVED' ? const Color(0xFF1A8C3E) : AppColors.black1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statusChip(
                'Bookings',
                bookingAccept ? 'ACCEPTING' : 'PAUSED',
                bookingAccept ? const Color(0xFF1A8C3E) : const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppSize.size_12,
            fontFamily: 'FontMedium',
            color: AppColors.black1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: AppSize.size_13,
              fontFamily: 'FontSemiBold',
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ── LOCATION INFO ─────────────────────────────────────────────────────────────

  Widget _buildLocationInfo() {
    final locationUrl = _venue['locationUrl']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Location'),
        _field('Flat / Building', _venue['flatBuilding']?.toString() ?? ''),
        _field('Address', _venue['address']?.toString() ?? ''),
        _field('City', _venue['city']?.toString() ?? ''),
        _field('State', _venue['state']?.toString() ?? ''),
        _field('Country', _venue['country']?.toString() ?? ''),
        _field('Zip Code', _venue['zipCode']?.toString() ?? ''),
        _field('Venue Phone', _venue['venuePhone']?.toString() ?? ''),
        if (locationUrl.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: 14),
            child: const Text(
              'Location URL',
              style: TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uri = Uri.tryParse(locationUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                locationUrl,
                style: const TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.purple,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.purple,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── CATEGORIES ───────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    final categories = _venue['categories'];
    if (categories is! List || categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Categories'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map<Widget>((cat) {
            final name = cat['name']?.toString() ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gray2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gray),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: AppSize.size_13,
                  fontFamily: 'FontMedium',
                  color: AppColors.darkBlack,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── AMENITIES ────────────────────────────────────────────────────────────────

  Widget _buildAmenities() {
    final amenities = _venue['amenities'];
    if (amenities is! List || amenities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Amenities'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amenities.map<Widget>((item) {
            final name = item.toString();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gray2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gray),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: AppSize.size_13,
                  fontFamily: 'FontMedium',
                  color: AppColors.darkBlack,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── AVAILABILITY ─────────────────────────────────────────────────────────────

  Widget _buildAvailability() {
    final availability = _venue['availability'];
    if (availability is! Map || availability.isEmpty) return const SizedBox.shrink();

    final categories = _venue['categories'];
    // Build categoryId → name map
    final Map<String, String> catNames = {};
    if (categories is List) {
      for (final cat in categories) {
        final id = cat['id']?.toString() ?? '';
        final name = cat['name']?.toString() ?? id;
        if (id.isNotEmpty) catNames[id] = name;
      }
    }

    final widgets = <Widget>[];
    widgets.add(_sectionHeader('Availability'));

    availability.forEach((catId, dayList) {
      final catName = catNames[catId] ?? catId;
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                catName,
                style: const TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontSemiBold',
                  color: AppColors.darkBlack,
                ),
              ),
              const SizedBox(height: 8),
              if (dayList is List)
                ...dayList.map<Widget>((dayEntry) {
                  final day = _capitalize(dayEntry['day']?.toString() ?? '');
                  final slots = dayEntry['slots'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: AppSize.size_13,
                            fontFamily: 'FontSemiBold',
                            color: AppColors.black1,
                          ),
                        ),
                        if (slots is List)
                          ...slots.map<Widget>((slot) {
                            final open = slot['openTime']?.toString() ?? '-';
                            final close = slot['closeTime']?.toString() ?? '-';
                            final capacity = slot['capacity']?.toString() ?? '-';
                            final price = slot['price']?.toString() ?? '-';
                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.gray2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$open – $close',
                                      style: const TextStyle(
                                        fontSize: AppSize.size_13,
                                        fontFamily: 'FontRegular',
                                        color: AppColors.darkBlack,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Cap: $capacity  •  ₹$price',
                                    style: const TextStyle(
                                      fontSize: AppSize.size_12,
                                      fontFamily: 'FontMedium',
                                      color: AppColors.black1,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // ── SERVICES ─────────────────────────────────────────────────────────────────

  Widget _buildServices() {
    final services = _venue['services'];
    if (services is! List || services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Services'),
        ...services.map<Widget>((service) {
          final name = service['name']?.toString() ?? '';
          final imageUrls = service['imageUrls'];
          final List<String> urls = imageUrls is List
              ? imageUrls.map((e) => e.toString()).toList()
              : [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: AppSize.size_14,
                    fontFamily: 'FontSemiBold',
                    color: AppColors.darkBlack,
                  ),
                ),
                if (urls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      itemBuilder: (context, i) {
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.gray2,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: urls[i],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.black,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.gray,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
