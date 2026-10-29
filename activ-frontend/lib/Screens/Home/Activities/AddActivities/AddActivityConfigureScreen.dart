import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../Style/app_colors.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../onboarding_widgets.dart';
import 'AddActivitySubmitReviewScreen.dart';
import 'AddVenueTimingScreen.dart';
import 'AddActivityAmenitiesScreen.dart';
import 'AddSelectedVenueFormScreen.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import 'EditActivityPhotosScreen.dart';
import '../../../../Utills/activity_question_visibility.dart';

class AddActivityConfigureScreen extends StatefulWidget {
  const AddActivityConfigureScreen({super.key, required this.activityId,
      required this.timing, required this.activityName, this.client,
      this.hasPreviousTimingRoute = false});
  final String activityId, activityName;
  final Map<String, dynamic> timing;
  final http.Client? client;
  final bool hasPreviousTimingRoute;
  @override State<AddActivityConfigureScreen> createState() => _State();
}

class _State extends State<AddActivityConfigureScreen> {
  late final ActivitySetupApi _api;
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic> _activity = {};
  bool _loading = true, _editingPhotos = false;
  String? _loadError;
  bool _leaving = false;
  @override void initState() { super.initState(); _api = ActivitySetupApi(client: widget.client); _saveInterruptedCheckpoint(); _load(); }
  @override void dispose() { _api.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final activity = await _api.activity(widget.activityId);
      if (!mounted) return;
      setState(() { _activity = activity; _loadError = null; });
      final questions = (await _api.questions(widget.activityId))
          .where((question) => !isRemovedActivityQuestion(question['questionText'])).toList();
      if (mounted) setState(() { _activity = activity; _questions = questions; });
    } catch (_) {
      if (mounted && _activity.isEmpty) setState(() => _loadError = 'Unable to load activity photos. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPhotos() async {
    if (_editingPhotos || _loading || _loadError != null) return;
    setState(() => _editingPhotos = true);
    try {
      final urls = await Navigator.push<List<String>>(context, MaterialPageRoute<List<String>>(
        builder: (_) => EditActivityPhotosScreen(
          activityId: widget.activityId, activityName: widget.activityName,
          imageUrls: (_activity['imageUrls'] as List? ?? []).map((url) => url.toString()).toList(),
          client: widget.client,
        ),
      ));
      if (!mounted) return;
      if (urls != null) setState(() => _activity = {..._activity, 'imageUrls': urls});
      await _saveInterruptedCheckpoint();
    } finally {
      if (mounted) setState(() => _editingPhotos = false);
    }
  }
  Future<void> _saveInterruptedCheckpoint() async {
    if (ActivityFlowCheckpoint.restoring) return;
    await ActivityFlowCheckpoint.save(
      activityId: widget.activityId,
      step: 'configure',
      data: {'activityName': widget.activityName, 'timing': widget.timing},
    );
  }
  void _backToPreviousAddStep() {
    if (_leaving) return;
    _leaving = true;
    if (widget.hasPreviousTimingRoute && Navigator.of(context).canPop()) {
      Navigator.pop(context);
      return;
    }
    // A restored review has no timing route underneath it. Reconstruct that
    // single previous step rather than popping to Activity Management or blank.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddVenueTimingScreen(
          activityId: widget.activityId,
          initialTiming: widget.timing,
          client: widget.client,
        ),
      ),
    );
  }
  Widget _card(String title, Widget child, {VoidCallback? onEdit}) => Container(
    margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.gray), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        if (onEdit != null) TextButton.icon(key: Key(title == 'Photos'
            ? 'edit-activity-photos'
            : 'edit-${title.toLowerCase().replaceAll(' ', '-')}'),
          onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
      ]),
      const Divider(), child,
    ]));
  Widget _photos() {
    final urls = (_activity['imageUrls'] as List? ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return _card('Photos', _loading ? const Center(child: CircularProgressIndicator())
      : _loadError != null ? Column(children: [Text(_loadError!), TextButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Retry'))])
      : urls.isEmpty ? const Text('No photos uploaded.') : Column(children: [
      for (final url in urls)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.95,
              child: Image.network(url, width: double.infinity,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined))),
            ),
          ),
        ),
    ]), onEdit: _loading || _editingPhotos || _loadError != null ? null : _editPhotos);
  }

  Map<String, dynamic> get _timingForEdit => {
    for (final entry in widget.timing.entries)
      entry.key: (entry.value as List)
          .map((slot) => Map<String, String>.from(slot as Map))
          .toList(),
  };

  void _editDetails() {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AddSelectedVenueFormScreen(
        activityId: widget.activityId,
        client: widget.client,
      ),
    ));
  }

  void _editAmenities() {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AddActivityAmenitiesScreen(
        activityId: widget.activityId,
        client: widget.client,
      ),
    ));
  }

  void _editTiming() {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AddVenueTimingScreen(
        activityId: widget.activityId,
        initialTiming: _timingForEdit,
        client: widget.client,
      ),
    ));
  }
  @override Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) { if (!didPop) _backToPreviousAddStep(); },
    child: OnboardingScaffold(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.activityName, style: OnboardingStyles.heading),
      const SizedBox(height: 6),
      const Text('Please review activity details and proceed', style: TextStyle(fontSize: 16, color: AppColors.black1)),
    ])),
    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
      _photos(),
      _card('Activity Specific Details', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final q in _questions) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${q['questionText'] ?? ''}\n${q['answer'] ?? '-'}'))]), onEdit: _editDetails),
      _card('Amenities List', Text(((_activity['amenities'] as List?) ?? []).asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')), onEdit: _editAmenities),
      _card('Operational Details', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in widget.timing.entries.where((e) => (e.value as List? ?? []).any((s) => s['open'] != null && s['open'] != '-'))) ...[
          Text(e.key.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final s in (e.value as List)) Builder(builder: (_) {
            final price = double.tryParse('${s['price'] ?? ''}');
            final discounted = double.tryParse('${s['discountedPrice'] ?? ''}');
            final percent = price != null && price > 0 && discounted != null
                ? ((price - discounted) / price * 100).round() : 0;
            return Text('${s['open'] ?? '-'}    ${s['close'] ?? '-'}    ₹${s['discountedPrice'] ?? s['price'] ?? '-'}'
                '${percent > 0 ? '  ($percent% OFF)' : ''}');
          }),
          const Divider(),
        ],
      ]), onEdit: _editTiming),
    ])),
    Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      Expanded(child: OnboardingButton(label: 'Back', outlined: true, onPressed: _backToPreviousAddStep)),
      const SizedBox(width: 12), Expanded(flex: 2, child: OnboardingButton(label: 'Next', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddActivitySubmitReviewScreen(activityId: widget.activityId, activityName: widget.activityName, timing: {for (final e in widget.timing.entries) e.key: (e.value as List).map((s) => Map<String, String>.from(s as Map)).toList()}, client: widget.client))))),
    ])),
  ])));
}
