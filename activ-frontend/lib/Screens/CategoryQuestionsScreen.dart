import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import '../api_calling/progress_bar/progress_bar_new.dart';
import 'CommonCode.dart';
import 'VenueTimingScreen.dart';

// ─── Question model ───────────────────────────────────────────────────────────

class _Question {
  final String id;
  final String questionText;
  final String questionType;
  final List<String> options;
  final bool isRequired;
  final bool isActive;
  final int order;
  final String placeholder;
  final String helperText;
  final bool isGlobal;
  final int? minLength;
  final int? maxLength;

  _Question({
    required this.id,
    required this.questionText,
    required this.questionType,
    this.options = const [],
    required this.isRequired,
    required this.isActive,
    required this.order,
    this.placeholder = '',
    this.helperText = '',
    this.isGlobal = false,
    this.minLength,
    this.maxLength,
  });

  factory _Question.fromJson(Map<String, dynamic> json) {
    return _Question(
      id: json['id']?.toString() ?? '',
      questionText: json['questionText']?.toString() ?? '',
      questionType: json['questionType']?.toString() ?? 'text',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isRequired: json['isRequired'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      order: (json['order'] as num?)?.toInt() ?? 0,
      placeholder: json['placeholder']?.toString() ?? '',
      helperText: json['helperText']?.toString() ?? '',
      isGlobal: json['isGlobal'] as bool? ?? false,
      minLength: (json['minLength'] as num?)?.toInt(),
      maxLength: (json['maxLength'] as num?)?.toInt(),
    );
  }
}

// ─── Category section model ───────────────────────────────────────────────────

class _CategorySection {
  final String categoryId;
  final String categoryTitle;
  final List<_Question> questions;

  _CategorySection({
    required this.categoryId,
    required this.categoryTitle,
    required this.questions,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CategoryQuestionsScreen extends StatefulWidget {
  final String venueId;
  final Map<String, dynamic> currentCategory;
  final List<Map<String, dynamic>> remainingCategories;
  final int categoryIndex;
  final int totalCategories;
  final List<Map<String, dynamic>> accumulatedTimings;

  const CategoryQuestionsScreen({
    super.key,
    required this.venueId,
    this.currentCategory = const {},
    this.remainingCategories = const [],
    this.categoryIndex = 1,
    this.totalCategories = 1,
    this.accumulatedTimings = const [],
  });

  @override
  State<CategoryQuestionsScreen> createState() => _State();
}

class _State extends State<CategoryQuestionsScreen> {
  List<_CategorySection> _sections = [];
  List<_Question> _globalQuestions = []; // shown once, not per-category
  bool _isLoading = true;
  String _errorMessage = '';

  // Keys are composite: "${categoryId}_${questionId}"
  // This ensures identical question IDs across different categories
  // each get their own independent controller/answer slot.
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, dynamic> _answers = {};

  int currentStep = 4;
  final int totalSteps = totalSetup;

  // ─── Composite key helper ─────────────────────────────────────────────────
  String _key(String categoryId, String questionId) =>
      '${categoryId}_$questionId';

  @override
  void initState() {
    super.initState();
    _fetchAllQuestions();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Fetch questions for all selected categories concurrently ─────────────

  Future<void> _fetchAllQuestions() async {
    final categoryId = widget.currentCategory['id']?.toString() ?? '';
    final categoryTitle = widget.currentCategory['title']?.toString() ?? '';

    if (categoryId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$QUESTIONS_BY_CATEGORY_URL/$categoryId'),
      );

      CommonUtilities.showLog(
          'Questions [$categoryTitle] status: ${response.statusCode}');

      List<_CategorySection> sections = [];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          data = (decoded['data'] ??
                  decoded['questions'] ??
                  decoded['items'] ??
                  []) as List<dynamic>;
        } else {
          data = [];
        }

        final questions = data
            .map((e) => _Question.fromJson(e as Map<String, dynamic>))
            .where((q) => q.isActive)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        sections = [
          _CategorySection(
            categoryId: categoryId,
            categoryTitle: categoryTitle,
            questions: questions,
          )
        ];
      }

      // ── Separate global questions ──────────────────────────────────────────
      // A question is treated as global if:
      //   (a) it is flagged isGlobal: true in the API response, OR
      //   (b) it appears in more than one category's response (same question ID).
      // Either way it is shown exactly once, at the bottom of the form.

      // First pass — count how many categories each question ID appears in.
      final Map<String, int> idCount = {};
      for (final section in sections) {
        for (final q in section.questions) {
          idCount[q.id] = (idCount[q.id] ?? 0) + 1;
        }
      }

      final Set<String> seenGlobalIds = {};
      final List<_Question> globals = [];
      final List<_CategorySection> filteredSections = [];

      for (final section in sections) {
        final categorySpecific = <_Question>[];
        for (final q in section.questions) {
          final isEffectivelyGlobal = q.isGlobal || (idCount[q.id] ?? 1) > 1;
          if (isEffectivelyGlobal) {
            if (!seenGlobalIds.contains(q.id)) {
              seenGlobalIds.add(q.id);
              globals.add(q);
            }
            // discard duplicate occurrences from other category sections
          } else {
            categorySpecific.add(q);
          }
        }
        filteredSections.add(_CategorySection(
          categoryId: section.categoryId,
          categoryTitle: section.categoryTitle,
          questions: categorySpecific,
        ));
      }

      // Create controllers for global questions (keyed under 'global')
      for (final q in globals) {
        if (['text', 'textarea', 'number'].contains(q.questionType)) {
          _textControllers[_key('global', q.id)] = TextEditingController();
        }
      }

      // Create controllers for category-specific questions
      for (final section in filteredSections) {
        for (final q in section.questions) {
          if (['text', 'textarea', 'number'].contains(q.questionType)) {
            _textControllers[_key(section.categoryId, q.id)] =
                TextEditingController();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _globalQuestions = globals;
        _sections = filteredSections;
        _isLoading = false;
      });
    } catch (e) {
      CommonUtilities.showLog('Fetch questions error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load questions. Please try again.';
        });
      }
    }
  }

  // ─── Answer helpers ───────────────────────────────────────────────────────

  // Always pass categoryId so we look up the category-scoped slot.
  dynamic _getAnswer(String categoryId, _Question q) {
    final k = _key(categoryId, q.id);
    if (_textControllers.containsKey(k)) {
      return _textControllers[k]!.text.trim();
    }
    return _answers[k];
  }

  bool _validate() {
    bool checkQuestion(String categoryId, _Question q) {
      final answer = _getAnswer(categoryId, q);
      final isEmpty = answer == null ||
          (answer is String && answer.isEmpty) ||
          (answer is List && answer.isEmpty);
      if (q.isRequired && isEmpty) {
        CommonUtilities.createSnackBar(
            context, 'Please fill in: ${q.questionText}');
        return false;
      }
      if (!isEmpty && answer is String && q.minLength != null && answer.length < q.minLength!) {
        CommonUtilities.createSnackBar(
            context, '${q.questionText} must be at least ${q.minLength} characters.');
        return false;
      }
      return true;
    }

    for (final q in _globalQuestions) {
      if (!checkQuestion('global', q)) return false;
    }
    for (final section in _sections) {
      for (final q in section.questions) {
        if (!checkQuestion(section.categoryId, q)) return false;
      }
    }
    return true;
  }

  // ─── Submit all answers ───────────────────────────────────────────────────

  Future<void> _submitAnswers() async {
    final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));

    if (!mounted) return;
    ProgressBarNew().showLoader(context);

    try {
      // Flat list of all answers; each entry carries its own questionId.
      final List<Map<String, dynamic>> answersPayload = [];
      final List<Map<String, dynamic>> displayList = [];

      // Category-specific questions first
      for (final section in _sections) {
        for (final q in section.questions) {
          final answer = _getAnswer(section.categoryId, q);
          answersPayload.add({
            'questionId': q.id,
            'answer': answer ?? '',
          });
          displayList.add({
            'questionText': q.questionText,
            'questionType': q.questionType,
            'categoryTitle': section.categoryTitle,
            'answer': answer,
          });
        }
      }

      // Global questions last — submitted once, shown under 'General' on review
      for (final q in _globalQuestions) {
        final answer = _getAnswer('global', q);
        answersPayload.add({
          'questionId': q.id,
          'answer': answer ?? '',
        });
        displayList.add({
          'questionText': q.questionText,
          'questionType': q.questionType,
          'categoryTitle': 'General',
          'answer': answer,
        });
      }

      // Persist for review screen — append if not first category
      List<dynamic> existingList = [];
      if (widget.categoryIndex > 1) {
        final existingRaw = checkString(await SharedPreference.readStr('activity_questions_display'));
        if (existingRaw.isNotEmpty) {
          existingList = jsonDecode(existingRaw) as List<dynamic>;
        }
      }
      existingList.addAll(displayList);
      await SharedPreference.addStringToSF(
          "activity_questions_display", jsonEncode(existingList));

      final response = await http.post(
        Uri.parse('$VENUE_ANSWERS_URL/${widget.venueId}/answers'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'answers': answersPayload}),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog(
          'Submit answers status: ${response.statusCode}');
      CommonUtilities.showLog('Submit answers body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        CommonUtilities.NavigateWithPush(
            context,
            VenueTimingScreen(
              activityId: widget.venueId,
              categoryId: widget.currentCategory['id']?.toString() ?? '',
              categoryTitle: widget.currentCategory['title']?.toString() ?? '',
              categoryIndex: widget.categoryIndex,
              totalCategories: widget.totalCategories,
              remainingCategories: widget.remainingCategories,
              accumulatedTimings: widget.accumulatedTimings,
            ));
      } else {
        final body = jsonDecode(response.body);
        final msg =
            body['message'] ?? 'Failed to save answers. Please try again.';
        CommonUtilities.createSnackBar(
            context, msg is List ? msg.join(', ') : msg.toString());
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog('Submit answers error: $e');
      CommonUtilities.createSnackBar(
          context, 'Network error. Please check your connection.');
    }
  }

  // ─── Question widgets ─────────────────────────────────────────────────────
  // categoryId is threaded through every widget so the composite key
  // is always available when reading/writing answers.

  Widget _buildQuestionWidget(String categoryId, _Question q) {
    switch (q.questionType) {
      case 'textarea':
        return _buildTextField(categoryId, q, maxLines: 3);
      case 'number':
        return _buildTextField(categoryId, q, isNumber: true);
      case 'select':
      case 'radio':
        return _buildDropdown(categoryId, q);
      case 'multiselect':
      case 'checkbox':
        return _buildCheckboxGroup(categoryId, q);
      case 'date':
        return _buildDatePicker(categoryId, q);
      default:
        return _buildTextField(categoryId, q);
    }
  }

  Widget _buildLabel(_Question q) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              q.questionText,
              style: const TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1.3,
              ),
            ),
          ),
          if (q.isRequired)
            const Text(
              ' *',
              style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.red,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(String categoryId, _Question q,
      {int maxLines = 1, bool isNumber = false}) {
    final k = _key(categoryId, q.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(q),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gray, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextFormField(
            controller: _textControllers[k],
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType:
                isNumber ? TextInputType.number : TextInputType.text,
            inputFormatters: [
              if (isNumber) FilteringTextInputFormatter.digitsOnly,
              if (q.maxLength != null)
                LengthLimitingTextInputFormatter(q.maxLength),
            ],
            cursorColor: AppColors.cursorBlack,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: q.placeholder.isNotEmpty
                  ? q.placeholder
                  : 'Enter ${q.questionText.toLowerCase()}',
              hintStyle: const TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (q.helperText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Text(
              q.helperText,
              style: const TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown(String categoryId, _Question q) {
    final k = _key(categoryId, q.id);
    final selected = _answers[k] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(q),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gray, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selected,
              hint: Text(
                q.placeholder.isNotEmpty ? q.placeholder : 'Select an option',
                style: const TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.hintColor,
                ),
              ),
              style: const TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontRegular',
                color: AppColors.darkBlack,
              ),
              items: q.options
                  .map((opt) => DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _answers[k] = val),
            ),
          ),
        ),
        if (q.helperText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Text(
              q.helperText,
              style: const TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckboxGroup(String categoryId, _Question q) {
    final k = _key(categoryId, q.id);
    final selected = (_answers[k] as List<String>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(q),
        ...q.options.map((opt) {
          final isChecked = selected.contains(opt);
          return InkWell(
            onTap: () {
              setState(() {
                final list = List<String>.from(selected);
                if (isChecked) {
                  list.remove(opt);
                } else {
                  list.add(opt);
                }
                _answers[k] = list;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: isChecked,
                    activeColor: AppColors.darkBlack,
                    onChanged: (val) {
                      setState(() {
                        final list = List<String>.from(selected);
                        if (val == true) {
                          list.add(opt);
                        } else {
                          list.remove(opt);
                        }
                        _answers[k] = list;
                      });
                    },
                  ),
                  Text(
                    opt,
                    style: const TextStyle(
                      fontSize: AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.darkBlack,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (q.helperText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Text(
              q.helperText,
              style: const TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDatePicker(String categoryId, _Question q) {
    final k = _key(categoryId, q.id);
    final dateStr = _answers[k] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(q),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null && mounted) {
              setState(() {
                _answers[k] =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              });
            }
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr ??
                      (q.placeholder.isNotEmpty
                          ? q.placeholder
                          : 'Select a date'),
                  style: TextStyle(
                    fontSize: AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: dateStr != null
                        ? AppColors.darkBlack
                        : AppColors.hintColor,
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        ),
        if (q.helperText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Text(
              q.helperText,
              style: const TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double progress = currentStep / totalSteps;
    final bool hasNoQuestions = !_isLoading &&
        _errorMessage.isEmpty &&
        _globalQuestions.isEmpty &&
        _sections.every((s) => s.questions.isEmpty);
    // Show "General" header for global questions only when there are also
    // category-specific questions to distinguish them from.
    final bool hasCategorySpecific = _sections.any((s) => s.questions.isNotEmpty);
    final bool showCategoryHeaders = _sections.length > 1 || hasCategorySpecific;

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
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      child: ListView(
                        children: [
                          // Header
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: SvgPicture.asset("assets/activ_tm.svg"),
                          ),

                          // Step bar
                          getStepBarCount(progress, currentStep, totalSteps),

                          // Title
                          Container(
                            margin: const EdgeInsets.only(top: 25),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              "Tell us about your venue!",
                              style: TextStyle(
                                fontSize: AppSize.size_25,
                                fontFamily: 'FontSemiBold',
                                color: AppColors.darkBlack,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                            child: const Text(
                              "Please answer the questions for each selected category",
                              style: TextStyle(
                                fontSize: AppSize.size_16,
                                fontFamily: 'FontRegular',
                                color: AppColors.black1,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),

                          // Content
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            )
                          else if (_errorMessage.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    fontSize: AppSize.size_14,
                                    fontFamily: 'FontRegular',
                                    color: AppColors.black1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else if (hasNoQuestions)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  "No additional questions for the selected categories.",
                                  style: TextStyle(
                                    fontSize: AppSize.size_14,
                                    fontFamily: 'FontRegular',
                                    color: AppColors.black1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else ...[
                            // Category-specific questions
                            ..._sections
                                .where((s) => s.questions.isNotEmpty)
                                .expand((section) => [
                                      _buildSectionHeader(
                                          section.categoryTitle),
                                      ...section.questions.map(
                                        (q) => _buildQuestionWidget(
                                            section.categoryId, q),
                                      ),
                                    ]),
                            // Global questions — shown once, at the bottom
                            if (_globalQuestions.isNotEmpty) ...[
                              if (showCategoryHeaders)
                                _buildSectionHeader('General'),
                              ..._globalQuestions.map(
                                (q) => _buildQuestionWidget('global', q),
                              ),
                            ],
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
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
                                  context, "Back", "categoryQuestions"),
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: InkWell(
                              onTap: () {
                                if (_isLoading) return;
                                if (hasNoQuestions || _validate()) {
                                  _submitAnswers();
                                }
                              },
                              child: getButtonBlack(
                                  context, "Next", "categoryQuestions"),
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

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkBlack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'FontSemiBold',
          color: AppColors.yellow,
          height: 1,
        ),
      ),
    );
  }
}
