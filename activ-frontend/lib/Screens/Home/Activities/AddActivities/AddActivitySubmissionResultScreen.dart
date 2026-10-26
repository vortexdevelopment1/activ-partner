import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/activity_logos.dart';
import '../../../../Style/app_size.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../StringExtensions.dart';
import '../VenueActivityListScreen.dart';
import 'AddListActivityTypeScreen.dart';
import '../../../../api_calling/activity_setup_api.dart';

class AddActivitySubmissionResultScreen extends StatefulWidget {
  const AddActivitySubmissionResultScreen({super.key, this.activityId, this.savedAsDraft = false, this.activityName = 'Activity'});
  final String? activityId;
  final String activityName;
  final bool savedAsDraft;

  @override
  State<AddActivitySubmissionResultScreen> createState() =>
      _AddActivitySubmissionResultScreenState();
}

class _AddActivitySubmissionResultScreenState
    extends State<AddActivitySubmissionResultScreen> {
  String _title = 'Activity';
  String _description = 'Activity details';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _title = widget.activityName.trim().isEmpty ? 'Activity' : widget.activityName;
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      Map<String, dynamic>? value;
      if (widget.activityId != null && widget.activityId!.isNotEmpty) {
        final api = ActivitySetupApi();
        try { value = await api.activity(widget.activityId!); } finally { api.dispose(); }
      }
      if (value == null) {
        final raw = checkString(await SharedPreference.readStr('operate_value'));
        if (raw.isNotEmpty) value = jsonDecode(raw) as Map<String, dynamic>;
      }
      if (value == null) return;
      if (!mounted) return;
      setState(() {
        final serverTitle = checkString(value!['name']);
        if (serverTitle.isNotEmpty) _title = serverTitle;
        _description = checkString(value['description']);
        if (_description.isEmpty) _description = 'Ready for admin verification';
        final images = value['imageUrls'];
        if (images is List && images.isNotEmpty && images.first is String) _imageUrl = images.first as String;
      });
    } catch (_) {}
  }

  void _backToActivities() {
    CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
      context,
      const VenueActivityListScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.savedAsDraft;
    return Container(
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
                  ? SvgPicture.asset('assets/save_as_draft.svg', width: 72, height: 72)
                  : const Icon(Icons.verified, color: AppColors.purple, size: 72),
              const SizedBox(height: 8),
              Text(
                draft ? 'Activity Saved as Draft' : 'Activity Submitted Successfully!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
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
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    _draftAction(
                      iconAsset: 'assets/delete_draft.svg',
                      label: 'Discard Draft',
                      onTap: _backToActivities,
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
                      onTap: _backToActivities,
                      child: _button('Back to Activities', filled: true),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(
                        context,
                        const AddListActivityTypeScreen(),
                      ),
                      child: _button('Add Another Activity', filled: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                    ? Image.asset(activityLogoAsset(_title), fit: BoxFit.contain)
                    : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(_imageUrl!, fit: BoxFit.cover)),
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
            draft ? 'Continue editing or submit for review when ready.' : 'Within 24-48 hours',
          ),
          if (!draft) ...[
            const SizedBox(height: 12),
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
        border: Border.all(color: draft ? AppColors.red : AppColors.purple, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(draft ? Icons.info_outline : Icons.notifications_none,
              color: draft ? AppColors.red : AppColors.purple, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              draft
                  ? "Important\nYour activity is not live yet.\nIt will be visible to users only after ACTIV's Admin approves it."
                  : "What Happens next?\nWe'll notify you once your activity is approved and live.",
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
    required VoidCallback onTap,
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
                child: SvgPicture.asset(iconAsset),
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

  Widget _detailRow(String label, String value, {bool badge = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Satoshi',
              color: AppColors.black1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: badge
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9E2C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'Satoshi',
                        color: AppColors.white,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                    color: AppColors.darkBlack,
                    height: 1.35,
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
