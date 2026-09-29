import 'dart:convert';
import 'dart:typed_data';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'LegalInformationScreen.dart';
import 'VenuePhotoListViewScreen.dart';

// Edit button accent colour (matches screenshot)
const _editColor = Color(0xFF7C3AED);

class ActivityReviewScreen extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> venueTimingMap;
  // Each entry: { 'id': categoryId, 'title': categoryTitle, 'timing': {...} }
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
  int currentStep = 9;
  final int totalSteps = totalSetup;

  List<Map<String, dynamic>> _questionDisplay = [];

  // Ordered full day names
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final raw =
        checkString(await SharedPreference.readStr('activity_questions_display'));
    if (raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      setState(() {
        _questionDisplay =
            decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  List<Map<String, String>> _slots(Map<String, dynamic> timing, String day) {
    final raw = timing[day];
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((s) => s.map((k, v) => MapEntry(k, v?.toString() ?? '')))
        .toList();
  }

  List<String> _openDays(Map<String, dynamic> timing) =>
      _days.where((day) {
        final slots = _slots(timing, day);
        return slots.any((s) => s['open'] != null && s['open'] != '-');
      }).toList();

  bool _isClosedDay(Map<String, dynamic> timing, String day) {
    final slots = _slots(timing, day);
    return slots.isEmpty ||
        slots.every((s) => s['open'] == '-' || s['open'] == null || s['open']!.isEmpty);
  }

  Widget _buildTimingContent(Map<String, dynamic> timing) {
    final openDays = _openDays(timing);
    const dayAbbr = {
      'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
      'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operating Days',
          style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontSemiBold',
            color: AppColors.darkBlack,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _days.map((day) {
            final isOpen = openDays.contains(day);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isOpen ? AppColors.darkBlack : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOpen ? AppColors.darkBlack : AppColors.gray,
                ),
              ),
              child: Text(
                dayAbbr[day] ?? day.substring(0, 3),
                style: TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'FontMedium',
                  color: isOpen ? AppColors.white : AppColors.hintColor,
                  height: 1,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.gray),
        const SizedBox(height: 12),
        const Text(
          'Day Wise Timings',
          style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontSemiBold',
            color: AppColors.darkBlack,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        ..._days.map((day) {
          if (_isClosedDay(timing, day)) return const SizedBox.shrink();
          final slots = _slots(timing, day);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: AppSize.size_13,
                    fontFamily: 'FontSemiBold',
                    color: AppColors.darkBlack,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                ...slots
                    .where((s) =>
                        s['open'] != null &&
                        s['open'] != '-' &&
                        s['close'] != null &&
                        s['close'] != '-')
                    .map((slot) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _timingCell(
                                      'Open Time', slot['open'] ?? '')),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _timingCell(
                                      'Close Time', slot['close'] ?? '')),
                            ],
                          ),
                        )),
                const Divider(height: 16, color: AppColors.gray),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatAnswer(Map<String, dynamic> q) {
    final answer = q['answer'];
    if (answer == null) return '-';
    if (answer is List) return answer.join(', ');
    return answer.toString().isEmpty ? '-' : answer.toString();
  }

  void _popTimes(int times) {
    for (int i = 0; i < times; i++) {
      Navigator.pop(context);
    }
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required VoidCallback onEdit,
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
          // Header
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

  // ─── Photos section ───────────────────────────────────────────────────────

  Widget _buildPhotosSection() {
    final List<Uint8List> bytes = VenuePhotoListViewScreen.cachedImageBytes;
    return _sectionCard(
      title: 'Photos',
      onEdit: () => _popTimes(3),
      content: bytes.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No photos uploaded.',
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.hintColor,
                ),
              ),
            )
          : Column(
              children: bytes.asMap().entries.map((entry) {
                final isFirst = entry.key == 0;
                return Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.memory(
                        entry.value,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    if (isFirst)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                          decoration: BoxDecoration(
                            color: AppColors.darkGray,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cover Photo',
                            style: TextStyle(
                              fontSize: AppSize.size_12,
                              fontFamily: 'FontSemiBold',
                              color: AppColors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  // ─── Activity Specific Details section ───────────────────────────────────

  Widget _buildActivityDetailsSection() {
    // Group questions by their category title
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final q in _questionDisplay) {
      final cat = q['categoryTitle']?.toString() ?? '';
      grouped.putIfAbsent(cat, () => []).add(q);
    }
    final categories = grouped.keys.toList();
    final bool multiCategory = categories.length > 1;

    return _sectionCard(
      title: 'Activity Specific Details',
      onEdit: () => _popTimes(2),
      content: _questionDisplay.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No details available.',
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.hintColor,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final cat in categories) ...[
                    // Show category header only when multiple categories
                    if (multiCategory)
                      Container(
                        margin: const EdgeInsets.fromLTRB(0, 4, 0, 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.darkBlack,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontSize: AppSize.size_12,
                            fontFamily: 'FontSemiBold',
                            color: AppColors.yellow,
                            height: 1,
                          ),
                        ),
                      ),
                    ...grouped[cat]!.map((q) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q['questionText']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: AppSize.size_12,
                                  fontFamily: 'FontRegular',
                                  color: AppColors.hintColor,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatAnswer(q),
                                style: const TextStyle(
                                  fontSize: AppSize.size_14,
                                  fontFamily: 'FontMedium',
                                  color: AppColors.darkBlack,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  // ─── Operational Details section ──────────────────────────────────────────

  Widget _buildOperationalDetailsSection() {
    final bool multiCategory = widget.categoryTimings.length > 1;

    // Decide content based on available data
    Widget content;
    if (widget.categoryTimings.isEmpty) {
      // Backward compat — flat venueTimingMap
      content = _buildTimingContent(widget.venueTimingMap);
    } else if (!multiCategory) {
      // Single category — no header chip needed
      content = _buildTimingContent(
          (widget.categoryTimings.first['timing'] as Map<String, dynamic>?) ??
              {});
    } else {
      // Multiple categories — show a chip header per category
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.categoryTimings.length; i++) ...[
            Container(
              margin: EdgeInsets.fromLTRB(0, i == 0 ? 0 : 16, 0, 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.darkBlack,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.categoryTimings[i]['title']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'FontSemiBold',
                  color: AppColors.yellow,
                  height: 1,
                ),
              ),
            ),
            _buildTimingContent(
              (widget.categoryTimings[i]['timing'] as Map<String, dynamic>?) ??
                  {},
            ),
          ],
        ],
      );
    }

    return _sectionCard(
      title: 'Operational Details',
      onEdit: () => _popTimes(1),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: content,
      ),
    );
  }

  Widget _timingCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppSize.size_12,
            fontFamily: 'FontRegular',
            color: AppColors.hintColor,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppSize.size_13,
            fontFamily: 'FontMedium',
            color: AppColors.darkBlack,
            height: 1,
          ),
        ),
      ],
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
                        // Header
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          child: SvgPicture.asset('assets/activ_tm.svg'),
                        ),
                        getStepBarCount(progress, currentStep, totalSteps),
                        Container(
                          margin: const EdgeInsets.only(top: 25),
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Configuring Activity',
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
                            "Review this activity's details for changes or proceed",
                            style: TextStyle(
                              fontSize: AppSize.size_16,
                              fontFamily: 'FontRegular',
                              color: AppColors.black1,
                              height: 1.4,
                            ),
                          ),
                        ),

                        _buildPhotosSection(),
                        _buildActivityDetailsSection(),
                        _buildOperationalDetailsSection(),
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
                                  context, 'Back', 'activityReview'),
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: InkWell(
                              onTap: () => CommonUtilities.NavigateWithPush(
                                  context, const LegalInformationScreen()),
                              child: getButtonBlack(
                                  context, 'Next', 'activityReview'),
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
