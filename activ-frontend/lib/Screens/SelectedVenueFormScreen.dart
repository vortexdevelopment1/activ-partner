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

// ─── Model ───────────────────────────────────────────────────────────────────

class Question {
  final String id;
  final String questionText;
  final String questionType;
  final List<String> options;
  final bool isRequired;
  final bool isActive;
  final int order;
  final String placeholder;
  final String helperText;

  Question({
    required this.id,
    required this.questionText,
    required this.questionType,
    this.options = const [],
    required this.isRequired,
    required this.isActive,
    required this.order,
    this.placeholder = '',
    this.helperText = '',
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
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
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SelectedVenueFormScreen extends StatefulWidget {
  final String activityId;
  const SelectedVenueFormScreen({super.key, required this.activityId});

  @override
  State<SelectedVenueFormScreen> createState() => _State();
}

class _State extends State<SelectedVenueFormScreen> {
  List<Question> _questions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Controllers for text / textarea / number questions
  final Map<String, TextEditingController> _textControllers = {};
  // Answers for select, multiselect, checkbox, date questions
  final Map<String, dynamic> _answers = {};

  int currentStep = 8;
  final int totalSteps = totalSetup;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── API call ──────────────────────────────────────────────────────────────

  Future<void> _fetchQuestions() async {
    final operateValueStr =
        checkString(await SharedPreference.readStr("operate_value"));
    String categoryId = '';
    if (operateValueStr.isNotEmpty) {
      final decoded = jsonDecode(operateValueStr);
      if (decoded is List && decoded.isNotEmpty) {
        // New format: array of {id, title} — use first selected category
        categoryId = decoded.first['id']?.toString() ?? '';
      } else if (decoded is Map) {
        // Old format: single {id, title}
        categoryId = decoded['id']?.toString() ?? '';
      }
    }

    if (categoryId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Category not found. Please go back and select an activity type.';
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$QUESTIONS_BY_CATEGORY_URL/$categoryId'),
      );

      if (!mounted) return;

      CommonUtilities.showLog('Questions response: ${response.body}');
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
        final questions = data
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .where((q) => q.isActive)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        // Create text controllers for text-based question types
        for (final q in questions) {
          if (['text', 'textarea', 'number'].contains(q.questionType)) {
            _textControllers[q.id] = TextEditingController();
          }
        }

        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load questions. Please try again.';
        });
      }
    } catch (e) {
      CommonUtilities.showLog('❌ Fetch questions error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load questions. Please try again.';
        });
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  dynamic _getAnswer(Question q) {
    if (_textControllers.containsKey(q.id)) {
      return _textControllers[q.id]!.text.trim();
    }
    return _answers[q.id];
  }

  bool _validate(BuildContext context) {
    for (final q in _questions) {
      if (!q.isRequired) continue;
      final answer = _getAnswer(q);
      final isEmpty = answer == null ||
          (answer is String && answer.isEmpty) ||
          (answer is List && answer.isEmpty);
      if (isEmpty) {
        CommonUtilities.createSnackBar(
            context, 'Please fill in: ${q.questionText}');
        return false;
      }
    }
    return true;
  }

  // ─── Submit answers ────────────────────────────────────────────────────────

  Future<void> _submitAnswers() async {
    // Build local maps first
    final Map<String, dynamic> allAnswers = {};
    final List<Map<String, dynamic>> displayList = [];
    for (final q in _questions) {
      final answer = _getAnswer(q);
      allAnswers[q.id] = answer;
      displayList.add({
        'questionText': q.questionText,
        'questionType': q.questionType,
        'answer': answer,
      });
    }

    // Persist locally (for review screen)
    await SharedPreference.addStringToSF(
        "activity_questions", jsonEncode(allAnswers));
    await SharedPreference.addStringToSF(
        "activity_questions_display", jsonEncode(displayList));

    // Read required values
    final venueId = checkString(await SharedPreference.readStr("venue_id"));
    final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));

    if (venueId.isEmpty) {
      if (!mounted) return;
      CommonUtilities.createSnackBar(context, 'Venue not found. Please restart setup.');
      return;
    }

    if (!mounted) return;
    ProgressBarNew().showLoader(context);

    try {
      // Build the answers payload: [{ questionId, answer }]
      final List<Map<String, dynamic>> answersPayload = _questions.map((q) {
        return {
          'questionId': q.id,
          'answer': _getAnswer(q) ?? '',
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$VENUE_ANSWERS_URL/$venueId/answers'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'answers': answersPayload}),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog('Submit answers status: ${response.statusCode}');
      CommonUtilities.showLog('Submit answers response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        CommonUtilities.NavigateWithPush(
            context, VenueTimingScreen(activityId: widget.activityId));
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Failed to save answers. Please try again.';
        CommonUtilities.createSnackBar(
            context, msg is List ? msg.join(', ') : msg.toString());
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog('❌ Submit answers error: $e');
      CommonUtilities.createSnackBar(
          context, 'Network error. Please check your connection.');
    }
  }

  // ─── Question widgets ──────────────────────────────────────────────────────

  Widget _buildQuestionWidget(Question q) {
    switch (q.questionType) {
      case 'textarea':
        return _buildTextField(q, maxLines: 3);
      case 'number':
        return _buildTextField(q, isNumber: true);
      case 'select':
      case 'radio':
        return _buildDropdown(q);
      case 'multiselect':
      case 'checkbox':
        return _buildCheckboxGroup(q);
      case 'date':
        return _buildDatePicker(q);
      default:
        return _buildTextField(q);
    }
  }

  Widget _buildLabel(Question q) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Row(
        children: [
          Text(
            q.questionText,
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1,
            ),
          ),
          if (q.isRequired)
            Text(
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

  Widget _buildTextField(Question q,
      {int maxLines = 1, bool isNumber = false}) {
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
            controller: _textControllers[q.id],
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType:
                isNumber ? TextInputType.number : TextInputType.text,
            inputFormatters:
                isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
            cursorColor: AppColors.cursorBlack,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: q.placeholder.isNotEmpty
                  ? q.placeholder
                  : 'Enter ${q.questionText.toLowerCase()}',
              hintStyle: TextStyle(
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
              style: TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown(Question q) {
    final selected = _answers[q.id] as String?;
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
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontRegular',
                  color: AppColors.hintColor,
                ),
              ),
              style: TextStyle(
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
              onChanged: (val) => setState(() => _answers[q.id] = val),
            ),
          ),
        ),
        if (q.helperText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Text(
              q.helperText,
              style: TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckboxGroup(Question q) {
    final selected = (_answers[q.id] as List<String>?) ?? [];
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
                _answers[q.id] = list;
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
                        _answers[q.id] = list;
                      });
                    },
                  ),
                  Text(
                    opt,
                    style: TextStyle(
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
              style: TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDatePicker(Question q) {
    final dateStr = _answers[q.id] as String?;
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
            if (picked != null) {
              setState(() {
                _answers[q.id] =
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
                    color:
                        dateStr != null ? AppColors.darkBlack : AppColors.hintColor,
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
              style: TextStyle(
                fontSize: AppSize.size_12,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(15, 0, 15, 0),
                            child: ListView(
                              children: [
                                getActivIcon(),
                                getStepBar(progress),
                                getText(),
                                getSubText(),
                                if (_isLoading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 40),
                                    child: Center(
                                        child:
                                            CircularProgressIndicator()),
                                  )
                                else if (_errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 40),
                                    child: Center(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                          fontSize: AppSize.size_14,
                                          fontFamily: 'FontRegular',
                                          color: AppColors.black1,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                else
                                  ..._questions
                                      .map(_buildQuestionWidget),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),

                        // Bottom bar
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          child: Column(
                            children: [
                              bottomBarShadow(),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      child: getBackButton(
                                          context, "Back", "tellUsAbout"),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 7,
                                    child: InkWell(
                                      onTap: () {
                                        if (_isLoading) return;
                                        if (_validate(context)) {
                                          _submitAnswers();
                                        }
                                      },
                                      child: getButtonBlack(
                                          context, "Next", "tellUsAbout"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
    );
  }

  Widget getStepBar(double progress) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getActivIcon() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: SvgPicture.asset("assets/activ_tm.svg"),
    );
  }

  Widget getText() {
    return Container(
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
    );
  }

  Widget getSubText() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: const Text(
        "We will use these details for venue place",
        style: TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'FontRegular',
          color: AppColors.black1,
          height: 1.4,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
