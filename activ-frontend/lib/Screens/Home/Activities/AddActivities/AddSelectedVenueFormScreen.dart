import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../../../../api_calling/activity_setup_api.dart';
import '../../../CommonCode.dart';
import '../../../onboarding_widgets.dart';
import 'AddActivityAmenitiesScreen.dart';

class AddSelectedVenueFormScreen extends StatefulWidget {
  const AddSelectedVenueFormScreen(
      {super.key, required this.activityId, this.client});
  final String activityId;
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

  @override
  void initState() {
    super.initState();
    _api = ActivitySetupApi(client: widget.client);
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
      final activity = await _api.activity(widget.activityId);
      final questions = await _api.questions(widget.activityId);
      if (!mounted) return;
      for (final question in questions) {
        final id = question['id'].toString();
        final value = question['answer'];
        if (value != null) _answers[id] = value;
        _controllers.putIfAbsent(
            id, () => TextEditingController(text: value?.toString() ?? ''));
      }
      setState(() {
        _questions = questions;
        _activityName = (activity['name'] ?? 'Activity').toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
            widget.activityId,
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
                  activityId: widget.activityId, client: widget.client)));
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
                                  widget.activityId,
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
                for (final option in options)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(option),
                      value: (field.value ?? []).contains(option),
                      onChanged: (selected) {
                        final value = List<String>.from(field.value ?? []);
                        selected == true
                            ? value.add(option)
                            : value.remove(option);
                        field.didChange(value);
                        _answers[id] = value;
                      }),
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
    return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${question['questionText'] ?? 'Activity details'}${required ? ' *' : ''}',
              style: OnboardingStyles.body),
          const SizedBox(height: 8),
          input,
          if ((question['helperText'] ?? '').toString().isNotEmpty)
            Text(question['helperText'].toString()),
        ]));
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: getStepBarCount(4 / 6, 4, 6)),
        const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Add activity - Step 4 of 6',
                style: OnboardingStyles.body)),
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('Activity details', style: OnboardingStyles.heading)),
        if (!_loading && _error == null)
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(_activityName,
                  textAlign: TextAlign.center,
                  style: OnboardingStyles.body
                      .copyWith(fontWeight: FontWeight.w700))),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
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
}
