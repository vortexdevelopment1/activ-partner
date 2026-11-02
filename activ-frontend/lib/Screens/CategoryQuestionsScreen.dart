import 'dart:async';
import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../Utills/activity_question_visibility.dart';
import '../Utills/browser_session.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'ActivityReviewScreen.dart';
import 'VenuePhotoUploadScreen.dart';
import 'activity_details_form.dart';

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
  final String unit;

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
    this.unit = '',
  });

  static String _normalizedType(dynamic rawType) {
    final type = rawType?.toString().trim().toLowerCase() ?? '';
    return switch (type) {
      'dropdown' || 'single_select' || 'single-select' => 'select',
      'multi_select' || 'multi-select' => 'multiselect',
      'long_text' || 'long-text' => 'textarea',
      'integer' || 'numeric' => 'number',
      'number_stepper' || 'stepper' => 'number_stepper',
      _ => type.isEmpty ? 'text' : type,
    };
  }

  static List<String> _parseOptions(dynamic rawOptions, String questionText) {
    final options = <String>[];

    void add(dynamic value) {
      if (value == null) return;
      if (value is Map) {
        add(value['label'] ?? value['name'] ?? value['title'] ?? value['value']);
        return;
      }
      final option = value.toString().trim();
      if (option.isNotEmpty && !options.contains(option)) options.add(option);
    }

    if (rawOptions is List) {
      for (final item in rawOptions) {
        add(item);
      }
    } else if (rawOptions is String) {
      for (final item in rawOptions.split(RegExp(r'[,|]'))) {
        add(item);
      }
    }

    if (options.isNotEmpty) return options;

    final text = questionText.trim().toLowerCase();
    if (text == 'pitch type') {
      return const ['Turf', 'Matting', 'Cement', 'Natural Grass', 'Astro Turf'];
    }
    if (text == 'pitch surface' || text == 'court surface') {
      return const ['Wooden', 'Synthetic', 'Concrete', 'Grass', 'Clay'];
    }
    if (text == 'court type') {
      return const ['Full Court', 'Half Court', 'Practice Court'];
    }
    if (text == 'playing environment') {
      return const ['Indoor', 'Outdoor', 'Air Conditioned', 'Covered', 'Floodlights', 'Spectator Seating'];
    }
    return const [];
  }

  factory _Question.fromJson(Map<String, dynamic> json) {
    final questionText = json['questionText']?.toString() ?? '';
    return _Question(
      id: json['id']?.toString() ?? '',
      questionText: questionText,
      questionType: _normalizedType(json['questionType']),
      options: _parseOptions(json['options'], questionText),
      isRequired: json['isRequired'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      order: (json['order'] as num?)?.toInt() ?? 0,
      placeholder: json['placeholder']?.toString() ?? '',
      helperText: json['helperText']?.toString() ?? '',
      isGlobal: json['isGlobal'] as bool? ?? false,
      minLength: (json['minLength'] as num?)?.toInt(),
      maxLength: (json['maxLength'] as num?)?.toInt(),
      unit: json['unit']?.toString() ?? '',
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
    this.client,
    this.reviewMode = false,
    this.activityId,
    this.initialManagementData = const {},
    this.onSaveActivity,
  });

  final http.Client? client;
  final bool reviewMode;
  final String? activityId;
  final Map<String, dynamic> initialManagementData;
  final Future<bool> Function(List<Map<String, dynamic>> answers)? onSaveActivity;

  @override
  State<CategoryQuestionsScreen> createState() => _State();
}

class _State extends State<CategoryQuestionsScreen> {
  List<_CategorySection> _sections = [];
  List<_Question> _globalQuestions = []; // shown once, not per-category
  bool _isLoading = true;
  String _errorMessage = '';
  bool _savingManaged = false;
  bool get _managedMode => widget.activityId?.isNotEmpty == true;

  // Keys are composite: "${categoryId}_${questionId}"
  // This ensures identical question IDs across different categories
  // each get their own independent controller/answer slot.
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, dynamic> _answers = {};
  final Map<String, String> _selectedUnits = {};

  int currentStep = onboardingQuestionsStep;
  final int totalSteps = totalSetup;

  // ─── Composite key helper ─────────────────────────────────────────────────
  String _key(String categoryId, String questionId) => '${categoryId}_$questionId';

  String get _sessionKey => 'question_draft_${widget.venueId}_${widget.currentCategory['id'] ?? ''}';

  void _saveSessionAnswers() {
    if (_managedMode || !isBrowserSession || _isLoading || _errorMessage.isNotEmpty) return;
    writeBrowserSession(_sessionKey, jsonEncode({
      for (final section in _sections)
        for (final question in section.questions)
          _key(section.categoryId, question.id): _getAnswer(section.categoryId, question),
      for (final question in _globalQuestions) _key('global', question.id): _getAnswer('global', question),
    }));
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _saveSessionAnswers();
  }

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

    if (categoryId.isEmpty && !_managedMode) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final headers = <String, String>{};
      if (_managedMode) {
        final token = await SharedPreference.readStr('jwt_token');
        if (token == null || token.isEmpty) throw StateError('Sign in required');
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse(_managedMode
            ? '$BASE_URL/venues/activities/${widget.activityId}/questions'
            : '$QUESTIONS_BY_CATEGORY_URL/$categoryId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (_managedMode && response.statusCode != 200) throw StateError('Question loading failed');
      final managedAnswers = <String, dynamic>{};

      CommonUtilities.showLog('Questions [$categoryTitle] status: ${response.statusCode}');

      List<_CategorySection> sections = [];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          data = (decoded['data'] ?? decoded['questions'] ?? decoded['items'] ?? []) as List<dynamic>;
        } else {
          data = [];
        }

        if (_managedMode) {
          for (final item in data.whereType<Map>()) {
            managedAnswers[item['id'].toString()] = item['answer'];
          }
        }
        final questions = data
            .map((e) => _Question.fromJson(e as Map<String, dynamic>))
            .where((q) => q.isActive &&
                !isPlaceholderActivityQuestion(q.questionText) &&
                !{'court surface', 'equipment available'}
                    .contains(q.questionText.trim().toLowerCase()))
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
            _textControllers[_key(section.categoryId, q.id)] = TextEditingController();
          }
        }
      }

      if (_managedMode) {
        final all = [...globals, for (final section in filteredSections) ...section.questions];
        void restore(String sectionId, _Question question) {
          final answer = _managedInitialAnswer(question, all, managedAnswers[question.id]);
          if (answer == null) return;
          final key = _key(sectionId, question.id);
          if (_textControllers.containsKey(key)) {
            _textControllers[key]!.text = answer.toString();
          } else {
            if (['select', 'radio'].contains(question.questionType) && !question.options.contains(answer)) return;
            _answers[key] = answer is List ? answer.map((value) => value.toString()).toList() : answer;
          }
        }
        for (final section in filteredSections) {
          for (final question in section.questions) { restore(section.categoryId, question); }
        }
        for (final question in globals) { restore('global', question); }
      } else {
        final raw = await SharedPreference.readStr('activity_questions_display');
        if (!mounted) return;
        final saved = raw == null || raw.isEmpty ? <dynamic>[] : jsonDecode(raw) as List;
        void restore(String sectionId, _Question question) {
          final matches = saved.where((entry) => (entry['categoryId']?.toString() == categoryId || entry['categoryTitle'] == categoryTitle || entry['categoryTitle'] == 'General') && (entry['questionId'] == question.id || entry['questionText'] == question.questionText));
          if (matches.isEmpty) return;
          final answer = matches.last['answer'];
          final key = _key(sectionId, question.id);
          if (_textControllers.containsKey(key)) {
            _textControllers[key]!.text = answer?.toString() ?? '';
          } else {
            if (['select', 'radio'].contains(question.questionType) && !question.options.contains(answer)) return;
            _answers[key] = answer is List ? answer.map((value) => value.toString()).toList() : answer;
          }
        }

        for (final section in filteredSections) {
          for (final question in section.questions) {
            restore(section.categoryId, question);
          }
        }
        for (final question in globals) {
          restore('global', question);
        }
      }
      if (!mounted) return;
      if (isBrowserSession && !_managedMode) {
        try {
          final raw = readBrowserSession(_sessionKey);
          final draft = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
          for (final entry in draft.entries) {
            final controller = _textControllers[entry.key];
            if (controller != null) {
              controller.text = entry.value?.toString() ?? '';
            } else {
              _answers[entry.key] = entry.value is List
                  ? (entry.value as List).map((e) => e.toString()).toList() : entry.value;
            }
          }
        } catch (_) {}
        for (final controller in _textControllers.values) {
          controller.addListener(_saveSessionAnswers);
        }
      }
      void initializeDefaults(String categoryId, _Question q) {
        final key = _key(categoryId, q.id);
        if (q.questionType == 'number_stepper') {
          _answers.putIfAbsent(key, () => q.questionText.toLowerCase().contains('batch') || q.questionText.toLowerCase().contains('capacity') ? 25 : 1);
        } else if (q.questionType == 'radio' && q.options.isNotEmpty) {
          _answers.putIfAbsent(key, () => q.options.first);
        }
      }
      for (final section in filteredSections) {
        for (final question in section.questions) { initializeDefaults(section.categoryId, question); }
      }
      for (final question in globals) { initializeDefaults('global', question); }
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
  dynamic _managedInitialAnswer(_Question question, List<_Question> all, dynamic saved) {
    String normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const labels = <String, List<String>>{
      'description': ['activity description'],
      'numberOfCourt': ['total courts', 'total turfs', 'total nets', 'total arenas', 'total tables', 'total fields', 'number of courts'],
      'courtType': ['court type', 'court surface', 'pitch type', 'pitch surface', 'turf type', 'field type', 'table type', 'lane type', 'range type', 'arena type', 'activity type'],
      'playingEnvironment': ['playing environment', 'environment'],
      'coachingAvailable': ['coaching available', 'coaching'],
      'recommendedFor': ['recommended for'],
    };
    for (final entry in labels.entries) {
      final selectedLabel = entry.value.where((label) => all.any((q) => normalize(q.questionText) == label)).firstOrNull;
      if (selectedLabel == normalize(question.questionText) && widget.initialManagementData[entry.key] != null) {
        return widget.initialManagementData[entry.key];
      }
    }
    return saved;
  }

  Future<void> _saveManagedAnswers() async {
    if (_savingManaged || widget.onSaveActivity == null) return;
    final payload = <Map<String, dynamic>>[];
    void add(String sectionId, _Question question) {
      payload.add({'questionId': question.id, 'answer': _getAnswer(sectionId, question) ??
          (['checkbox', 'multiselect'].contains(question.questionType) ? <String>[] : '')});
    }
    for (final section in _sections) {
      for (final question in section.questions) { add(section.categoryId, question); }
    }
    for (final question in _globalQuestions) { add('global', question); }
    setState(() => _savingManaged = true);
    try {
      final saved = await widget.onSaveActivity!(payload);
      if (mounted && saved) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) CommonUtilities.createSnackBar(context, 'Unable to save activity details. Please try again.');
    } finally {
      if (mounted) setState(() => _savingManaged = false);
    }
  }

  dynamic _getAnswer(String categoryId, _Question q) {
    final k = _key(categoryId, q.id);
    if (_textControllers.containsKey(k)) {
      final text = _textControllers[k]!.text.trim();
      final value = num.tryParse(text);
      final selectedUnit = _selectedUnits[k] ?? q.unit;
      if (q.questionType == 'number' && q.unit.isNotEmpty && selectedUnit != q.unit && value != null) {
        return activityConvertUnit(value, selectedUnit, q.unit).toString();
      }
      return text;
    }
    return _answers[k];
  }

  bool _validate() {
    bool checkQuestion(String categoryId, _Question q) {
      final answer = _getAnswer(categoryId, q);
      final isEmpty = answer == null || (answer is String && answer.isEmpty) || (answer is List && answer.isEmpty);
      if (q.isRequired && isEmpty) {
        CommonUtilities.createSnackBar(context, 'Please fill in: ${q.questionText}');
        return false;
      }
      if (!isEmpty && q.questionType == 'number' &&
          (num.tryParse(answer.toString()) == null || num.parse(answer.toString()) < 0)) {
        CommonUtilities.createSnackBar(context, 'Enter a valid number for ${q.questionText}.');
        return false;
      }
      if (!isEmpty && answer is String && q.minLength != null && answer.length < q.minLength!) {
        CommonUtilities.createSnackBar(context, '${q.questionText} must be at least ${q.minLength} characters.');
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

  Future<void> _cacheAnswers({
    required List<Map<String, dynamic>> displayList,
    required String categoryId,
  }) async {
    List<dynamic> existingList = [];
    final existingRaw = checkString(
        await SharedPreference.readStr('activity_questions_display'));
    if (existingRaw.isNotEmpty) {
      existingList = jsonDecode(existingRaw) as List<dynamic>;
    }
    final titles = displayList.map((q) => q['categoryTitle']).toSet();
    existingList.removeWhere((q) =>
        isPlaceholderActivityQuestion(q['questionText']) ||
        q['categoryId'] == categoryId ||
        (q['categoryId'] == null && titles.contains(q['categoryTitle'])));
    existingList.addAll(displayList);

    await SharedPreference.addStringToSF(
        'activity_questions_display', jsonEncode(existingList));
  }

  Future<void> _persistAnswers({
    required String jwtToken,
    required List<Map<String, dynamic>> answersPayload,
  }) async {
    try {
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse('$VENUE_ANSWERS_URL/${widget.venueId}/answers'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'answers': answersPayload}),
      );
      CommonUtilities.showLog('Submit answers status: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        CommonUtilities.showLog('Submit answers failed: ${response.body}');
      }
    } catch (e) {
      CommonUtilities.showLog('Submit answers error: $e');
    }
  }

  Future<void> _submitAnswers() async {
    final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));
    if (!mounted) return;

    // Flat list of all answers; each entry carries its own questionId.
    final List<Map<String, dynamic>> answersPayload = [];
    final List<Map<String, dynamic>> displayList = [];

    // Category-specific questions first
    for (final section in _sections) {
      for (final q in section.questions) {
        final answer = _getAnswer(section.categoryId, q);
        answersPayload.add({'questionId': q.id, 'answer': answer ?? ''});
        displayList.add({
          'questionId': q.id,
          'questionText': q.questionText,
          'questionType': q.questionType,
          'categoryTitle': section.categoryTitle,
          'categoryId': widget.currentCategory['id']?.toString() ?? '',
          'answer': answer,
        });
      }
    }

    // Global questions last — submitted once, shown under 'General' on review
    for (final q in _globalQuestions) {
      final answer = _getAnswer('global', q);
      answersPayload.add({'questionId': q.id, 'answer': answer ?? ''});
      displayList.add({
        'questionId': q.id,
        'questionText': q.questionText,
        'questionType': q.questionType,
        'categoryTitle': 'General',
        'categoryId': widget.currentCategory['id']?.toString() ?? '',
        'answer': answer,
      });
    }

    final categoryId = widget.currentCategory['id']?.toString() ?? '';
    // The review screen reads this cache once on entry. Commit the display
    // data before navigating, independently of the background API response.
    await _cacheAnswers(displayList: displayList, categoryId: categoryId);
    if (!mounted) return;
    unawaited(_persistAnswers(
      jwtToken: jwtToken,
      answersPayload: answersPayload,
    ));

    if (widget.reviewMode) {
      Navigator.pop(context, true);
      return;
    }

    final accumulated = List<Map<String, dynamic>>.from(widget.accumulatedTimings)
      ..removeWhere((entry) => entry['id'] == categoryId)
      ..add({
        'id': categoryId,
        'title': widget.currentCategory['title']?.toString() ?? '',
        'timing': <String, dynamic>{},
      });

    if (widget.remainingCategories.isNotEmpty) {
      final nextCategory = widget.remainingCategories.first;
      CommonUtilities.NavigateWithPush(
          context,
          VenuePhotoUploadScreen(
            currentCategory: nextCategory,
            remainingCategories: widget.remainingCategories.sublist(1),
            categoryIndex: widget.categoryIndex + 1,
            totalCategories: widget.totalCategories,
            accumulatedTimings: accumulated,
          ));
    } else {
      CommonUtilities.NavigateWithPush(
          context,
          ActivityReviewScreen(
            activityId: widget.venueId,
            categoryTimings: accumulated,
          ));
    }
  }

  // ─── Question widgets ─────────────────────────────────────────────────────
  // categoryId is threaded through every widget so the composite key
  // is always available when reading/writing answers.

  Widget _buildQuestionWidget(String categoryId, _Question q) {
    if (q.questionType == 'date') return _buildDatePicker(categoryId, q);
    final key = _key(categoryId, q.id);
    return ActivityQuestionInput(
      label: q.questionText, type: q.questionType,
      inputKey: ValueKey('question-$categoryId-${q.id}'),
      controller: _textControllers[key], answer: _answers[key],
      required: q.isRequired, options: q.options,
      placeholder: activityQuestionPlaceholder(widget.currentCategory['title']?.toString() ?? '', q.questionText, q.placeholder), helper: q.helperText,
      maxLength: q.maxLength, minLength: q.minLength,
      unit: q.unit, selectedUnit: _selectedUnits[key],
      onChanged: (value) {
        setState(() => _answers[key] = value);
        _saveSessionAnswers();
      },
      onUnitChanged: (next) {
        final controller = _textControllers[key]!;
        final value = num.tryParse(controller.text);
        if (value != null) {
          final converted = activityConvertUnit(value, _selectedUnits[key] ?? q.unit, next);
          controller.text = converted.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
        }
        setState(() => _selectedUnits[key] = next);
        _saveSessionAnswers();
      },
    );
  }

  Widget _buildLabel(_Question q) => ActivityDetailsLabel(label: q.questionText, required: q.isRequired);

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
                _answers[k] = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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
                  dateStr ?? (q.placeholder.isNotEmpty ? q.placeholder : 'Select a date'),
                  style: TextStyle(
                    fontSize: AppSize.size_14,
                    fontFamily: 'Satoshi',
                    color: dateStr != null ? AppColors.darkBlack : AppColors.hintColor,
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
                fontFamily: 'Satoshi',
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
    final empty = !_isLoading && _errorMessage.isEmpty && _globalQuestions.isEmpty && _sections.every((section) => section.questions.isEmpty);
    final name = widget.currentCategory['title']?.toString() ?? 'Activity';
    return ActivityDetailsLayout(
      buttonLabel: _managedMode ? 'Save Changes' : 'Next',
      saving: _savingManaged,
      onContinue: _isLoading || _savingManaged || _errorMessage.isNotEmpty ? null : () {
        if (empty || _validate()) {
          if (_managedMode) { _saveManagedAnswers(); } else { _submitAnswers(); }
        }
      },
      child: ListView(padding: EdgeInsets.symmetric(horizontal: activityDetailsGutter(context)), children: [
        ActivityDetailsHeading(name: name, bookingType: widget.currentCategory['type']?.toString()),
        if (_isLoading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text(_errorMessage, textAlign: TextAlign.center),
          TextButton(onPressed: _fetchAllQuestions, child: const Text('Retry')),
        ]))
        else if (empty) const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text('No additional questions for the selected categories.'))
        else ...[
          for (final section in _sections.where((section) => section.questions.isNotEmpty)) ...[
            if (_sections.length > 1) _buildSectionHeader(section.categoryTitle),
            for (final question in section.questions) _buildQuestionWidget(section.categoryId, question),
          ],
          if (_globalQuestions.isNotEmpty) ...[
            if (_sections.any((section) => section.questions.isNotEmpty)) _buildSectionHeader('General'),
            for (final question in _globalQuestions) _buildQuestionWidget('global', question),
          ],
        ],
      ]),
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
          fontFamily: 'Satoshi',
          color: AppColors.yellow,
          height: 1,
        ),
      ),
    );
  }
}
