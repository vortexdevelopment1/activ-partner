import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../StringExtensions.dart';
import '../VenueActivityListScreen.dart';
import 'AddListActivityTypeScreen.dart';

class AddActivitySubmissionResultScreen extends StatefulWidget {
  const AddActivitySubmissionResultScreen({super.key, this.savedAsDraft = false});
  final bool savedAsDraft;

  @override
  State<AddActivitySubmissionResultScreen> createState() =>
      _AddActivitySubmissionResultScreenState();
}

class _AddActivitySubmissionResultScreenState
    extends State<AddActivitySubmissionResultScreen> {
  String _title = 'Activity';
  String _description = 'Activity details';

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final raw = checkString(await SharedPreference.readStr('operate_value'));
    if (raw.isEmpty) return;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _title = checkString(value['title']);
        _description = _title.isEmpty ? 'Activity details' : 'Ready for admin verification';
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
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            children: [
              Icon(
                draft ? Icons.inventory_2 : Icons.verified,
                color: AppColors.purple,
                size: 96,
              ),
              const SizedBox(height: 24),
              Text(
                draft ? 'Activity Saved as Draft' : 'Activity Submitted Successfully!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'FontSemiBold',
                  color: AppColors.darkBlack,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                draft
                    ? 'Your activity has been saved as a draft. You can complete and submit it for review anytime.'
                    : "Your activity has been submitted for ACTIV's admin verification",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppSize.size_16,
                  fontFamily: 'FontRegular',
                  color: AppColors.black1,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              _activityCard(draft),
              const SizedBox(height: 22),
              _noticeCard(draft),
              const SizedBox(height: 80),
              InkWell(
                onTap: _backToActivities,
                child: _button('Back to Activities', filled: true),
              ),
              const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _activityCard(bool draft) {
    final now = DateTime.now();
    final timestamp =
        '${now.day.toString().padLeft(2, '0')} ${_month(now.month)} ${now.year}, ${TimeOfDay.fromDateTime(now).format(context)}';
    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1FD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.sports_tennis, color: AppColors.purple, size: 44),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.isEmpty ? 'Activity' : _title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _description,
                      style: const TextStyle(
                        fontSize: AppSize.size_16,
                        fontFamily: 'FontRegular',
                        color: AppColors.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.gray),
          const SizedBox(height: 12),
          _detailRow(draft ? 'Created On' : 'Submitted On', timestamp),
          const SizedBox(height: 12),
          _detailRow(
            draft ? "What's Next" : 'Estimated Review Time',
            draft ? "Continue editing or submit for review when you're ready." : 'Within 24-48 hours',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: draft ? AppColors.red : AppColors.purple, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(draft ? Icons.info_outline : Icons.notifications_none,
              color: draft ? AppColors.red : AppColors.purple, size: 42),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              draft
                  ? "Important\nYour activity is not live yet. It will be visible to users only after ACTIV's Admin approves it."
                  : "What Happens next?\nWe'll notify you once your activity is approved and live.",
              style: TextStyle(
                fontSize: AppSize.size_16,
                fontFamily: 'FontSemiBold',
                color: draft ? AppColors.red : AppColors.purple,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool badge = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppSize.size_15,
              fontFamily: 'FontRegular',
              color: AppColors.black1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
                        fontFamily: 'FontSemiBold',
                        color: AppColors.white,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: AppSize.size_15,
                    fontFamily: 'FontSemiBold',
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
      height: 58,
      decoration: BoxDecoration(
        color: filled ? AppColors.black : AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.black, width: 1.3),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppSize.size_18,
            fontFamily: 'FontBold',
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
