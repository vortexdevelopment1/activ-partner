import 'package:activ_app/Screens/Home/HomeScreen.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../Beans/activity_model.dart';
import '../../../api_calling/api_request.dart';
import '../../../api_calling/api_constant.dart';
import '../../StringExtensions.dart';
import 'ActivityManagementScreen.dart';
import 'AddActivities/AddListActivityTypeScreen.dart';

class VenueActivityListScreen extends StatefulWidget {
  const VenueActivityListScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<VenueActivityListScreen> createState() => _State();
}

class _State extends State<VenueActivityListScreen> {
  List<ActivityModel> activities = [];
  bool isLoading = true;
  String? loadError;
  String selectedFilter = 'All';
  Map<String, Map<String, dynamic>> activityInfo = {};
  static const background = Color(0xFFF0F6D2);
  static const purple = Color(0xFFA536F5);
  final currency = NumberFormat.currency(
      locale: 'en_IN', symbol: '\u20b9 ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    fetchActivities();
  }

  Future<void> fetchActivities() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final token = checkString(await SharedPreference.readStr('jwt_token'));
      if (token.isEmpty) {
        throw Exception('Please sign in again to view activities.');
      }
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(MY_APPROVED_VENUES_URL),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(response.statusCode == 401
            ? 'Your session expired. Please sign in again.'
            : 'Unable to load activities. Please try again.');
      }
      final data = jsonDecode(response.body)['data'] as List;
      final result = <ActivityModel>[];
      final info = <String, Map<String, dynamic>>{};
      for (final venue in data.cast<Map<String, dynamic>>()) {
        for (final service in (venue['services'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final status =
              (service['status'] ?? 'draft').toString().toLowerCase();
          final label = status == 'approved'
              ? (service['isActive'] == false || venue['bookingAccept'] == false
                  ? 'Inactive'
                  : 'Active')
              : status == 'draft'
                  ? 'Draft'
                  : ['pending', 'submitted', 'in_review'].contains(status)
                      ? 'In Review'
                      : 'Inactive';
          info[service['id'].toString()] = {
            'venueId': venue['id']?.toString() ?? '',
            'status': label,
            'bookings': service['bookingCount'],
            'earnings': service['earnings'],
          };
          final categoryId = service['categoryId'];
          final title = service['name']?.toString() ?? 'Activity';
          final timing = <String, dynamic>{};
          final days = service['availability'] ??
              venue['availability']?[categoryId] ??
              [];
          for (final day in days as List) {
            final name = day['day'].toString();
            timing[name[0].toUpperCase() + name.substring(1).toLowerCase()] = [
              for (final slot in day['slots'] as List? ?? [])
                {
                  'open': slot['openTime'],
                  'close': slot['closeTime'],
                  'capacity': slot['capacity'],
                  'price': slot['price'],
                },
            ];
          }
          result.add(ActivityModel.fromJson({
            'activity_id': service['id'],
            'operate_value': {'id': categoryId, 'title': title},
            'activity_status': 'true',
            'description': service['description'] ?? '',
            'images': [
              for (final url in service['imageUrls'] as List? ?? [])
                {
                  'url': url,
                  'coverPhoto': url == service['coverImageUrl'],
                }
            ],
            'venue_amenities': {
              'place_offer': [
                for (final title
                    in service['amenities'] ?? venue['amenities'] ?? [])
                  {'title': title},
              ]
            },
            'venue_timing': timing,
          }));
        }
      }
      result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      if (mounted) {
        setState(() {
          activities = result;
          activityInfo = info;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() =>
            loadError = 'The server is taking too long. Please try again.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => loadError =
            error is FormatException || error is TypeError
                ? 'Unable to read activities. Please try again.'
                : error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<ActivityModel> get visibleActivities => activities
      .where((a) =>
          selectedFilter == 'All' ||
          activityInfo[a.activityId]?['status'] == selectedFilter)
      .toList();

  String totalMetric(String key, {bool money = false}) {
    if (activities.any((a) => activityInfo[a.activityId]?[key] == null)) {
      return '\u2014';
    }
    final total = activities.fold<num>(
        0,
        (sum, a) =>
            sum +
            (num.tryParse(activityInfo[a.activityId]![key].toString()) ?? 0));
    return money ? currency.format(total) : total.toInt().toString();
  }

  Future<void> addActivity() async {
    for (final key in [
      'number_of_court',
      'flooring_type',
      'maximum_capacity',
      'description',
      'operate_value',
      'place_offer'
    ]) {
      await SharedPreference.addStringToSF(key, '');
    }
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => AddListActivityTypeScreen()));
    if (mounted) fetchActivities();
  }

  void goBack() {
    CommonUtilities.addActivitySuccessfully = '';
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
          context, HomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleActivities;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Row(children: [
              Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: const CircleBorder(),
                  child: IconButton(
                      tooltip: 'Back',
                      onPressed: goBack,
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back, size: 20))),
              const SizedBox(width: 20),
              const Expanded(
                  child: Text('Activity Management',
                      style: TextStyle(
                          fontFamily: 'FontBold',
                          fontSize: 22,
                          color: Color(0xFF303030)))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(
                  child: summaryTile(
                      'Total Activities',
                      isLoading ? '\u2014' : activities.length.toString(),
                      'Active, Draft & Pending')),
              const SizedBox(width: 10),
              Expanded(
                  child: summaryTile(
                      'Total Booking',
                      isLoading ? '\u2014' : totalMetric('bookings'),
                      'All Activities')),
              const SizedBox(width: 10),
              Expanded(
                  child: summaryTile(
                      'Total Earning',
                      isLoading
                          ? '\u2014'
                          : totalMetric('earnings', money: true),
                      'All Activities')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
                children: ['All', 'Active', 'In Review', 'Draft', 'Inactive']
                    .map((filter) => Expanded(
                          flex: filter == 'In Review'
                              ? 13
                              : filter == 'All'
                                  ? 7
                                  : 10,
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: filter == 'Inactive' ? 0 : 8),
                            child: Semantics(
                              selected: selectedFilter == filter,
                              button: true,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => selectedFilter = filter),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: selectedFilter == filter
                                          ? purple
                                          : Colors.transparent,
                                      border: Border.all(
                                          color: selectedFilter == filter
                                              ? purple
                                              : const Color(0xFF87916B)),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 3),
                                          child: Text(filter,
                                              style: TextStyle(
                                                  fontFamily: 'FontRegular',
                                                  fontSize: 12,
                                                  color:
                                                      selectedFilter == filter
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF545A48))))),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList()),
          ),
          Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : loadError != null
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(loadError!,
                                        textAlign: TextAlign.center),
                                    TextButton.icon(
                                        onPressed: fetchActivities,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry')),
                                  ])))
                      : RefreshIndicator(
                          onRefresh: fetchActivities,
                          child: visible.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 80),
                                          child: Center(
                                              child: Text(activities.isEmpty
                                                  ? 'No Activities found'
                                                  : 'No ${selectedFilter.toLowerCase()} activities')))
                                    ])
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(32, 0, 32, 12),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) =>
                                      activityCard(visible[i])))),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                      onPressed: addActivity,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: const Color(0xFFD8F34A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Add New Activity',
                          style: TextStyle(
                              fontFamily: 'FontBold', fontSize: 16))))),
        ]),
      ))),
    );
  }

  Widget summaryTile(String title, String value, String caption) => Container(
        height: 82,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    maxLines: 1,
                    style: const TextStyle(
                        fontFamily: 'FontRegular', fontSize: 9))),
            const Icon(Icons.receipt_long_outlined,
                size: 12, color: Color(0xFF80DD92)),
          ]),
          const SizedBox(height: 10),
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontFamily: 'FontBold', fontSize: 16)))),
          const SizedBox(height: 7),
          Text(caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'FontRegular',
                  fontSize: 8,
                  color: Color(0xFF858585))),
        ]),
      );

  Widget activityCard(ActivityModel activity) {
    final info = activityInfo[activity.activityId]!;
    final status = info['status'] as String;
    final statusColor = switch (status) {
      'Active' => const Color(0xFF13CE28),
      'Inactive' => const Color(0xFFFF5757),
      'In Review' => const Color(0xFFDC9300),
      _ => purple,
    };
    final cover = activity.images
        .whereType<Map>()
        .where((i) => i['coverPhoto'] == true)
        .firstOrNull;
    final first = activity.images.whereType<Map>().firstOrNull;
    final url = (cover?['url'] ?? first?['url'])?.toString();
    final earnings = num.tryParse(info['earnings']?.toString() ?? '');
    final fallback = Image.asset('assets/ic_cock.png', fit: BoxFit.contain);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDDE0D5))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute<bool>(
                  builder: (_) => ActivityManagementScreen(
                      activity: activity,
                      initialStatus: status,
                      venueId: info['venueId'] as String,
                      client: widget.client)));
          if (mounted) fetchActivities();
        },
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                      width: 88,
                      height: 96,
                      child: url == null || url.isEmpty
                          ? fallback
                          : Image.network(url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => fallback))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(activity.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'FontBold', fontSize: 15))),
                      const Icon(Icons.chevron_right,
                          size: 18, color: Color(0xFF777777)),
                    ]),
                    const SizedBox(height: 3),
                    Text(activity.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'FontRegular',
                            fontSize: 12,
                            color: Color(0xFF888888))),
                    const SizedBox(height: 15),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: metric(
                                  'Booking',
                                  Text(info['bookings']?.toString() ?? '\u2014',
                                      style: const TextStyle(
                                          fontFamily: 'FontBold',
                                          fontSize: 15,
                                          color: purple)))),
                          Expanded(
                              child: metric(
                                  'Earning',
                                  FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          earnings == null
                                              ? '\u2014'
                                              : currency.format(earnings),
                                          style: const TextStyle(
                                              fontFamily: 'FontBold',
                                              fontSize: 11))))),
                          const SizedBox(width: 4),
                          Expanded(
                              child: metric(
                                  'Status',
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: statusColor,
                                              borderRadius:
                                                  BorderRadius.circular(5)),
                                          child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                  status == 'In Review'
                                                      ? 'In review'
                                                      : status,
                                                  style: const TextStyle(
                                                      fontFamily: 'FontBold',
                                                      fontSize: 9,
                                                      color:
                                                          Colors.white))))))),
                        ]),
                  ])),
            ])),
      ),
    );
  }

  Widget metric(String label, Widget value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontFamily: 'FontRegular', fontSize: 10)),
          const SizedBox(height: 4),
          value,
        ],
      );
}
