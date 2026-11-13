import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../activity_details_form.dart';

import '../../../../api_calling/activity_setup_api.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import 'AddActivityAmenitiesScreen.dart';

class AddActivityDetailsScreen extends StatefulWidget {
  const AddActivityDetailsScreen({
    super.key,
    required this.activityId,
    this.initialActivity,
    this.initialQuestions,
    this.client,
    this.isEdit = false,
  });

  final String activityId;
  final Map<String, dynamic>? initialActivity;
  final List<Map<String, dynamic>>? initialQuestions;
  final http.Client? client;
  final bool isEdit;

  @override
  State<AddActivityDetailsScreen> createState() => _AddActivityDetailsScreenState();
}

class _AddActivityDetailsScreenState extends State<AddActivityDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ActivitySetupApi _api;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _activityName = 'Activity';
  String _bookingType = 'Single booking';
  List<Map<String, dynamic>> _questions = [];
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selectedUnits = {};

  @override
  void initState() {
    super.initState();
    _api = ActivitySetupApi(client: widget.client);
    if (widget.activityId.isNotEmpty && !ActivityFlowCheckpoint.restoring) {
      ActivityFlowCheckpoint.save(activityId: widget.activityId, step: 'details');
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
      Map<String, dynamic> activity;
      List<Map<String, dynamic>> questions;

      if (widget.initialActivity != null && widget.initialQuestions != null) {
        activity = widget.initialActivity!;
        questions = widget.initialQuestions!;
      } else {
        final results = await Future.wait<dynamic>([
          _api.activity(widget.activityId),
          _api.questions(widget.activityId),
        ]);
        activity = results[0] as Map<String, dynamic>;
        questions = results[1] as List<Map<String, dynamic>>;
      }

      _activityName = (activity['name'] ?? activity['title'] ?? 'Activity').toString();
      final category = activity['category'];
      _bookingType = activity['bookingType']?.toString() ?? (category is Map ? category['type']?.toString() : null) ?? '';

      _questions = questions;

      for (final q in _questions) {
        final id = q['id'].toString();
        final rawAns = q['answer'];
        final type = (q['questionType'] ?? '').toString().toLowerCase();
        final qText = (q['questionText'] ?? '').toString().toLowerCase();

        // Initial answer
        dynamic ans = rawAns;
        if (ans == null && (qText.contains('activity description') || qText.contains('description'))) {
          ans = activity['description'];
        }

        if (type == 'number_stepper') {
          int intVal = 1;
          if (ans != null) {
            intVal = int.tryParse(ans.toString()) ?? 1;
          } else {
            if (qText.contains('batch') || qText.contains('capacity')) {
              intVal = 25;
            } else {
              intVal = 1;
            }
          }
          _answers[id] = intVal;
        } else if (type == 'radio') {
          final options = _getOptions(q['options']);
          if (ans != null && options.contains(ans.toString())) {
            _answers[id] = ans.toString();
          } else if (options.isNotEmpty) {
            _answers[id] = options.first;
          }
        } else if (type == 'select') {
          final options = _getOptions(q['options']);
          if (ans != null && options.contains(ans.toString())) {
            _answers[id] = ans.toString();
          } else if (options.isNotEmpty) {
            _answers[id] = options.first;
          }
        } else if (type == 'multiselect' || type == 'checkbox') {
          if (ans is List) {
            _answers[id] = ans.map((e) => e.toString()).toList();
          } else if (ans is String && ans.isNotEmpty) {
            _answers[id] = [ans];
          } else {
            _answers[id] = <String>[];
          }
        } else {
          final strVal = ans?.toString() ?? '';
          _answers[id] = strVal;
          _controllers[id] = TextEditingController(text: strVal);
        }

        final unit = q['unit']?.toString() ?? '';
        if (unit.isNotEmpty) {
          _selectedUnits[id] = unit;
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<String> _getOptions(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> _save() async {
    if (_saving || (_formKey.currentState != null && !_formKey.currentState!.validate())) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      for (final q in _questions) {
        final id = q['id'].toString();
        final type = (q['questionType'] ?? '').toString().toLowerCase();

        if (type == 'number_stepper') {
          payload[id] = _answers[id] ?? 1;
        } else if (type == 'radio' || type == 'select') {
          if (_answers[id] != null) {
            payload[id] = _answers[id];
          }
        } else if (type == 'multiselect' || type == 'checkbox') {
          final list = _answers[id];
          if (list is List && list.isNotEmpty) {
            payload[id] = list;
          }
        } else {
          final text = _controllers[id]?.text.trim() ?? '';
          if (text.isNotEmpty) {
            final number = num.tryParse(text);
            final unit = q['unit']?.toString() ?? '';
            payload[id] = type == 'number' && number != null
                ? activityConvertUnit(number, _selectedUnits[id] ?? unit, unit) : text;
          }
        }
      }

      if (payload.isNotEmpty) { await _api.saveAnswers(widget.activityId, payload); }
      if (!mounted) return;
      if (widget.isEdit) {
        Navigator.pop(context, true);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AddActivityAmenitiesScreen(
              activityId: widget.activityId,
              client: widget.client,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ActivityDetailsLayout(
    currentStep: widget.isEdit ? null : 4,
    totalSteps: widget.isEdit ? null : 6,
    buttonLabel: widget.isEdit ? 'Save Changes' : 'Next',
    saving: _saving,
    onContinue: _loading || _error != null ? null : _save,
    child: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]))
      : Form(key: _formKey, child: ListView(
          padding: EdgeInsets.fromLTRB(activityDetailsGutter(context), 0, activityDetailsGutter(context), 80),
          children: [
            ActivityDetailsHeading(name: _activityName, bookingType: _bookingType),
            if (_questions.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No extra details needed')),
            for (final question in _questions) _buildQuestionItem(question),
          ],
        )),
  );

  Key _getKeyForQuestion(Map<String, dynamic> q) {
    final text = (q['questionText'] ?? '').toString().toLowerCase();
    final id = q['id'].toString();
    if (id == 'description' || text.contains('description')) {
      return const ValueKey('activity-question-description');
    }
    if (id == 'courts' || text.contains('court') || text.contains('pool')) {
      return const ValueKey('activity-question-courts');
    }
    return ValueKey('activity-question-$id');
  }

  Widget _buildQuestionItem(Map<String, dynamic> q) {
    final id = q['id'].toString();
    final unit = q['unit']?.toString() ?? '';
    final type = (q['questionType'] ?? 'text').toString().toLowerCase();
    return ActivityQuestionInput(
      label: (q['questionText'] ?? '').toString(), type: type,
      inputKey: _getKeyForQuestion(q), controller: _controllers[id],
      answer: _answers[id], required: q['isRequired'] == true,
      options: _getOptions(q['options']), placeholder: activityQuestionPlaceholder(_activityName, (q['questionText'] ?? '').toString(), (q['placeholder'] ?? '').toString()),
      helper: (q['helperText'] ?? '').toString(),
      maxLength: int.tryParse('${q['maxLength']}'), minLength: int.tryParse('${q['minLength']}'),
      unit: unit, selectedUnit: _selectedUnits[id],
      onChanged: (value) => setState(() => _answers[id] = value),
      onUnitChanged: (next) {
        final controller = _controllers[id]!;
        final value = num.tryParse(controller.text);
        if (value != null) {
          final converted = activityConvertUnit(value, _selectedUnits[id] ?? unit, next);
          controller.text = converted.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
        }
        setState(() => _selectedUnits[id] = next);
      },
    );
  }
}
