
import 'package:http/http.dart' as http;
import '../../../../api_calling/activity_setup_api.dart';
import 'package:flutter/material.dart';

import '../../../../Beans/venue_type_model.dart';
import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../Style/constants_messages.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../CommonCode.dart';
import '../../../StringExtensions.dart';
import 'AddVenueTimingScreen.dart';
import '../../../../api_calling/api_request.dart';
import '../../../../Utills/activity_flow_checkpoint.dart';
import 'dart:convert';
import '../../../onboarding_widgets.dart';

class AddActivityAmenitiesScreen extends StatefulWidget {
  const AddActivityAmenitiesScreen(
      {super.key, required this.activityId, this.client});
  final String activityId;
  final http.Client? client;

  @override
  State<AddActivityAmenitiesScreen> createState() =>
      _AddActivityAmenitiesScreenState();
}

class _AddActivityAmenitiesScreenState
    extends State<AddActivityAmenitiesScreen> {
  final ScrollController _scrollController = ScrollController();
  List<VenueTypeModel> _amenities = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late final ActivitySetupApi _api;
  bool get _hasSelection => _amenities.any((item) => item.isSelected);

  @override
  void initState() {
    super.initState();
    if (!ActivityFlowCheckpoint.restoring) {
      ActivityFlowCheckpoint.save(activityId: widget.activityId, step: 'amenities');
    }
    _api = ActivitySetupApi(client: widget.client);
    _fetchAmenities();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetchAmenities() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _api.amenities();
      final activity = await _api.activity(widget.activityId);
      final selected = (activity['amenities'] as List? ?? [])
          .map((v) => v.toString())
          .toSet();
      if (!mounted) return;
      setState(() => _amenities = catalog
          .map((item) => VenueTypeModel.fromJson(item)
            ..isSelected = selected.contains(item['title']))
          .toList());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_saving) return;
    if (!_hasSelection) {
      CommonUtilities.createSnackBar(
          context, ConstantsMessages.selectOfferType);
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.saveAmenities(
          widget.activityId,
          _amenities
              .where((item) => item.isSelected)
              .map((item) => item.title)
              .toList());
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => AddVenueTimingScreen(
                  activityId: widget.activityId, client: widget.client)));
    } catch (error) {
      if (mounted) CommonUtilities.createSnackBar(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _iconFor(VenueTypeModel model) {
    switch (model.type) {
      case 'parking':
        return 'assets/placeOffer/ic_parking.png';
      case 'health':
        return 'assets/placeOffer/ic_health.png';
      case 'wifi':
        return 'assets/placeOffer/ic_wifi.png';
      case 'ac':
        return 'assets/placeOffer/ic_air.png';
      case 'locker':
        return 'assets/placeOffer/ic_locker.png';
      case 'lounge':
        return 'assets/placeOffer/ic_lounge.png';
      case 'trainer':
        return 'assets/placeOffer/ic_trainer.png';
      case 'lighting':
        return 'assets/placeOffer/ic_lighting.png';
      case 'fencing':
        return 'assets/placeOffer/ic_fencing.png';
      case 'shower':
        return 'assets/placeOffer/ic_shower_room.png';
      case 'sound':
        return 'assets/placeOffer/ic_sound.png';
      case 'childcare':
        return 'assets/placeOffer/ic_child_care.png';
      case 'security':
        return 'assets/placeOffer/ic_security_camera.png';
      case 'rental':
        return 'assets/placeOffer/ic_rental.png';
      default:
        return 'assets/placeOffer/ic_parking.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.getYellowGradient,
      child: SafeArea(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              const OnboardingHeader(),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
                  children: [
                    getStepBarCount(5 / 6, 5, 6),
                    const SizedBox(height: 24),
                    const Text(
                      'Select amenities for this activity',
                      style: TextStyle(
                        fontSize: 25,
                        fontFamily: 'Satoshi',
                        color: AppColors.darkBlack,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Column(children: [
                        Text(_error!),
                        TextButton(
                            onPressed: _fetchAmenities,
                            child: const Text('Retry'))
                      ])
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _amenities.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          // Keep enough vertical room for the icon, label and
                          // card padding on small screens. 113px caused a
                          // five-pixel overflow for the longer amenity labels.
                          mainAxisExtent: 125,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _amenities[index];
                          return InkWell(
                            onTap: () => setState(
                                () => item.isSelected = !item.isSelected),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: item.isSelected
                                  ? const EdgeInsets.all(2)
                                  : EdgeInsets.zero,
                              decoration: BoxDecoration(
                                gradient: item.isSelected
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.borderGradient1,
                                          AppColors.borderGradient2,
                                        ],
                                      )
                                    : null,
                                color: item.isSelected ? null : AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: item.isSelected
                                      ? const Color(0xFFF6F1FD)
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: item.isSelected
                                      ? null
                                      : Border.all(color: AppColors.gray),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(_iconFor(item),
                                        width: 28, height: 28),
                                    const SizedBox(height: 14),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: AppSize.size_16,
                                        fontFamily: 'Satoshi',
                                        color: AppColors.darkBlack,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              bottomBarShadow(),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child:
                          getBackButton(context, 'Back', 'activityAmenities'),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: InkWell(
                      onTap: _saving || _loading || _error != null
                          ? null
                          : _saveAndContinue,
                      child: _hasSelection && !_saving
                          ? getButtonBlack(context, 'Next', 'activityAmenities')
                          : getButtonGray(context, 'Next', 'activityAmenities'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
