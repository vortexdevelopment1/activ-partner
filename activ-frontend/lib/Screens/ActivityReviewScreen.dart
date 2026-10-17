import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Style/app_colors.dart';
import '../Utills/activity_question_visibility.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'LegalInformationScreen.dart';
import 'CategoryQuestionsScreen.dart';
import 'VenuePhotoListViewScreen.dart';
import 'VenuePhotoUploadScreen.dart';
import 'onboarding_widgets.dart';

const _editColor = Color(0xFFA634FF);

class ActivityReviewScreen extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> venueTimingMap;
  final List<Map<String, dynamic>> categoryTimings;
  final int initialActivityIndex;
  final http.Client? client;

  const ActivityReviewScreen({
    super.key,
    required this.activityId,
    this.venueTimingMap = const {},
    this.categoryTimings = const [],
    this.initialActivityIndex = 0,
    this.client,
  });

  @override
  State<ActivityReviewScreen> createState() => _State();
}

class _State extends State<ActivityReviewScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _activityIndex = 0;
  final _scrollController = ScrollController();
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
    _activityIndex = widget.initialActivityIndex.clamp(
      0,
      _activities.length - 1,
    );
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final raw = await SharedPreference.readStr('activity_questions_display');
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((q) => q is! Map)) return;
      setState(() => _questions =
          decoded.map((q) => Map<String, dynamic>.from(q as Map))
              .where((q) => !isPlaceholderActivityQuestion(q['questionText'])).toList());
    } on FormatException {
      // An incomplete local draft must not prevent reviewing saved timings.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        return 'Activity Description';
      default:
        return label;
    }
  }

  Future<void> _edit(int screensBack) async {
    if (screensBack == 2) {
      final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CategoryQuestionsScreen(
          venueId: widget.activityId,
          currentCategory: {
            ..._activity,
            'title': _title,
          },
          categoryIndex: _activityIndex + 1,
          totalCategories: _activities.length,
          accumulatedTimings: _activities,
          reviewMode: true,
          client: widget.client,
        ),
      ));
      if (!mounted || saved != true) return;
      await _loadQuestions();
      return;
    }
    if (screensBack == 3) {
      final activityId = widget.activityId;
      final venueTimingMap = Map<String, dynamic>.from(widget.venueTimingMap);
      final categoryTimings = _activities
          .map((timing) => Map<String, dynamic>.from(timing))
          .toList();
      final activityIndex = _activityIndex;
      VenuePhotoListViewScreen.returnToReviewBuilder = (_) =>
          ActivityReviewScreen(
            activityId: activityId,
            venueTimingMap: venueTimingMap,
            categoryTimings: categoryTimings,
            initialActivityIndex: activityIndex,
            client: widget.client,
          );
      final categoryId = _activity['id']?.toString() ?? '';
      final initialPhotos = VenuePhotoListViewScreen
              .cachedImagesByCategory[categoryId] ??
          (_activities.length == 1
              ? VenuePhotoListViewScreen.cachedImageBytes
              : <Uint8List>[]);
      final initialCoverIndex =
          VenuePhotoListViewScreen.cachedCoverIndexByCategory[categoryId] ?? 0;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VenuePhotoUploadScreen(
            currentCategory: {
              ..._activity,
              'id': categoryId,
              'name': _title,
              'title': _title,
            },
            remainingCategories: const [],
            categoryIndex: _activityIndex + 1,
            totalCategories: _activities.length,
            accumulatedTimings: _activities,
            initialImageBytes: List<Uint8List>.from(initialPhotos),
            initialCoverIndex: initialCoverIndex,
            replaceOnlyCurrentCategory: true,
          ),
        ),
      );
      return;
    }

    // Each configured activity contributes upload, preview and questions.
    final count = screensBack + 3 * (_activities.length - 1 - _activityIndex);
    final navigator = Navigator.of(context);
    for (var i = 0; i < count && navigator.canPop(); i++) {
      navigator.pop();
    }
  }

  void _selectActivity(int index) {
    setState(() => _activityIndex = index);
    _scrollController.jumpTo(0);
  }

  Widget _section(String title, int screensBack, Widget child) {
    final partitioned = title == 'Activity Specific Details';
    final header = Row(children: [
      Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontFamily: 'Satoshi', fontSize: 16, height: 1.3))),
      TextButton.icon(
        onPressed: () => _edit(screensBack),
        style: TextButton.styleFrom(
          foregroundColor: _editColor,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(fontFamily: 'Satoshi', fontSize: 14),
        ),
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Edit'),
      ),
    ]);
    return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: partitioned ? EdgeInsets.zero : const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.gray),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (partitioned)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: header,
            )
          else
            header,
          if (partitioned || title == 'Photos')
            const Divider(height: 1, color: AppColors.gray),
          if (partitioned)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: child,
            )
          else ...[
            const SizedBox(height: 12),
            child,
          ],
        ]),
      );
  }

  Widget _photos() {
    final coverIndex = VenuePhotoListViewScreen.cachedCoverIndexByCategory[
        _activity['id']?.toString()] ?? 0;
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
                      child: Stack(children: [AspectRatio(
                        aspectRatio: 1.95,
                        child: Image.memory(photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined))),
                      ),
                        if (i == coverIndex) Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Cover Photo', style: TextStyle(color: Colors.white, fontFamily: 'Satoshi', fontSize: 14)),
                          ),
                        ),
                      ]),
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
              Text(_title, style: const TextStyle(fontFamily: 'Satoshi', fontSize: 16)),
              const SizedBox(height: 14),
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
                  fontFamily: 'Satoshi', fontSize: 14, height: 1.4)),
        ],
      );

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
              const TextStyle(fontFamily: 'Satoshi', fontSize: 16),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              getStepBarCount(onboardingActivityReviewStep / totalSetup,
                  onboardingActivityReviewStep, totalSetup),
              const SizedBox(height: 25),
              const Text('Configuring Activity', style: OnboardingStyles.heading),
              const SizedBox(height: 8),
              const Text(
                  "Review this activity's details for changes or proceed",
                  style: TextStyle(
                      fontSize: 16, height: 1.4, color: AppColors.black1)),
            ],
          ),
        ),
          Expanded(
              child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 32),
            children: [

              _photos(),
              _details(),
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
