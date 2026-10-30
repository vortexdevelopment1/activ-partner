import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../Style/app_colors.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../../api_calling/api_request.dart';
import '../../../onboarding_widgets.dart';
import 'AddActivitySubmissionResultScreen.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';

class AddActivitySubmitReviewScreen extends StatefulWidget {
  const AddActivitySubmitReviewScreen({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.timing,
    this.client,
  });

  final String activityId;
  final String activityName;
  final Map<String, List<Map<String, String>>> timing;
  final http.Client? client;

  @override
  State<AddActivitySubmitReviewScreen> createState() => _State();
}

class _State extends State<AddActivitySubmitReviewScreen> {
  bool _saving = false;
  String _description = 'Activity details';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadActivitySummary();
  }

  Future<void> _loadActivitySummary() async {
    try {
      final api = ActivitySetupApi(client: widget.client);
      final activity = await api.activity(widget.activityId);
      api.dispose();
      if (!mounted) return;
      setState(() {
        final description = _activityDescription(activity);
        if (description.isNotEmpty) _description = description;
        final images = activity['imageUrls'];
        if (images is List && images.isNotEmpty) _imageUrl = images.first.toString();
      });
    } catch (_) {}
  }

  String _activityDescription(Map<String, dynamic> activity) {
    final answers = activity['answers'];
    if (answers is List) {
      for (final raw in answers.whereType<Map>()) {
        final questionValue = raw['question'];
        final question = questionValue is Map
                ? questionValue['question']
                : questionValue ?? raw['questionText'] ??
            (raw['partner_service_questions'] is Map
                ? raw['partner_service_questions']['question']
                : null);
        if (question.toString().trim().toLowerCase() == 'activity description') {
          final answer = raw['answer'];
          final text = answer is List ? answer.join(', ') : answer?.toString() ?? '';
          if (text.trim().isNotEmpty) return text.trim();
        }
      }
    }
    return activity['description']?.toString().trim() ?? '';
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final api = ActivitySetupApi(client: widget.client);
    try {
      await api.submit(widget.activityId, widget.timing);
      await ActivityFlowCheckpoint.clear(widget.activityId);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AddActivitySubmissionResultScreen(
            activityId: widget.activityId,
            activityName: widget.activityName,
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
      api.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await SharedPreference.addStringToSF(
          'activity_draft_resume_${widget.activityId}',
          jsonEncode(widget.timing));
      await ActivityFlowCheckpoint.markCompletedDraft(widget.activityId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AddActivitySubmissionResultScreen(
            activityId: widget.activityId,
            activityName: widget.activityName,
            savedAsDraft: true,
            returnToEditor: true,
            client: widget.client,
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to save draft progress. Please retry.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showLogo: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 8),
            child: Row(
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Submit Activity For Review', maxLines: 1,
                        style: OnboardingStyles.heading.copyWith(fontSize: 25)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.gray),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      if (_imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(_imageUrl!, width: 78, height: 78, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 78, height: 78, child: Icon(Icons.image_outlined))),
                        ),
                      if (_imageUrl != null) const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.activityName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(_description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFF9E2C), borderRadius: BorderRadius.circular(18)),
                              child: const Text('Pending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('What happens next?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _reviewSteps(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                OnboardingButton(
                  key: const Key('submit-activity-for-review'),
                  label: _saving ? 'Submitting...' : 'Submit for review',
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
                const SizedBox(height: 12),
                OnboardingButton(
                  label: 'Save as Draft',
                  outlined: true,
                  disabledForegroundColor: Colors.black,
                  onPressed: _saving ? null : _saveDraft,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewSteps() {
    const labels = [
      'ACTIV reviews\nyour activity',
      'Venue verification\ncross-check',
      'Activity\napproved',
      'Activity goes\nlive',
      'Users can\nstart booking',
    ];
    const icons = [Icons.person_outline, Icons.verified_user_outlined, Icons.business_center_outlined, Icons.language, Icons.calendar_month_outlined];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: i == 0
                        ? const SizedBox.shrink()
                        : Container(height: 2, color: const Color(0xFFD7D7D7)),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.purple, width: 2),
                    ),
                    child: Icon(icons[i], color: AppColors.purple, size: 22),
                  ),
                  Expanded(
                    child: i == labels.length - 1
                        ? const SizedBox.shrink()
                        : Container(height: 2, color: const Color(0xFFD7D7D7)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('${i + 1}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.2)),
              ],
            ),
          ),
      ],
    );
  }
}
