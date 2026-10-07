import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../api_calling/api_constant.dart';
import '../Beans/venue_type_model.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'LegalInformationScreen.dart';
import 'TellUsAboutScreen.dart';
import 'VenueAvailabilityScreen.dart';
import 'ListActivityTypeScreen.dart';
import 'VenueTimingScreen.dart';

class CustomerPlacesOffer extends StatefulWidget {
  const CustomerPlacesOffer({super.key, this.reviewMode = false});
  final bool reviewMode;
  @override
  _State createState() => _State();
}

class _State extends State<CustomerPlacesOffer> {
  List<VenueTypeModel> resultList = [];
  int page = 1;
  bool isSelectedValue = false;
  bool isShimmerLoading = false;
  String noDataFound = NO_DATA_FOUND;
  ScrollController scrollController = ScrollController();

  int currentStep = onboardingAmenitiesStep;
  final int totalSteps = totalSetup;

  void nextStep() {
    if (currentStep < totalSteps) {
      setState(() {
        currentStep++;
      });
    }
  }

  void prevStep() {
    if (currentStep > 1) {
      setState(() {
        currentStep--;
      });
    }
  }

  _State() {
    noDataFound = LOADING;
    page=1;
  }

  @override
  void initState() {
    isShimmerLoading = true;
    fetchData();
    super.initState();
  }

  // Fetch Data Name
  Future<void> fetchData() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("customer_facilities_type")
          .doc("facilities_type")
         // .doc("main_document")
          .get();

      if (snapshot.exists) {
        var data = snapshot.data();
        var list = data?["facilities"] as List<dynamic>;
        final raw = widget.reviewMode ? await SharedPreference.readStr('place_offer') : null;
        final saved = raw == null ? <dynamic>[] : (jsonDecode(raw)['place_offer'] as List);
        final selectedIds = saved.map((e) => e['id']?.toString()).toSet();
        if (!mounted) return;

        setState(() {
          resultList = list.map((e) => VenueTypeModel.fromJson(e)).toList();
          for (final model in resultList) {
            model.isSelected = selectedIds.contains(model.id);
          }
          isSelectedValue = resultList.any((model) => model.isSelected);
          isShimmerLoading = false;
        });
        isShimmerLoading = false;
      }
    } catch (e) {
      CommonUtilities.showLog("Error fetching Data: $e");
    }
  }

  void goToBackScreen(BuildContext context)
  {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    double progress = currentStep / totalSteps;

    return PopScope(
      // Setting canPop to false means pop action can't happen directly
      canPop: false,
      // onPopInvokedWithResult handles the back button or pop gesture
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return; // If the pop is already handled, do nothing
        }
        goToBackScreen(context);
        // Return true to allow the pop action to proceed
        return Future.value(true);
      },
      child: Container(
        decoration: context.getYellowGradient,
        child: SafeArea(
          left: false,
          top: true,
          bottom: true,
          right: false,
          child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Container(
                decoration: context.getYellowGradient,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0,0,0,0),
                  child: Column(
                    children: [

                      getActivIcon(),

                      getStepBar(progress),

                      getText(),

                      isShimmerLoading == true ? buildShimmer(context):
                      Expanded(
                        flex: 9,
                        child: getList(context),
                      ),

                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            bottomBarShadow(),

                            Row(
                              children: [


                                Expanded(
                                    flex: 3,
                                    child: InkWell(
                                        onTap: ()
                                        {
                                          Navigator.pop(context);
                                        },
                                        child: getBackButton(context, "Back", "selectActivity"))
                                ),


                                Expanded(
                                  flex: 7,
                                  child: InkWell(
                                      onTap: ()
                                      async
                                      {
                                        //CommonUtilities.NavigateWithPush(context, VenueAvailabilityScreen());
                                        if(isSelectedValue)
                                        {
                                          if (widget.reviewMode) {
                                            await SharedPreference.addStringToSF('place_offer', jsonEncode({
                                              'place_offer': resultList.where((model) => model.isSelected)
                                                  .map((model) => {'id': model.id, 'title': model.title}).toList(),
                                            }));
                                            if (!mounted) return;
                                            Navigator.pop(context, true);
                                          } else {
                                            CommonUtilities.NavigateWithPush(context, ListActivityTypeScreen());
                                          }

                                        }else{
                                          CommonUtilities.createSnackBar(context, ConstantsMessages.selectOfferType);
                                        }
                                      },
                                      child: isSelectedValue ? getButtonBlack(context, "Next", "selectActivity") :
                                      getButtonGray(context, "Next", "selectActivity")
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              )
          ),
        ),
      ),
    );
  }

  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 0, 0),
        child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain)
    );
  }

  Widget getStepBar(double progress)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
        child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getText()
  {
    return Container(
      margin: EdgeInsets.only(top: 25, left: 15, right: 15, bottom: 10),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Tell members what your place has to offer",
        style: TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'FontSemiBold',
            color: AppColors.darkBlack,
            height: 1.2
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  ///To get the List
  Widget getList(BuildContext context)
  {
    // Filter only active items
    final activeList = resultList.where((model) => model.active).toList();

    return Container(
        margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: LazyLoadScrollView(
          scrollDirection: Axis.vertical,
          scrollOffset: activeList.length,
          onEndOfPage:()
          {
          },
          child: RefreshIndicator(
            onRefresh: _pullRefresh,
            color: AppColors.lineGradientStart,             // loader color
            backgroundColor: AppColors.yellowTop, // background circle color
            strokeWidth: 3.0,              // thickness
            displacement: 30,
            child: GridView.builder
              (
                shrinkWrap: true,
                primary: false,
                physics: ClampingScrollPhysics(), // To desable List Scroll
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.only(top: 10),
                itemCount: activeList.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,mainAxisExtent: 113, mainAxisSpacing: 1.0, crossAxisSpacing: 1.0, childAspectRatio: 1.0,),
                itemBuilder: (BuildContext ctxt, int index)
                {
                  return rowListItem(index: index, context: context, model: activeList[index]);
                }
            ),
          ),
        )
    );
  }

  /// Row item View.
  Widget rowListItem({required int index, required BuildContext context, required VenueTypeModel model,})
  {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 5, 5, 10),
      decoration: model.isSelected
          ? BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.borderGradient1, AppColors.borderGradient2],
        ),
        borderRadius: BorderRadius.circular(12),
      )
          : BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: Container(
        width: double.infinity,
        alignment: Alignment.topLeft,
        margin: model.isSelected
            ? EdgeInsets.fromLTRB(2, 2, 2, 2)
            : EdgeInsets.fromLTRB(0, 0, 0, 0),
        decoration: BoxDecoration(
          color: model.isSelected ? AppColors.gray3 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: ()
          async {
            model.isSelected = !model.isSelected;
            isSelectedValue = resultList.any((element) => element.isSelected);

            // Selected list
            List<Map<String, dynamic>> selectedList = resultList
                .where((e) => e.isSelected)
                .map((e) => {
              "id": e.id,
              "title": e.title,
            })
                .toList();

            // Wrap inside key
            Map<String, dynamic> finalJson = {
              "place_offer": selectedList
            };

            // Convert to string
            String jsonString = jsonEncode(finalJson);

            if (!widget.reviewMode) {
              await SharedPreference.addStringToSF("place_offer", checkString(jsonString));
            }
            String placeOffer = checkString(await SharedPreference.readStr("place_offer"));
            CommonUtilities.showLog("Saved Place Offer => $placeOffer");

            setState(() {});

          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              getImage(model, context),
              getTitle(model, context),
            ],
          ),
        ),
      ),
    );
  }

  String setTypeImages(VenueTypeModel model) {
    if (model.type == "parking") {
      return "assets/placeOffer/ic_parking.png";
    }
    else if (model.type == "health") {
      return "assets/placeOffer/ic_health.png";
    }
    else if (model.type == "wifi") {
      return "assets/placeOffer/ic_wifi.png";
    }
    else if (model.type == "ac") {
      return "assets/placeOffer/ic_air.png";
    }
    else if (model.type == "locker") {
      return "assets/placeOffer/ic_locker.png";
    }
    else if (model.type == "lounge") {
      return "assets/placeOffer/ic_lounge.png";
    }
    else if (model.type == "trainer") {
      return "assets/placeOffer/ic_trainer.png";
    }
    else if (model.type == "lighting") {
      return "assets/placeOffer/ic_lighting.png";
    }
    else if (model.type == "fencing") {
      return "assets/placeOffer/ic_fencing.png";
    }
    else if (model.type == "shower") {
      return "assets/placeOffer/ic_shower_room.png";
    }
    else if (model.type == "sound") {
      return "assets/placeOffer/ic_sound.png";
    }
    else if (model.type == "childcare") {
      return "assets/placeOffer/ic_child_care.png";
    }
    else if (model.type == "security") {
      return "assets/placeOffer/ic_security_camera.png";
    }
    else if (model.type == "rental") {
      return "assets/placeOffer/ic_rental.png";
    }
    else {
      return "assets/placeOffer/ic_parking.png";
    }
  }

  /// Image Layout.
  Widget getImage(VenueTypeModel model, BuildContext context)
  {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.fromLTRB(10, 5, 2, 0),
      child: Container(
        width: 28,
        height: 28,
        child: Image.asset(
          setTypeImages(model),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget getTitle(VenueTypeModel model, BuildContext context)
  {
    return Container(
      margin: EdgeInsets.fromLTRB(12, 5, 5, 5),
      child: Text(
        (model.title!=null && model.title!="") ? model.title : "",
        textAlign: TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'FontSemiBold',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Future<void> _pullRefresh() async {
    // Simulate network call or data refresh
    await Future.delayed(Duration(seconds: 2));
    fetchData();
  }

  Widget buildShimmer(BuildContext context) =>
      Expanded(
        flex: 9,
        child: Container(
          decoration: context.getYellowGradient,
          margin: EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: ListView(
            controller: scrollController, //set controller
            shrinkWrap: true,
            children: List.generate(
                10, // or any desired number of items
                    (index) => getShimmerLayoutWithoutImage(context)
            ),

          ),
        ),
      );
}
