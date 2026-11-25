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
  const AddActivityConfigureScreen(
      {super.key,
      required this.activityId,
      required this.timing,
      required this.activityName,
      this.client,
      this.hasPreviousTimingRoute = false});
  final String activityId, activityName;
  final Map<String, dynamic> timing;
  final http.Client? client;
  final bool hasPreviousTimingRoute;
  @override
  State<AddActivityConfigureScreen> createState() => _State();
}

class _State extends State<AddActivityConfigureScreen> {
  late final ActivitySetupApi _api;
  late Map<String, dynamic> _timing;
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic> _activity = {};
  bool _loading = true, _editingPhotos = false;
  String? _loadError;
  bool _leaving = false;

  static const List<String> _shortDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const Map<String, String> _dayMap = {
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
    'Sat': 'Saturday',
    'Sun': 'Sunday',
  };

  List<dynamic> _getSlotsForDay(String shortDay) {
    final fullDay = _dayMap[shortDay] ?? shortDay;
    final val = _timing[fullDay] ?? _timing[shortDay];
    return (val is List) ? val : [];
  }

  bool _isDayActive(String shortDay) {
    final slots = _getSlotsForDay(shortDay);
    return slots.any((s) =>
        s is Map &&
        s['open'] != null &&
        s['open'] != '-' &&
        s['open'].toString().trim().isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _timing = {
      for (final entry in widget.timing.entries)
        entry.key: (entry.value as List)
            .map((slot) => Map<String, String>.from(slot as Map))
            .toList(),
    };
    _api = ActivitySetupApi(client: widget.client);
    _saveInterruptedCheckpoint();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final activity = await _api.activity(widget.activityId);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _loadError = null;
      });
      final questions = (await _api.questions(widget.activityId))
          .where((question) =>
              !isRemovedActivityQuestion(question['questionText']))
          .toList();
      if (mounted)
        setState(() {
          _activity = activity;
          _questions = questions;
        });
    } catch (_) {
      if (mounted && _activity.isEmpty)
        setState(
            () => _loadError = 'Unable to load activity photos. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPhotos() async {
    if (_editingPhotos || _loading || _loadError != null) return;
    setState(() => _editingPhotos = true);
    try {
      final urls = await Navigator.push<List<String>>(
          context,
          MaterialPageRoute<List<String>>(
            builder: (_) => EditActivityPhotosScreen(
              activityId: widget.activityId,
              activityName: widget.activityName,
              imageUrls: (_activity['imageUrls'] as List? ?? [])
                  .map((url) => url.toString())
                  .toList(),
              client: widget.client,
            ),
          ));
      if (!mounted) return;
      if (urls != null)
        setState(() => _activity = {..._activity, 'imageUrls': urls});
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
      data: {'activityName': widget.activityName, 'timing': _timing},
    );
  }

  void _backToPreviousAddStep() {
    if (_leaving) return;
    _leaving = true;
    ActivityFlowCheckpoint.save(
      activityId: widget.activityId,
      step: 'timing',
      data: {'timing': _timing},
    );
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
          initialTiming: _timing,
          client: widget.client,
        ),
      ),
    );
  }

  Widget _card(String title, Widget child,
          {VoidCallback? onEdit, double titleFontSize = 17}) =>
      Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.gray),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700))),
          if (onEdit != null)
            TextButton.icon(
                key: Key(title == 'Photos'
                    ? 'edit-activity-photos'
                    : 'edit-${title.toLowerCase().replaceAll(' ', '-')}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit')),
        ]),
        const Divider(),
        child,
      ]));
  Widget _photos() {
    final urls = (_activity['imageUrls'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return _card(
        'Photos',
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Column(children: [
                    Text(_loadError!),
                    TextButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        child: const Text('Retry'))
                  ])
                : urls.isEmpty
                    ? const Text('No photos uploaded.')
                    : Column(children: [
                        for (final url in urls)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1.95,
                                child: Image.network(url,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.image_outlined))),
                              ),
                            ),
                          ),
                      ]),
        onEdit: _loading || _editingPhotos || _loadError != null
            ? null
            : _editPhotos);
  }

  void _editDetails() async {
    final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => AddSelectedVenueFormScreen(
            activityId: widget.activityId,
            client: widget.client,
            isEdit: true,
          ),
        ));
    if (updated == true && mounted) {
      _load();
    }
  }

  void _editAmenities() async {
    final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => AddActivityAmenitiesScreen(
            activityId: widget.activityId,
            client: widget.client,
            isEdit: true,
          ),
        ));
    if (updated == true && mounted) {
      _load();
    }
  }

  void _editTiming() async {
    final updated = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute<dynamic>(
          builder: (_) => AddVenueTimingScreen(
            activityId: widget.activityId,
            initialTiming: _timing,
            client: widget.client,
            isEdit: true,
          ),
        ));
    if (updated != null && mounted) {
      if (updated is Map<String, dynamic>) {
        setState(() {
          _timing = {
            for (final entry in updated.entries)
              entry.key: (entry.value as List)
                  .map((slot) => Map<String, String>.from(slot as Map))
                  .toList(),
          };
        });
      } else {
        final cp = await ActivityFlowCheckpoint.read(widget.activityId);
        if (cp?.data['timing'] is Map) {
          setState(() {
            _timing = {
              for (final entry in (cp!.data['timing'] as Map).entries)
                entry.key.toString(): (entry.value as List)
                    .map((slot) => Map<String, String>.from(slot as Map))
                    .toList(),
            };
          });
        }
      }
      await _saveInterruptedCheckpoint();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToPreviousAddStep();
      },
      child: OnboardingScaffold(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.activityName, style: OnboardingStyles.heading),
                  const SizedBox(height: 6),
                  const Text('Please review activity details and proceed',
                      style: TextStyle(fontSize: 16, color: AppColors.black1)),
                ])),
        Expanded(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
              _photos(),
              _card(
                  'Activity Specific Details',
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final q in _questions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q['questionText']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Satoshi',
                                    color: AppColors.hintColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  q['answer']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Satoshi',
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkBlack,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ]),
                  titleFontSize: 20,
                  onEdit: _editDetails),
              _card(
                  'Amenities List',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amenities',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Satoshi',
                          color: AppColors.hintColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          ((_activity['amenities'] as List?) ?? [])
                              .asMap()
                              .entries
                              .map((e) => '${e.key + 1}. ${e.value}')
                              .join('\n'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onEdit: _editAmenities),
              _card(
                'Operational Details',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operating Days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Satoshi',
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final shortDay in _shortDays)
                          Builder(builder: (_) {
                            final isActive = _isDayActive(shortDay);
                            return Text(
                              shortDay,
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Satoshi',
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isActive
                                    ? AppColors.darkBlack
                                    : const Color(0xFFB0B0B0),
                                decoration: isActive
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                              ),
                            );
                          }),
                      ],
                    ),
                    const Divider(
                        color: Color(0xFFE8E8E8), height: 32, thickness: 1),
                    const Text(
                      'Day Wise Timings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Satoshi',
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Builder(builder: (_) {
                      final activeShortDays =
                          _shortDays.where(_isDayActive).toList();
                      if (activeShortDays.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No operating timings added.',
                            style:
                                TextStyle(fontSize: 14, color: AppColors.gray),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < activeShortDays.length; i++) ...[
                            Builder(builder: (_) {
                              final shortDay = activeShortDays[i];
                              final fullDay = _dayMap[shortDay] ?? shortDay;
                              final slots = _getSlotsForDay(shortDay)
                                  .where((s) =>
                                      s is Map &&
                                      s['open'] != null &&
                                      s['open'] != '-' &&
                                      s['open']
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                  .toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullDay,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Satoshi',
                                      color: AppColors.darkBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final rawSlot in slots)
                                    Builder(builder: (_) {
                                      final slot = rawSlot as Map;
                                      final openTime = slot['open'] ??
                                          slot['openTime'] ??
                                          '-';
                                      final closeTime = slot['close'] ??
                                          slot['closeTime'] ??
                                          '-';
                                      final priceVal =
                                          slot['price']?.toString().trim();
                                      final discountedVal =
                                          slot['discountedPrice']
                                              ?.toString()
                                              .trim();
                                      final slotPrice = (discountedVal != null &&
                                              discountedVal.isNotEmpty &&
                                              discountedVal != '-')
                                          ? discountedVal
                                          : (priceVal != null &&
                                                  priceVal.isNotEmpty &&
                                                  priceVal != '-')
                                              ? priceVal
                                              : '-';

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    'Open Time',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'Satoshi',
                                                      color: Color(0xFF8E8E93),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    'Close Time',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'Satoshi',
                                                      color: Color(0xFF8E8E93),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'Slot Price',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'Satoshi',
                                                      color: Color(0xFF8E8E93),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    openTime.toString(),
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Satoshi',
                                                      color:
                                                          AppColors.darkBlack,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    closeTime.toString(),
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Satoshi',
                                                      color:
                                                          AppColors.darkBlack,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    slotPrice,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Satoshi',
                                                      color:
                                                          AppColors.darkBlack,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              );
                            }),
                            if (i < activeShortDays.length - 1)
                              const Divider(
                                  color: Color(0xFFE8E8E8),
                                  height: 28,
                                  thickness: 1),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
                onEdit: _editTiming,
              ),
            ])),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                  child: OnboardingButton(
                      label: 'Back',
                      outlined: true,
                      onPressed: _backToPreviousAddStep)),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: OnboardingButton(
                      label: 'Next',
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddActivitySubmitReviewScreen(
                                  activityId: widget.activityId,
                                  activityName: widget.activityName,
                                  timing: {
                                    for (final e in _timing.entries)
                                      e.key: (e.value as List)
                                          .map((s) => Map<String, String>.from(
                                              s as Map))
                                          .toList()
                                  },
                                  client: widget.client))))),
            ])),
      ])));
}
