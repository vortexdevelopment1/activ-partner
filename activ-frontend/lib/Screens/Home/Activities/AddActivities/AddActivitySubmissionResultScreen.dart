import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../../../../Style/app_colors.dart';
import '../../../../Style/activity_logos.dart';
import '../../../../Style/app_size.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../StringExtensions.dart';
import '../VenueActivityListScreen.dart';
import 'AddListActivityTypeScreen.dart';
import 'AddActivitySubmitReviewScreen.dart';
import 'AddSelectedVenueFormScreen.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import '../../../../Utills/activity_image_draft_store.dart';
import '../../../../Utills/activity_resume_navigator.dart';

class AddActivitySubmissionResultScreen extends StatefulWidget {
  const AddActivitySubmissionResultScreen(
      {super.key,
      this.activityId,
      this.savedAsDraft = false,
      this.activityName = 'Activity',
      this.returnToEditor = false,
      this.client});
  final String? activityId;
  final String activityName;
  final bool savedAsDraft;
  final bool returnToEditor;
  final http.Client? client;

  @override
  State<AddActivitySubmissionResultScreen> createState() =>
      _AddActivitySubmissionResultScreenState();
}

class _AddActivitySubmissionResultScreenState
    extends State<AddActivitySubmissionResultScreen> {
  String _title = 'Activity';
  String _description = 'Activity details';
  String? _imageUrl;
  bool _resuming = false;
  bool _discarding = false;

  @override
  void initState() {
    super.initState();
    _title =
        widget.activityName.trim().isEmpty ? 'Activity' : widget.activityName;
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      Map<String, dynamic>? value;
      if (widget.activityId != null && widget.activityId!.isNotEmpty) {
        final api = ActivitySetupApi(client: widget.client);
        try {
          value = await api.activity(widget.activityId!);
        } finally {
          api.dispose();
        }
      }
      if (value == null) {
        final raw =
            checkString(await SharedPreference.readStr('operate_value'));
        if (raw.isNotEmpty) value = jsonDecode(raw) as Map<String, dynamic>;
      }
      if (value == null) return;
      if (!mounted) return;
      setState(() {
        final serverTitle = checkString(value!['name']);
        if (serverTitle.isNotEmpty) _title = serverTitle;
        _description = _activityDescription(value);
        if (_description.isEmpty) _description = 'Ready for admin verification';
        final images = value['imageUrls'];
        if (images is List && images.isNotEmpty && images.first is String)
          _imageUrl = images.first as String;
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
    return checkString(activity['description']);
  }

  void _backToActivities() {
    CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
      context,
      VenueActivityListScreen(client: widget.client),
    );
  }

  void _addAnotherActivity() {
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute(
          builder: (_) => VenueActivityListScreen(client: widget.client)),
      (_) => false,
    );
    navigator.push<void>(MaterialPageRoute(
        builder: (_) => AddListActivityTypeScreen(client: widget.client)));
  }

  Future<void> _continueEditing() async {
    if (_resuming || _discarding) return;
    final id = widget.activityId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'This draft is missing its activity ID. Reopen it from Activities.')));
      return;
    }
    setState(() => _resuming = true);
    try {
      final checkpoint = await ActivityFlowCheckpoint.read(id);
      if (checkpoint != null) {
        await ActivityResumeNavigator.open(context, checkpoint, widget.client);
        return;
      }
      final raw = await SharedPreference.readStr('activity_draft_resume_$id');
      Map<String, List<Map<String, String>>>? timing;
      if (raw != null && raw.isNotEmpty) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        timing = saved.map((day, slots) => MapEntry(
            day,
            (slots as List)
                .map((slot) => Map<String, String>.from(slot as Map))
                .toList()));
      }
      if (!mounted) return;
      if (timing != null) {
        await ActivityResumeNavigator.open(
          context,
          ActivityFlowCheckpoint(
            activityId: id,
            step: 'configure',
            data: {'activityName': _title, 'timing': timing},
            interrupted: false,
            updatedAt: DateTime.now(),
          ),
          widget.client,
        );
      } else {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AddSelectedVenueFormScreen(
                activityId: id, client: widget.client),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to resume this draft. Please retry.')));
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  Future<void> _discardDraft() async {
    if (_discarding || _resuming) return;
    final id = widget.activityId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'This draft is missing its activity ID. Reopen it from Activities.')));
      return;
    }
    setState(() => _discarding = true);
    final api = ActivitySetupApi(client: widget.client);
    try {
      await api.discardDraft(id);
      // A local checkpoint must never prevent navigation after server removal.
      try {
        await SharedPreference.remove('activity_draft_resume_$id');
        await ActivityFlowCheckpoint.clear(id);
        await ActivityImageDraftStore.clear(id);
        if (await SharedPreference.readStr('activity_current_draft_id') == id) {
          await SharedPreference.remove('activity_current_draft_id');
          await SharedPreference.remove('operate_value');
        }
      } catch (_) {}
      if (mounted) _backToActivities();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to discard this draft. Please retry.')));
    } finally {
      api.dispose();
      if (mounted) setState(() => _discarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.savedAsDraft;
    return PopScope(
        canPop: !_discarding,
        child: Container(
          decoration: context.getYellowGradient,
          child: SafeArea(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      children: [
                        draft
                            ? SvgPicture.asset('assets/save_as_draft.svg',
                                width: 72, height: 72)
                            : SvgPicture.asset('assets/success_purple.svg',
                                width: 72, height: 72),
                        const SizedBox(height: 8),
                        Text(
                          draft
                              ? 'Activity Saved as Draft'
                              : 'Activity Submitted Successfully!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Satoshi',
                            color: AppColors.darkBlack,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          draft
                              ? 'Your activity has been saved as a draft. You can complete and submit it for review anytime.'
                              : "Your activity has been submitted for ACTIV's admin verification",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Satoshi',
                            color: AppColors.black1,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _activityCard(draft),
                        const SizedBox(height: 22),
                        _noticeCard(draft),
                        if (draft) ...[
                          const SizedBox(height: 18),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'You can now',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkBlack,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _draftAction(
                                iconAsset: 'assets/confirm_editing.svg',
                                label: 'Continue Editing',
                                onTap: _discarding ? null : _continueEditing,
                              ),
                              const SizedBox(width: 12),
                              _draftAction(
                                iconAsset: 'assets/delete_draft.svg',
                                label: _discarding
                                    ? 'Discarding...'
                                    : 'Discard Draft',
                                loading: _discarding,
                                onTap: _discarding ? null : _discardDraft,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _discarding ? null : _backToActivities,
                          child: _button('Back to Activities', filled: true),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _discarding ? null : _addAnotherActivity,
                          child: _button('Add Another Activity', filled: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _activityCard(bool draft) {
    final now = DateTime.now();
    final timestamp =
        '${now.day.toString().padLeft(2, '0')} ${_month(now.month)} ${now.year}, ${TimeOfDay.fromDateTime(now).format(context)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1FD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _imageUrl == null
                    ? Image.asset(activityLogoAsset(_title),
                        fit: BoxFit.contain)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(_imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.isEmpty ? 'Activity' : _title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontFamily: 'Satoshi',
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                        color: AppColors.hintColor,
                      ),
                    ),
                    if (draft) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Draft',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Satoshi',
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.gray),
          const SizedBox(height: 8),
          _detailRow(draft ? 'Created On' : 'Submitted On', timestamp),
          const SizedBox(height: 8),
          _detailRow(
            draft ? "What's Next" : 'Estimated Review Time',
            draft
                ? 'Continue editing or submit for\nreview when you’re ready.'
                : 'Within 24-48 hours',
            valueLeftAligned: draft,
          ),
          if (!draft) ...[
            const SizedBox(height: 8),
            _detailRow('Current Status', 'Pending Approval', badge: true),
          ],
        ],
      ),
    );
  }

  Widget _noticeCard(bool draft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: draft ? AppColors.red : AppColors.purple, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(draft ? Icons.info_outline : Icons.notifications_none,
              color: draft ? AppColors.red : AppColors.purple, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: draft ? 'Important\n' : 'What Happens next?\n',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: draft
                      ? "Your activity is not live yet.\nIt will be visible to users only after ACTIV's Admin approves it."
                      : "We'll notify you once your activity is approved and live.",
                ),
              ]),
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Satoshi',
                color: draft ? AppColors.red : AppColors.purple,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftAction({
    required String iconAsset,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.purple, width: 1.0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : SvgPicture.asset(iconAsset),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Satoshi',
                color: AppColors.black1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool badge = false, bool valueLeftAligned = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Satoshi',
              color: AppColors.black1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: badge
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9E2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Satoshi',
                        color: AppColors.white,
                      ),
                    ),
                  ),
                )
              : Transform.translate(
                  offset: Offset(valueLeftAligned ? 6 : 0, 0),
                  child: Text(
                    value,
                    textAlign:
                        valueLeftAligned ? TextAlign.left : TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Satoshi',
                      color: AppColors.darkBlack,
                      height: 1.35,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _button(String label, {required bool filled}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: filled ? AppColors.black : AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.black, width: 1.3),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Satoshi',
            color: filled ? AppColors.yellow : AppColors.black,
          ),
        ),
      ),
    );
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
