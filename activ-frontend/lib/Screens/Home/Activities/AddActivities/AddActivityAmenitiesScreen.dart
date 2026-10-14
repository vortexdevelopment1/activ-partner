import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../Beans/venue_type_model.dart';
import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../Style/constants_messages.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../CommonCode.dart';
import '../../../StringExtensions.dart';
import 'AddVenuePhotoUploadScreen.dart';

class AddActivityAmenitiesScreen extends StatefulWidget {
  const AddActivityAmenitiesScreen({super.key});

  @override
  State<AddActivityAmenitiesScreen> createState() => _AddActivityAmenitiesScreenState();
}

class _AddActivityAmenitiesScreenState extends State<AddActivityAmenitiesScreen> {
  final ScrollController _scrollController = ScrollController();
  List<VenueTypeModel> _amenities = [];
  bool _loading = true;
  bool get _hasSelection => _amenities.any((item) => item.isSelected);

  @override
  void initState() {
    super.initState();
    _fetchAmenities();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAmenities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('customer_facilities_type')
          .doc('facilities_type')
          .get();
      if (!mounted) return;
      if (snapshot.exists) {
        final list = snapshot.data()?['facilities'] as List<dynamic>? ?? [];
        setState(() {
          _amenities = list
              .map((item) => VenueTypeModel.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.active)
              .toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (error) {
      CommonUtilities.showLog('AddActivityAmenitiesScreen error: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_hasSelection) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.selectOfferType);
      return;
    }

    final selected = _amenities
        .where((item) => item.isSelected)
        .map((item) => {'id': item.id, 'title': item.title})
        .toList();
    await SharedPreference.addStringToSF(
      'place_offer',
      jsonEncode({'place_offer': selected}),
    );
    if (!mounted) return;
    CommonUtilities.NavigateWithPush(context, const AddVenuePhotoUploadScreen());
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
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 16),
                  children: [
                    Center(child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain)),
                    getStepBarCount(5 / 6, 5, 6),
                    const SizedBox(height: 24),
                    const Text(
                      'Select amenities for this activity',
                      style: TextStyle(
                        fontSize: 25,
                        fontFamily: 'FontSemiBold',
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
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _amenities.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 113,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _amenities[index];
                          return InkWell(
                            onTap: () => setState(() => item.isSelected = !item.isSelected),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: item.isSelected ? const Color(0xFFF6F1FD) : AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: item.isSelected ? AppColors.borderGradient1 : AppColors.gray,
                                  width: item.isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(_iconFor(item), width: 28, height: 28),
                                  const SizedBox(height: 14),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: AppSize.size_16,
                                      fontFamily: 'FontSemiBold',
                                      color: AppColors.darkBlack,
                                    ),
                                  ),
                                ],
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
                      child: getBackButton(context, 'Back', 'activityAmenities'),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: InkWell(
                      onTap: _saveAndContinue,
                      child: _hasSelection
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
