import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../api_calling/activity_setup_api.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import '../../../../Utills/activity_question_visibility.dart';
import '../../../CommonCode.dart';
import '../../../onboarding_widgets.dart';
import 'AddActivityAmenitiesScreen.dart';

class AddSelectedVenueFormScreen extends StatefulWidget {
  const AddSelectedVenueFormScreen({
    super.key,
    this.activityId = '',
    this.activityIdFuture,
    this.onActivityReady,
    this.initialActivity,
    this.initialQuestions,
    this.client,
  });

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
  final _descriptionController = TextEditingController();
  final _answers = <String, dynamic>{};
  late final ActivitySetupApi _api;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _activityName = 'Badminton';
  String _resolvedActivityId = '';
  String? _descriptionQuestionId;
  bool _isExampleOpen = true;

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
    _descriptionController.dispose();
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
    questions = questions
        .where((question) => !isRemovedActivityQuestion(question['questionText']))
        .toList();

    _activityName = (activity['name'] ?? activity['title'] ?? 'Badminton').toString();

    // Preserve existing answers
    for (final q in questions) {
      final id = q['id'].toString();
      final val = q['answer'];
      if (val != null) _answers[id] = val;
    }

    // Identify description question ID & pre-populate description
    String existingDesc = (activity['description'] ?? '').toString();
    for (final q in questions) {
      final text = (q['questionText'] ?? '').toString().toLowerCase();
      if (text.contains('activity description') || text.contains('description')) {
        _descriptionQuestionId = q['id']?.toString();
        final ans = q['answer']?.toString();
        if (ans != null && ans.trim().isNotEmpty) {
          existingDesc = ans;
        }
        break;
      }
    }

    if (_descriptionQuestionId == null && questions.isNotEmpty) {
      _descriptionQuestionId = questions.first['id']?.toString();
    }
    _descriptionQuestionId ??= 'description';

    _descriptionController.text = existingDesc;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _next() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final descText = _descriptionController.text.trim();
      final descId = _descriptionQuestionId ?? 'description';
      _answers[descId] = descText;

      if (_answers.isNotEmpty) {
        await _api.saveAnswers(
          _resolvedActivityId,
          Map.fromEntries(
            _answers.entries.where((entry) =>
                entry.value != null &&
                entry.value.toString().trim().isNotEmpty &&
                (entry.value is! List || (entry.value as List).isNotEmpty)),
          ),
        );
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AddActivityAmenitiesScreen(
            activityId: _resolvedActivityId,
            client: widget.client,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getExampleText(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.contains('badminton')) {
      return 'We have 3 indoor badminton courts with synthetic flooring, quality rackets available on rent, changing rooms, and coaching for beginners. Suitable for friends, families, and players of all levels. We also host weekend tournaments and corporate bookings.';
    } else if (lower.contains('tennis')) {
      return 'We have 2 synthetic turf tennis courts with floodlights, quality rackets and balls available on rent, changing rooms, and coaching for beginners. Suitable for friends, families, and players of all levels. We also host weekend tournaments and corporate bookings.';
    } else if (lower.contains('cricket') || lower.contains('box cricket')) {
      return 'We offer 2 high-grade turf cricket nets with floodlights, bowling machines, bats, pads and balls available on rent. Suitable for team practice, coaching, and friendly weekend matches.';
    } else if (lower.contains('football') || lower.contains('turf')) {
      return 'We offer a FIFA-standard 5-a-side artificial turf football pitch with floodlights, bibs, balls, changing rooms, and seating. Suitable for tournaments and casual matches.';
    } else if (lower.contains('swim')) {
      return 'We offer a semi-Olympic size temperature-controlled swimming pool with clean filtered water, shower cubicles, lockers, and certified lifeguards on duty. Coaching available for all levels.';
    } else if (lower.contains('basketball')) {
      return 'We have 2 full-size indoor wooden basketball courts with height-adjustable hoops, lockers, and coaching sessions. Suitable for friends, families, and corporate tournaments.';
    } else {
      return 'We have 3 indoor ${name.toLowerCase()} courts with synthetic flooring, quality equipment available on rent, changing rooms, and coaching for beginners. Suitable for friends, families, and players of all levels. We also host weekend tournaments and corporate bookings.';
    }
  }

  String _getHintText(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.contains('badminton')) {
      return 'Example: We have 3 indoor badminton courts with synthetic flooring, quality rackets available on rent, changing rooms, and coaching for beginners. Suitable for friends, families, and players of all levels.';
    } else if (lower.contains('tennis')) {
      return 'Example: We have 2 synthetic turf tennis courts with floodlights, quality rackets and balls available on rent, changing rooms, and coaching for beginners. Suitable for friends, families, and players of all levels.';
    } else {
      return 'Example: We have 3 indoor ${name.toLowerCase()} courts with synthetic flooring, quality equipment available on rent, changing rooms, and coaching for beginners. Suitable for friends, families, and players of all levels.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: getStepBarCount(4 / 6, 4, 6),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activityName,
                    style: OnboardingStyles.heading.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tell us about your activity',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      color: Color(0xFF555555),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : Form(
                        key: _form,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            const SizedBox(height: 4),
                            // Label with info icon and speech bubble tooltip
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text.rich(
                                      TextSpan(
                                        text: 'Activity Description',
                                        style: TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F1F1F),
                                        ),
                                        children: [
                                          TextSpan(
                                            text: ' *',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Color(0xFF777777),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: _SpeechBubble(
                                    text:
                                        "Share the details you want players to know. We'll help convert your description into clear English.",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Textarea container with placeholder & corner resize handle
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    key: const ValueKey('activity-description-field'),
                                    controller: _descriptionController,
                                    maxLines: 7,
                                    minLines: 6,
                                    style: const TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 14,
                                      color: Color(0xFF1F1F1F),
                                      height: 1.45,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _getHintText(_activityName),
                                      hintStyle: const TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 13.5,
                                        color: Color(0xFF9CA3AF),
                                        height: 1.45,
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter an activity description';
                                      }
                                      return null;
                                    },
                                  ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                                      child: CustomPaint(
                                        size: const Size(12, 12),
                                        painter: _ResizeHandlePainter(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Card 1: Need an idea?
                            Container(
                              margin: const EdgeInsets.only(top: 18),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF9E7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF3E7BE),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline,
                                    color: Color(0xFF8BBF2B),
                                    size: 26,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Need an idea?',
                                          style: TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1F1F1F),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Write in Hindi , Hinglish, or English. Mention your facilities, equipment, coaching, who can join, and what makes your venue special.',
                                          style: TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontSize: 13,
                                            color: Color(0xFF555555),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Card 2: See an example for [Activity] (Accordion)
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF6E5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD6E8CA),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => setState(
                                        () => _isExampleOpen = !_isExampleOpen),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.article_outlined,
                                          color: Color(0xFF2C3E50),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'See an example for $_activityName',
                                            style: const TextStyle(
                                              fontFamily: 'Satoshi',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1F1F1F),
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          _isExampleOpen
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: const Color(0xFF1F1F1F),
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isExampleOpen) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE2EFE0),
                                        ),
                                      ),
                                      child: Text(
                                        _getExampleText(_activityName),
                                        style: const TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 13,
                                          color: Color(0xFF444444),
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OnboardingButton(
                    label: 'Back',
                    outlined: true,
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: OnboardingButton(
                    label: 'Next',
                    loading: _saving,
                    onPressed: _saving || _loading || _error != null ? null : _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(6, 12),
          painter: _TrianglePointerPainter(),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2124),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 11,
                color: Colors.white,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrianglePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2124)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResizeHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8BFC8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width, size.height - 4),
      Offset(size.width - 4, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - 8),
      Offset(size.width - 8, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
