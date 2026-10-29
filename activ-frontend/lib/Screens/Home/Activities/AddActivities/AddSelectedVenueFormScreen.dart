import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../../../../api_calling/activity_setup_api.dart';
import '../../../../api_calling/api_request.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import '../../../../Utills/activity_question_visibility.dart';
import '../../../CommonCode.dart';
import '../../../onboarding_widgets.dart';
import '../../../activity_details_fields.dart';
import 'AddActivityAmenitiesScreen.dart';

class AddSelectedVenueFormScreen extends StatefulWidget {
  const AddSelectedVenueFormScreen(
      {super.key,
      this.activityId = '',
      this.activityIdFuture,
      this.onActivityReady,
      this.initialActivity,
      this.initialQuestions,
      this.client});
  final String activityId;
  final Future<String>? activityIdFuture;
  final Future<void> Function(String activityId)? onActivityReady;
  final Map<String, dynamic>? initialActivity;
  final List<Map<String, dynamic>>? initialQuestions;
  final http.Client? client;
  @override
  State<AddSelectedVenueFormScreen> createState() => _DetailsState();
}

class _DetailsState extends State<AddSelectedVenueFormScreen> {
  final _form = GlobalKey<FormState>();
  final _answers = <String, dynamic>{};
  final _controllers = <String, TextEditingController>{};
  late final ActivitySetupApi _api;
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true, _saving = false;
  String? _error;
  String? _uploadingQuestion;
  String _activityName = 'Activity';
  String _resolvedActivityId = '';

  @override
  void initState() {
    super.initState();
    _api = ActivitySetupApi(client: widget.client);
    _resolvedActivityId = widget.activityId;
    if (_resolvedActivityId.isNotEmpty && !ActivityFlowCheckpoint.restoring) {
      ActivityFlowCheckpoint.save(activityId: _resolvedActivityId, step: 'details');
    }
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.initialActivity != null && widget.initialQuestions != null) {
        _applyLoadedData(widget.initialActivity!, widget.initialQuestions!);
        return;
      }
      if (_resolvedActivityId.isEmpty && widget.activityIdFuture != null) {
        _resolvedActivityId = await widget.activityIdFuture!;
      }
      if (_resolvedActivityId.isEmpty) {
        throw Exception('Activity upload did not return an activity ID.');
      }
      final results = await Future.wait<dynamic>([
        _api.activity(_resolvedActivityId),
        _api.questions(_resolvedActivityId),
      ]);
      final activity = results[0] as Map<String, dynamic>;
      final questions = results[1] as List<Map<String, dynamic>>;
      _applyLoadedData(activity, questions);
      if (widget.onActivityReady != null) {
        unawaited(widget.onActivityReady!(_resolvedActivityId));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLoadedData(
      Map<String, dynamic> activity, List<Map<String, dynamic>> questions) {
    questions = questions.where((question) => !isRemovedActivityQuestion(question['questionText'])).toList();
    final originalOrder = <Map<String, dynamic>, int>{
      for (var i = 0; i < questions.length; i++) questions[i]: i,
    };
    final orderedQuestions = List<Map<String, dynamic>>.from(questions)
      ..sort((a, b) {
        int priority(Map<String, dynamic> question) {
          final text = question['questionText']?.toString().toLowerCase() ?? '';
          if (text.contains('activity description')) return 0;
          if (text.contains('pool length')) return 1;
          if (text.contains('pool type')) return 2;
          return 4;
        }

        final priorityComparison = priority(a).compareTo(priority(b));
        return priorityComparison != 0
            ? priorityComparison
            : originalOrder[a]!.compareTo(originalOrder[b]!);
      });
    for (final question in questions) {
      final id = question['id'].toString();
      final value = question['answer'];
      if (value != null) _answers[id] = value;
      _controllers.putIfAbsent(
          id, () => TextEditingController(text: value?.toString() ?? ''));
    }
    if (mounted) {
      setState(() {
        _questions = orderedQuestions;
        _activityName = (activity['name'] ?? 'Activity').toString();
      });
    }
  }

  Future<void> _next() async {
    if (_saving ||
        _uploadingQuestion != null ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_questions.isNotEmpty) {
        await _api.saveAnswers(
            _resolvedActivityId,
            Map.fromEntries(_answers.entries.where((entry) =>
                entry.value != null &&
                entry.value.toString().trim().isNotEmpty &&
                (entry.value is! List || (entry.value as List).isNotEmpty))));
      }
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => AddActivityAmenitiesScreen(
                  activityId: _resolvedActivityId, client: widget.client)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _options(Map<String, dynamic> question) {
    final raw = question['options'];
    return raw is List
        ? raw
            .map((v) => v is Map
                ? (v['label'] ?? v['value'] ?? '').toString()
                : v.toString())
            .where((v) => v.isNotEmpty)
            .toList()
        : raw is String
            ? raw
                .split(RegExp(r'[,|]'))
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toList()
            : [];
  }

  Widget _field(Map<String, dynamic> question) {
    final id = question['id'].toString();
    final type = question['questionType']?.toString().toLowerCase() ?? 'text';
    final required = question['isRequired'] == true;
    final options = _options(question);
    String? validate(dynamic value) => required &&
            (value == null ||
                value.toString().trim().isEmpty ||
                (value is List && value.isEmpty))
        ? 'Please answer this question'
        : null;
    Widget input;
    if (type == 'file') {
      input = FormField<String>(
          initialValue: _answers[id]?.toString(),
          validator: validate,
          builder: (field) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                OutlinedButton(
                    onPressed: _uploadingQuestion != null
                        ? null
                        : () async {
                            final selected = await FilePicker.platform
                                .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png'
                                    ],
                                    withData: true);
                            if (selected == null || !mounted) return;
                            final file = selected.files.single;
                            if (file.bytes == null) return;
                            setState(() => _uploadingQuestion = id);
                            try {
                              final url = await _api.uploadAnswerFile(
                                  _resolvedActivityId,
                                  id,
                                  file.bytes!,
                                  file.name);
                              if (!mounted) return;
                              _answers[id] = url;
                              field.didChange(url);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())));
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _uploadingQuestion = null);
                              }
                            }
                          },
                    child: Text(_uploadingQuestion == id
                        ? 'Uploading...'
                        : field.value == null
                            ? 'Upload PDF or image'
                            : 'Document attached — replace')),
                if (field.hasError)
                  Text(field.errorText!,
                      style: const TextStyle(color: Colors.red)),
              ]));
    } else if (['select', 'radio'].contains(type) && options.isNotEmpty) {
      input = DropdownButtonFormField<String>(
        initialValue:
            options.contains(_answers[id]) ? _answers[id] as String : null,
        isExpanded: true,
        decoration:
            OnboardingStyles.inputDecoration(hintText: 'Select an option'),
        items: options
            .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis)))
            .toList(),
        validator: validate,
        onChanged: (value) => setState(() => _answers[id] = value),
      );
    } else if (['multiselect', 'checkbox'].contains(type) &&
        options.isNotEmpty) {
      input = FormField<List<String>>(
          initialValue: _answers[id] is List
              ? (_answers[id] as List).map((v) => v.toString()).toList()
              : [],
          validator: validate,
          builder: (field) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ActivityDetailsOptions(
                  options: options,
                  values: field.value ?? [],
                  onChanged: (value) {
                    field.didChange(value);
                    _answers[id] = value;
                  },
                ),
                if (field.hasError)
                  Text(field.errorText!,
                      style: const TextStyle(color: Colors.red)),
              ]));
    } else {
      input = TextFormField(
        key: ValueKey('activity-question-$id'),
        controller: _controllers[id],
        maxLines: type == 'textarea' ? 3 : 1,
        readOnly: type == 'date',
        decoration: OnboardingStyles.inputDecoration(
            hintText: question['placeholder']?.toString() ?? 'Enter answer'),
        keyboardType:
            type == 'number' ? TextInputType.number : TextInputType.text,
        validator: (value) {
          final missing = validate(value);
          if (missing != null) return missing;
          if (type == 'number' &&
              (value ?? '').isNotEmpty &&
              num.tryParse(value!) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
        onTap: type == 'date'
            ? () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100));
                if (date != null && mounted) {
                  _controllers[id]!.text =
                      date.toIso8601String().split('T').first;
                  _answers[id] = _controllers[id]!.text;
                }
              }
            : null,
        onChanged: (value) =>
            _answers[id] = type == 'number' ? num.tryParse(value) : value,
      );
    }
    return ActivityDetailsField(
      label: (question['questionText'] ?? 'Activity details').toString(),
      isRequired: required,
      helperText: (question['helperText'] ?? '').toString(),
      child: input,
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: getStepBarCount(4 / 6, 4, 6)),
        if (!_loading && _error == null)
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activityName,
                        style: OnboardingStyles.heading.copyWith(
                            fontSize: 34, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Provide Activity Specific Details',
                        style: OnboardingStyles.body.copyWith(fontSize: 16)),
                  ])),
        Expanded(
            child: _loading
                ? const SizedBox.shrink()
                : _error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!),
                        TextButton(onPressed: _load, child: const Text('Retry'))
                      ]))
                    : Form(
                        key: _form,
                        child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              if (_questions.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFCEDCE0)),
                                  ),
                                  child: Column(children: [
                                    const Icon(Icons.task_alt,
                                        size: 48, color: Color(0xFF9D38EB)),
                                    const SizedBox(height: 16),
                                    Text('No extra details needed',
                                        textAlign: TextAlign.center,
                                        style: OnboardingStyles.body.copyWith(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Text(
                                        'You can continue to choose amenities for $_activityName.',
                                        textAlign: TextAlign.center,
                                        style: OnboardingStyles.body),
                                  ]),
                                ),
                              ..._questions.map(_field),
                            ]))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                  child: OnboardingButton(
                      label: 'Back',
                      outlined: true,
                      onPressed:
                          _saving ? null : () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: OnboardingButton(
                      label: 'Next',
                      loading: _saving,
                      onPressed: _loading ||
                              _error != null ||
                              _uploadingQuestion != null
                          ? null
                          : _next)),
            ])),
      ]));

  Widget _detailsSkeleton() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          for (final height in [150.0, 64.0, 64.0, 56.0, 56.0, 56.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD5E0D0)),
                ),
              ),
            ),
        ],
      );
}
