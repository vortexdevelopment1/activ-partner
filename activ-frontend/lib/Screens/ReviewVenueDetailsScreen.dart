import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Utills/activity_question_visibility.dart';
import '../Style/activity_logos.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'CustomerPlacesOffer.dart';
import 'ListActivityTypeScreen.dart';
import 'ReviewSignAgreement.dart';
import 'TellUsAboutScreen.dart';
import 'VenueScreen.dart';
import 'onboarding_widgets.dart';

const _editColor = Color(0xFFA634FF);

class ReviewVenueDetailsScreen extends StatefulWidget {
  const ReviewVenueDetailsScreen({super.key, this.client, this.mapBuilder});
  final http.Client? client;
  final Widget Function(LatLng position)? mapBuilder;

  @override
  State<ReviewVenueDetailsScreen> createState() => _State();
}

class _State extends State<ReviewVenueDetailsScreen> {
  String ownerFullName = '', ownerEmail = '', ownerMobileNumber = '';
  String contactNumber = '', phoneCode = '+91';
  Map<String, dynamic> venue = {};
  List<Map<String, dynamic>> activities = [],
      questions = [],
      categoryTimings = [];
  List<String> amenities = [];
  double? commissionPct;
  bool commissionLoading = true, loading = true, saving = false;
  bool pendingVenueUpdate = false;
  String? loadError, commissionError;
  int _loadVersion = 0;

  String get city => venue['venue_city']?.toString() ?? '';
  String get commissionLabel => commissionPct == null
      ? '-'
      : '${commissionPct!.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}%';

  dynamic _decode(String? raw, dynamic fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return fallback;
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : raw is Map
          ? [Map<String, dynamic>.from(raw)]
          : [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final version = ++_loadVersion;
    try {
      final values = await Future.wait([
        for (final key in [
          'owner_full_name',
          'owner_email',
          'owner_mobile_number',
          'phoneCode',
          'userMobileNumber',
          'same_as_owner_number_checked',
          'same_as_owner_number',
          'venue_details',
          'operate_value',
          'place_offer',
          'venue_commission',
          'activity_questions_display',
          'activity_review_timings',
        ])
          SharedPreference.readStr(key),
      ]);
      if (!mounted || version != _loadVersion) return;
      final decodedVenue = _decode(values[7], {});
      final offers = _decode(values[9], {});
      final cachedCommission = double.tryParse(values[10] ?? '');
      setState(() {
        ownerFullName = values[0] ?? '';
        ownerEmail = values[1] ?? '';
        ownerMobileNumber =
            (values[2]?.isNotEmpty ?? false) ? values[2]! : values[4] ?? '';
        phoneCode = (values[3]?.isNotEmpty ?? false) ? values[3]! : '+91';
        contactNumber = values[5] == 'true' || values[6] == 'true'
            ? ownerMobileNumber
            : values[6] ?? '';
        venue =
            decodedVenue is Map ? Map<String, dynamic>.from(decodedVenue) : {};
        activities = _maps(_decode(values[8], []));
        amenities = _maps(offers is Map ? offers['place_offer'] : [])
            .map((e) => e['title']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        questions = _maps(_decode(values[11], []))
            .where((q) => !isPlaceholderActivityQuestion(q['questionText'])).toList();
        categoryTimings = _maps(_decode(values[12], []));
        commissionPct = cachedCommission != null &&
                cachedCommission >= 0 &&
                cachedCommission <= 100
            ? cachedCommission
            : null;
        loading = false;
        loadError = null;
      });
      await _fetchCommission(version);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'Could not load your saved details.';
        });
      }
    }
  }

  Future<void> _fetchCommission(int version) async {
    if (city.isEmpty) {
      setState(() {
        commissionLoading = false;
        commissionError = null;
      });
      return;
    }
    final requestCity = city;
    setState(() {
      commissionLoading = true;
      commissionError = null;
    });
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(
            '$COMMISSION_BY_CITY_URL/${Uri.encodeComponent(requestCity)}')
            .replace(queryParameters: {'state': venue['venue_state']?.toString() ?? ''}),
        headers: {'accept': '*/*'},
      );
      if (!mounted || version != _loadVersion) return;
      final body = _decode(response.body, {});
      final pct = body is Map && body['data'] is Map
          ? double.tryParse(
              body['data']['commissionPercentage']?.toString() ?? '')
          : null;
      if (response.statusCode != 200 || pct == null || pct < 0 || pct > 100) {
        throw const FormatException('Invalid commission response');
      }
      setState(() => commissionPct = pct);
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => commissionError = 'Unable to refresh the rate.');
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => commissionLoading = false);
      }
    }
  }

  String _phone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    if (trimmed.startsWith('+')) return trimmed;
    final country = phoneCode.trim();
    final prefix = RegExp(r'[A-Za-z]').hasMatch(country)
        ? country.replaceFirst(RegExp(r'^\+'), '')
        : country.startsWith('+') ? country : '+$country';
    return '$prefix $trimmed';
  }

  Future<void> _editSection(Widget screen) async {
    if (saving) return;
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _loadData();
    if (!mounted || result != true) return;
    setState(() => pendingVenueUpdate = true);
    await _saveVenueChanges();
  }

  Future<bool> _saveVenueChanges() async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      final id = await SharedPreference.readStr('venue_id') ?? '';
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      if (id.isEmpty || token.isEmpty) {
        throw const FormatException('Missing session');
      }
      final response = await (widget.client?.patch ?? http.patch)(
        Uri.parse('$CREATE_VENUE_URL/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'name': venue['venue_name'] ?? '',
          'description': venue['venue_description'] ?? '',
          'address': (venue['venue_search_address'] ?? '').toString().trim().isNotEmpty
              ? venue['venue_search_address']
              : venue['venue_address'] ?? '',
          'flatBuilding': [
            if ((venue['venue_search_address'] ?? '').toString().trim().isNotEmpty)
              venue['venue_address'],
            venue['venue_area'],
          ].where((value) => value != null && value.toString().trim().isNotEmpty)
              .map((value) => value.toString().trim()).join(', '),
          'city': venue['venue_city'] ?? '',
          'state': venue['venue_state'] ?? '',
          'zipCode': venue['venue_pin_code'] ?? '',
          'locationUrl': venue['venue_location_url'] ?? '',
          'latitude':
              double.tryParse(venue['venue_latitude']?.toString() ?? ''),
          'longitude':
              double.tryParse(venue['venue_longitude']?.toString() ?? ''),
          'phone': ownerMobileNumber.replaceAll(RegExp(r'\D'), ''),
          'venuePhone': contactNumber.replaceAll(RegExp(r'\D'), ''),
          'amenities': amenities,
          if (commissionPct != null) 'commission': commissionPct,
        }),
      );
      if (!mounted) return false;
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const FormatException('Update failed');
      }
      setState(() => pendingVenueUpdate = false);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not save venue changes. Tap Confirm to retry.')));
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _confirm() async {
    if (saving) return;
    if (pendingVenueUpdate && !await _saveVenueChanges()) return;
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => ReviewSignAgreement(client: widget.client)));
  }

  Future<void> _editActivity() async {
    if (saving) return;
    final id = await SharedPreference.readStr('venue_id') ?? '';
    if (!mounted) return;
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please save your venue first.')));
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute<bool>(
            builder: (_) => ListActivityTypeScreen(
                  reviewMode: true,
                  client: widget.client,
                )));
    if (mounted) await _loadData();
  }

  Widget _editButton(VoidCallback onPressed) => TextButton.icon(
      onPressed: saving ? null : onPressed,
      style: TextButton.styleFrom(
          foregroundColor: _editColor,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle:
              const TextStyle(fontFamily: 'Satoshi', fontSize: 14)),
      icon: const Icon(Icons.edit_outlined, size: 17),
      label: const Text('Edit'));

  Widget _section(String title, Widget content,
          {VoidCallback? onEdit, Widget? trailing}) =>
      Container(
        margin: const EdgeInsets.only(top: 24),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.gray),
            borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.4))),
              if (onEdit != null) _editButton(onEdit),
              if (trailing != null) const SizedBox(width: 12),
              if (trailing != null) trailing,
            ]),
          ),
          const Divider(height: 1, color: AppColors.gray),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: content,
          ),
        ]),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.hintColor)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value,
              style: const TextStyle(
                  fontSize: 14, fontFamily: 'Satoshi', height: 1.45)),
        ]),
      );

  Widget _partnerDetails() => _section(
        'Venue Partner Details',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detail('Full Name', ownerFullName),
          _detail('Email Address', ownerEmail),
          _detail('Phone Number', _phone(ownerMobileNumber)),
          const Divider(height: 12, color: AppColors.gray),
          const SizedBox(height: 14),
          const Text("Venue's primary contact number",
              style: TextStyle(
                  fontFamily: 'Satoshi', fontSize: 16, height: 1.4)),
          const SizedBox(height: 14),
          _detail('Phone Number', _phone(contactNumber)),
        ]),
        onEdit: () => _editSection(const TellUsAboutScreen(reviewMode: true)),
      );

  Widget _venueDetails() {
    final address = [
      if ((venue['venue_search_address'] ?? '').toString().trim().isNotEmpty)
        'venue_search_address',
      'venue_address',
      'venue_area',
      if ((venue['venue_search_address'] ?? '').toString().trim().isEmpty) ...[
        'venue_city',
        'venue_state',
        'venue_pin_code'
      ]
    ]
        .map((key) => venue[key]?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .join(', ');
    final lat = double.tryParse(venue['venue_latitude']?.toString() ?? '');
    final lon = double.tryParse(venue['venue_longitude']?.toString() ?? '');
    final position = lat != null &&
            lon != null &&
            lat >= -90 &&
            lat <= 90 &&
            lon >= -180 &&
            lon <= 180
        ? LatLng(lat, lon)
        : null;
    return _section(
        'Venue Details',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detail('Venue Name', venue['venue_name']?.toString() ?? ''),
          _detail('Description', venue['venue_description']?.toString() ?? ''),
          _detail('Address', address),
          if (position != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: widget.mapBuilder?.call(position) ??
                        GoogleMap(
                          initialCameraPosition:
                              CameraPosition(target: position, zoom: 17),
                          markers: {
                            Marker(
                                markerId: const MarkerId('venue'),
                                position: position)
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
                        ))),
        ]),
        onEdit: () => _editSection(const VenueScreen(reviewMode: true)));
  }

  Widget _commissionRow(
          String title, String subtitle, String value, String valueLabel) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontFamily: 'Satoshi', height: 1.4)),
          const SizedBox(height: 4),
          Text(subtitle.replaceAll('\u20b9', 'INR '),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.hintColor, height: 1.4)),
        ])),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          commissionLoading
              ? const AppSkeleton(width: 42, height: 18, radius: 4)
              : Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 14,
                      color: _editColor,
                      height: 1.4)),
          const SizedBox(height: 4),
          Text(valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.hintColor, height: 1.4)),
        ])),
      ]);

  void _commissionInfo() => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.yellowTop, AppColors.yellowBottom]),
                  borderRadius: BorderRadius.circular(30)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Commission Structure',
                        style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBlack))),
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        commissionPct == null
                            ? 'The commission rate for your venue is currently unavailable. Please try refreshing the rate.'
                            : 'The commission for your venue in $city is $commissionLabel per booking. Rates vary by city.',
                        style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            height: 1.45,
                            color: AppColors.darkBlack))),
                const SizedBox(height: 22),
                Center(
                    child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6D4CB3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                        child: const Text('Close')))
              ]))));

  Widget _commission() => _section(
      "ACTIV's Commission Structure",
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _commissionRow(
            'For your venue in ${city.isEmpty ? 'your city' : city}',
            'Standard rate',
            commissionLabel,
            'Per booking'),
        const Divider(height: 24, color: AppColors.gray),
        if (commissionError != null)
          TextButton.icon(
              onPressed: () => _fetchCommission(_loadVersion),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(commissionError!)),
        Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
                border: Border.all(color: _editColor),
                borderRadius: BorderRadius.circular(8)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Note: Commission rates vary by city to ensure pricing and operational coverage across India.',
                  style:
                      TextStyle(fontSize: 13, color: _editColor, height: 1.5)),
              TextButton(
                  onPressed: _commissionInfo,
                  style: TextButton.styleFrom(
                      foregroundColor: _editColor,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      textStyle: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                        child: Text('Learn more about how commissions work',
                            style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 13,
                                fontWeight: FontWeight.w700))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16),
                  ])),
            ])),
      ]),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF0F1),
            borderRadius: BorderRadius.circular(8)),
        child: const Text('IMPORTANT',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.red,
                fontFamily: 'Satoshi')),
      ));

  Widget _amenities() => _section(
      'Amenities',
      amenities.isEmpty
          ? const Text('No amenities selected.')
          : Wrap(spacing: 10, runSpacing: 12, children: [
              for (final name in amenities)
                Container(
                    constraints: const BoxConstraints(maxWidth: 330),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.gray),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(name,
                        style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            height: 1.3))),
            ]),
      onEdit: () => _editSection(CustomerPlacesOffer(reviewMode: true)));

  String _activityImage(String title) => activityLogoAsset(title);

  String _activityDescription(Map<String, dynamic> activity) {
    for (final q in questions) {
      final matches = (q['categoryId'] != null &&
              activity['id'] != null &&
              q['categoryId'].toString() == activity['id'].toString()) ||
          q['categoryTitle'] == activity['title'];
      if (matches &&
          q['questionText']?.toString().toLowerCase() ==
              'activity description') {
        return q['answer']?.toString() ?? '';
      }
    }
    return activity['description']?.toString() ?? '';
  }

  Widget _activityRow(Map<String, dynamic> activity, int index) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          final details =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity['title']?.toString() ?? '',
                style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 16,
                    height: 1.3)),
            const SizedBox(height: 4),
            Text(_activityDescription(activity),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.hintColor, height: 1.4)),
          ]);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Image.asset(
                      _activityImage(activity['title']?.toString() ?? ''),
                      width: compact ? 44 : 60,
                      height: compact ? 44 : 60,
                      fit: BoxFit.contain),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                ]),
              ]);
        },
      );

  Widget _activities() => _section(
      'Activities',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'You can always add more activities or update activity details later, once venue is approved.',
            style:
                TextStyle(fontSize: 14, height: 1.5, color: AppColors.black1)),
        const SizedBox(height: 16),
        if (activities.isEmpty) const Text('No activities selected.'),
        for (var i = 0; i < activities.length; i++)
          Padding(
              padding:
                  EdgeInsets.only(bottom: i == activities.length - 1 ? 0 : 16),
              child: _activityRow(activities[i], i)),
      ]),
      onEdit: _editActivity);

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              getStepBarCount(onboardingReviewStep / totalSetup,
                  onboardingReviewStep, totalSetup),
              const SizedBox(height: 28),
              const Text('Review Venue Details',
                  style: OnboardingStyles.heading),
              const SizedBox(height: 8),
              const Text("Review your venue's details for a final confirmation",
                  style: TextStyle(
                      fontSize: 16, height: 1.4, color: AppColors.black1)),
            ])),
        Expanded(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [

              if (loading)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(children: [
                      AppSkeleton(height: 110),
                      SizedBox(height: 16),
                      AppSkeleton(height: 150),
                      SizedBox(height: 16),
                      AppSkeleton(height: 110),
                    ]))
              else if (loadError != null)
                TextButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: Text(loadError!))
              else ...[
                _partnerDetails(),
                _venueDetails(),
                _commission(),
                _amenities(),
                _activities()
              ],
            ])),
        DecoratedBox(
            decoration: const BoxDecoration(
                color: AppColors.yellowBottom,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 4,
                      offset: Offset(0, -2))
                ]),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: OnboardingButton(
                          label: 'Back',
                          fontSize: 16,
                          horizontalPadding: 8,
                          borderRadius: 8,
                          outlined: true,
                          onPressed:
                              saving ? null : () => Navigator.pop(context))),
                  const SizedBox(width: 16),
                  Expanded(
                      flex: 7,
                      child: OnboardingButton(
                          label: 'Confirm',
                          fontSize: 16,
                          horizontalPadding: 8,
                          borderRadius: 8,
                          loading: saving,
                          onPressed:
                              loading || loadError != null ? null : _confirm)),
                ]))),
      ]));
}
