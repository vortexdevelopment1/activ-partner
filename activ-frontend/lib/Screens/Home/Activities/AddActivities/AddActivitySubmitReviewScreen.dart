import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../Style/app_colors.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../../api_calling/api_request.dart';
import '../../../onboarding_widgets.dart';
import 'AddActivitySubmissionResultScreen.dart';

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

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final api = ActivitySetupApi(client: widget.client);
    try {
      await api.submit(widget.activityId, widget.timing);
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Submit Activity For Review',
                style: OnboardingStyles.heading,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.gray),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.activityName,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Pending review',
                          style: TextStyle(color: Colors.orange, fontSize: 18)),
                      const SizedBox(height: 20),
                      const Text('What happens next?',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      const Text(
                          'ACTIV will review your activity details. After approval, your activity will go live and users can start booking.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                OnboardingButton(
                  label: _saving ? 'Submitting...' : 'Submit for review',
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
                const SizedBox(height: 12),
                OnboardingButton(
                  label: 'Save as Draft',
                  outlined: true,
                  onPressed: _saving ? null : _saveDraft,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
