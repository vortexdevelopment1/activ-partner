import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../Style/app_colors.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'LegalInformationScreen.dart';
import 'VenuePhotoListViewScreen.dart';
import 'onboarding_widgets.dart';

const _editColor = Color(0xFFA634FF);

class ActivityReviewScreen extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> venueTimingMap;
  final List<Map<String, dynamic>> categoryTimings;

  const ActivityReviewScreen({
    super.key,
    required this.activityId,
    this.venueTimingMap = const {},
    this.categoryTimings = const [],
  });

  @override
  State<ActivityReviewScreen> createState() => _State();
}

class _State extends State<ActivityReviewScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _activityIndex = 0;
  final _scrollController = ScrollController();
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  List<Map<String, dynamic>> get _activities {
    if (widget.categoryTimings.isNotEmpty) return widget.categoryTimings;
    final titles = _questions
        .map((q) => q['categoryTitle']?.toString() ?? '')
        .where((title) => title.isNotEmpty && title != 'General')
        .toSet();
    return [
      for (final title in titles)
        {'title': title, 'timing': widget.venueTimingMap},
      if (titles.isEmpty)
        {'title': 'Activity', 'timing': widget.venueTimingMap},
    ];
  }

  Map<String, dynamic> get _activity => _activities[_activityIndex];
  String get _title => _activity['title']?.toString() ?? 'Activity';
  Map<String, dynamic> get _timing =>
      Map<String, dynamic>.from(_activity['timing'] as Map? ?? {});
  List<Map<String, dynamic>> get _activityQuestions => _questions
      .where((q) => q['categoryId'] != null && _activity['id'] != null
          ? q['categoryId'].toString() == _activity['id'].toString()
          : q['categoryTitle'] == _title || q['categoryTitle'] == 'General')
      .toList();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final raw = await SharedPreference.readStr('activity_questions_display');
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((q) => q is! Map)) return;
      setState(() => _questions =
          decoded.map((q) => Map<String, dynamic>.from(q as Map)).toList());
    } on FormatException {
      // An incomplete local draft must not prevent reviewing saved timings.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _slots(String day) => (_timing[day] as List? ?? [])
      .map((slot) => Map<String, dynamic>.from(slot as Map))
      .where((slot) => _hasTime(slot['open']) && _hasTime(slot['close']))
      .toList();

  bool _hasTime(dynamic value) =>
      value != null && value.toString().isNotEmpty && value != '-';

  String _answer(dynamic value) {
    if (value is List) return value.join(', ');
    return value == null || value.toString().isEmpty ? '-' : value.toString();
  }

  String _detailLabel(dynamic value) {
    final label = value?.toString() ?? '';
    switch (label.toLowerCase()) {
      case 'total courts':
        return 'Number of Courts';
      case 'activity description':
        return 'Description';
      default:
        return label;
    }
  }

  void _edit(int screensBack) {
    // Each configured activity contributes upload, preview, questions and timings.
    final count = screensBack + 4 * (_activities.length - 1 - _activityIndex);
    final navigator = Navigator.of(context);
    for (var i = 0; i < count && navigator.canPop(); i++) {
      navigator.pop();
    }
  }

  void _selectActivity(int index) {
    setState(() => _activityIndex = index);
    _scrollController.jumpTo(0);
  }

  Widget _section(String title, int screensBack, Widget child) => Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.gray),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: 'OnboardingSemibold',
                        fontSize: 16,
                        height: 1.3))),
            TextButton.icon(
              onPressed: () => _edit(screensBack),
              style: TextButton.styleFrom(
                foregroundColor: _editColor,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(
                    fontFamily: 'OnboardingMedium', fontSize: 14),
              ),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit'),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _photos() {
    final List<Uint8List> photos = VenuePhotoListViewScreen
            .cachedImagesByCategory[_activity['id']?.toString()] ??
        (_activities.length == 1
            ? VenuePhotoListViewScreen.cachedImageBytes
            : []);
    return _section(
        'Photos',
        3,
        photos.isEmpty
            ? const Text('No photos uploaded.')
            : Column(children: [
                for (var i = 0; i < photos.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == photos.length - 1 ? 0 : 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 1.95,
                        child: Image.memory(photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined))),
                      ),
                    ),
                  ),
              ]));
  }

  Widget _details() => _section(
      'Activity Specific Details',
      2,
      _activityQuestions.isEmpty
          ? const Text('No details available.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < _activityQuestions.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: i == _activityQuestions.length - 1 ? 0 : 14),
                  child: _cell(
                      _detailLabel(_activityQuestions[i]['questionText']),
                      _answer(_activityQuestions[i]['answer'])),
                ),
            ]));

  Widget _cell(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.hintColor, height: 1.4)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'OnboardingMedium', fontSize: 14, height: 1.4)),
        ],
      );

  String _capacity(Map<String, dynamic> slot) {
    if (slot['capacity'] != null) return _answer(slot['capacity']);
    for (final q in _activityQuestions) {
      final label = q['questionText']?.toString().toLowerCase() ?? '';
      if (label.contains('capacity')) return _answer(q['answer']);
    }
    return '-';
  }

  Widget _operations() {
    final openDays = _days.where((day) => _slots(day).isNotEmpty).toList();
    return _section(
        'Operational Details',
        1,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Operating Days',
              style: TextStyle(fontFamily: 'OnboardingSemibold')),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    for (final day in _days)
                      Text(day.substring(0, 3),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: openDays.contains(day)
                                  ? AppColors.darkBlack
                                  : AppColors.hintColor,
                              decoration: openDays.contains(day)
                                  ? null
                                  : TextDecoration.lineThrough)),
                  ])),
          const Divider(height: 32, color: AppColors.gray),
          const Text('Day Wise Timings',
              style: TextStyle(fontFamily: 'OnboardingSemibold')),
          if (openDays.isEmpty) ...[
            const SizedBox(height: 16),
            const Text('Operational timings have not been added yet.'),
          ],
          for (var i = 0; i < openDays.length; i++) ...[
            const SizedBox(height: 18),
            Text(openDays[i],
                style: const TextStyle(fontFamily: 'OnboardingSemibold')),
            for (final slot in _slots(openDays[i])) ...[
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(14) > 18 ? 2 : 3;
                final width =
                    (constraints.maxWidth - 8 * (columns - 1)) / columns;
                return Wrap(spacing: 8, runSpacing: 12, children: [
                  SizedBox(
                      width: width,
                      child: _cell('Open Time', _answer(slot['open']))),
                  SizedBox(
                      width: width,
                      child: _cell('Close Time', _answer(slot['close']))),
                  SizedBox(
                      width: width, child: _cell('Capacity', _capacity(slot))),
                ]);
              }),
            ],
            if (i < openDays.length - 1)
              const Divider(height: 24, color: AppColors.gray),
          ],
        ]));
  }

  Widget _footerButton(
          {required String label,
          required VoidCallback onPressed,
          bool outlined = false}) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          backgroundColor: outlined ? AppColors.cream : Colors.black,
          foregroundColor: outlined ? Colors.black : AppColors.yellow,
          textStyle:
              const TextStyle(fontFamily: 'OnboardingSemibold', fontSize: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: outlined
                  ? const BorderSide(color: AppColors.gray1)
                  : BorderSide.none),
        ),
        child: Text(label, textAlign: TextAlign.center),
      );

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
        child: Column(children: [
          Expanded(
              child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
            children: [
              const OnboardingLogo(),
              getStepBarCount(onboardingActivityReviewStep / totalSetup,
                  onboardingActivityReviewStep, totalSetup),
              const SizedBox(height: 20),
              Text(
                  'Configuring Activity ${_activityIndex + 1} of ${_activities.length} \u2014 Step 4/4',
                  style: const TextStyle(
                      fontFamily: 'OnboardingMedium',
                      fontSize: 14,
                      color: AppColors.hintColor,
                      height: 1.4)),
              const SizedBox(height: 12),
              Text(_title, style: OnboardingStyles.heading),
              const SizedBox(height: 8),
              const Text(
                  "Review this activity's details for changes or proceed",
                  style: TextStyle(
                      fontSize: 16, height: 1.4, color: AppColors.black1)),
              _photos(),
              _details(),
              _operations(),
            ],
          )),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.yellowBottom,
              boxShadow: [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, -2))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: _footerButton(
                        label: 'Back',
                        outlined: true,
                        onPressed: () => _activityIndex > 0
                            ? _selectActivity(_activityIndex - 1)
                            : Navigator.pop(context))),
                const SizedBox(width: 16),
                Expanded(
                    flex: 7,
                    child: _footerButton(
                      label: _activityIndex < _activities.length - 1
                          ? 'Configure Next Activity'
                          : 'Next',
                      onPressed: () => _activityIndex < _activities.length - 1
                          ? _selectActivity(_activityIndex + 1)
                          : Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const LegalInformationScreen())),
                    )),
              ]),
            ),
          ),
        ]),
      );
}
