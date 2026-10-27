import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../Style/app_colors.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../onboarding_widgets.dart';
import 'AddActivitySubmitReviewScreen.dart';
import 'AddVenueTimingScreen.dart';
import '../../../../api_calling/api_request.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';

class AddActivityConfigureScreen extends StatefulWidget {
  const AddActivityConfigureScreen({super.key, required this.activityId,
      required this.timing, required this.activityName, this.client});
  final String activityId, activityName;
  final Map<String, dynamic> timing;
  final http.Client? client;
  @override State<AddActivityConfigureScreen> createState() => _State();
}

class _State extends State<AddActivityConfigureScreen> {
  late final ActivitySetupApi _api;
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic> _activity = {};
  @override void initState() { super.initState(); _api = ActivitySetupApi(client: widget.client); _saveInterruptedCheckpoint(); _load(); }
  @override void dispose() { _api.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final activity = await _api.activity(widget.activityId);
      final questions = await _api.questions(widget.activityId);
      if (mounted) setState(() { _activity = activity; _questions = questions; });
    } catch (_) {}
  }
  Future<void> _saveInterruptedCheckpoint() async {
    await ActivityFlowCheckpoint.save(
      activityId: widget.activityId,
      step: 'configure',
      data: {'activityName': widget.activityName, 'timing': widget.timing},
    );
  }
  void _backToPreviousAddStep() {
    // Always return to the timing step. This also handles restored sessions,
    // where Activity Management may still be underneath the recreated route.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddVenueTimingScreen(
          activityId: widget.activityId,
          client: widget.client,
        ),
      ),
    );
  }
  Widget _card(String title, Widget child) => Container(
    margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.gray), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const Divider(), child,
    ]));
  Widget _photos() {
    final urls = (_activity['imageUrls'] as List? ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return _card('Photos', urls.isEmpty ? const Text('No photos uploaded.') : Column(children: [
      for (final url in urls)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.95,
              child: Image.network(url, width: double.infinity,
                  fit: BoxFit.cover),
            ),
          ),
        ),
    ]));
  }
  @override Widget build(BuildContext context) => OnboardingScaffold(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.activityName, style: OnboardingStyles.heading),
      const SizedBox(height: 6),
      const Text('Please review activity details and proceed', style: TextStyle(fontSize: 16, color: AppColors.black1)),
    ])),
    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _photos(),
      _card('Activity Specific Details', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final q in _questions) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${q['questionText'] ?? ''}\n${q['answer'] ?? '-'}'))])),
      _card('Amenities List', Text(((_activity['amenities'] as List?) ?? []).asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n'))),
      _card('Operational Details', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in widget.timing.entries.where((e) => (e.value as List? ?? []).any((s) => s['open'] != null && s['open'] != '-'))) ...[
          Text(e.key.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final s in (e.value as List)) Text('${s['open'] ?? '-'}    ${s['close'] ?? '-'}    ₹${s['price'] ?? '-'}'),
          const Divider(),
        ],
      ])),
    ])),
    Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      Expanded(child: OnboardingButton(label: 'Back', outlined: true, onPressed: _backToPreviousAddStep)),
      const SizedBox(width: 12), Expanded(flex: 2, child: OnboardingButton(label: 'Next', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddActivitySubmitReviewScreen(activityId: widget.activityId, activityName: widget.activityName, timing: {for (final e in widget.timing.entries) e.key: (e.value as List).map((s) => Map<String, String>.from(s as Map)).toList()}, client: widget.client))))),
    ])),
  ]));
}
