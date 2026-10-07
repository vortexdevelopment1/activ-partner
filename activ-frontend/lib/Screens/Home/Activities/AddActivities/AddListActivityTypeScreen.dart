import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';

import '../../../../Beans/venue_type_model.dart';
import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../api_calling/api_constant.dart';
import '../../../../api_calling/api_request.dart';
import '../../../CommonCode.dart';
import 'AddSelectedVenueFormScreen.dart';

class AddListActivityTypeScreen extends StatefulWidget {
  const AddListActivityTypeScreen({super.key});

  @override
  _State createState() => _State();
}

class _State extends State<AddListActivityTypeScreen> {
  List<VenueTypeModel> resultList = [];
  int page = 1;
  String noDataFound = NO_DATA_FOUND;
  ScrollController scrollController = ScrollController();

  bool isActivitySelected = false;
  bool isShimmerLoading = false;

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
          .collection("venue_operate_type")
          .doc("main_document")
          .get();

      if (snapshot.exists) {
        var data = snapshot.data();
        var list = data?["venue_type"] as List<dynamic>;

        setState(() {
          resultList = list.map((e) => VenueTypeModel.fromJson(e)).toList();
        });
      }
      isShimmerLoading = false;
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

                      getOperateText(),

                      isShimmerLoading == true ? buildShimmer(context) :
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
                                      {
                                        if(isActivitySelected)
                                        {
                                          CommonUtilities.NavigateWithPush(context, AddSelectedVenueFormScreen());
                                        }else{
                                          CommonUtilities.createSnackBar(context, ConstantsMessages.selectVenueType);
                                        }
                                      },
                                      child: isActivitySelected ? getButtonBlack(context, "Next", "selectActivity") :
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

  Widget getOperateText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 5, left: 15, right: 15, bottom: 10),
      alignment: Alignment.centerLeft,
      child: const Text(
        "What type of venue do you operate?",
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

  /// To get the List
  Widget getList(BuildContext context) {
    // Filter only active items
    final activeList = resultList.where((model) => model.active).toList();

    return Container(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: LazyLoadScrollView(
        scrollDirection: Axis.vertical,
        scrollOffset: activeList.length,
        onEndOfPage: () {},
        child: RefreshIndicator(
          onRefresh: _pullRefresh,
          color: AppColors.lineGradientStart,             // loader color
          backgroundColor: AppColors.yellowTop, // background circle color
          strokeWidth: 3.0,              // thickness
          displacement: 30,
          child: GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.only(top: 10, bottom: 0, left: 0, right: 0),
            itemCount: activeList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 180,
              mainAxisSpacing: 1.0,
              crossAxisSpacing: 1.0,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (BuildContext ctxt, int index) {
              return rowListItem(model: activeList[index], context: context);
            },
          ),
        ),
      ),
    );
  }

  /// Row item View
  Widget rowListItem({required VenueTypeModel model, required BuildContext context,})
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
      child: InkWell(
        onTap: () async {
          // Single selection
          for (var item in resultList) {
            item.isSelected = false;
          }
          model.isSelected = true;

          isActivitySelected = resultList.any((item) => item.isSelected);

          // JSON object
          Map<String, dynamic> operateValue = {
            "id": model.id,
            "title": model.title,
          };
          // Convert to String
          String jsonString = jsonEncode(operateValue);
          // Save in SharedPreferences
          SharedPreference.addStringToSF("operate_value", checkString(jsonString));
          String operateCValue = checkString(await SharedPreference.readStr("operate_value"));
          CommonUtilities.showLog("Saved operate_value => $operateCValue");
          setState(() {});
        },
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: model.isSelected
              ? EdgeInsets.fromLTRB(2, 2, 2, 2)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: model.isSelected ? AppColors.gray3 : AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              getImage(model, context),
              getTitle(model, context),
              getDescription(model, context),
            ],
          ),
        ),
      ),
    );
  }



  String setTypeImages(VenueTypeModel model) {
    if (model.type == "pool") {
      return "assets/ic_pool.png";
    } else if (model.type == "gym") {
      return "assets/ic_gym.png";
    } else if (model.type == "court") {
      return "assets/ic_cock.png";
    } else if (model.type == "football") {
      return "assets/ic_football.png";
    } else if (model.type == "yoga") {
      return "assets/ic_yoga.png";
    } else if (model.type == "arts") {
      return "assets/ic_arts.png";
    } else if (model.type == "dance") {
      return "assets/ic_dance.png";
    } else if (model.type == "others") {
      return "assets/ic_other.png";
    } else {
      return "assets/ic_pool.png";
    }
  }



  /// Image Layout.
  Widget getImage(VenueTypeModel model, BuildContext context)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
        child: Container(
          width: 46,
          height: 59,
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
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        (model.title!=null && model.title!="") ? model.title : "",
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'FontSemiBold',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Widget getDescription(VenueTypeModel model, BuildContext context)
  {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        (model.description!=null && model.description!="") ? model.description : "",
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'FontRegular',
          color: AppColors.black1,
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
