import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../api_calling/api_constant.dart';
import '../Beans/activity_type_model.dart';
import 'CommonCode.dart';
import 'LegalInformationScreen.dart';
import 'TellUsAboutScreen.dart';

class VenueAvailabilityScreen extends StatefulWidget {
  @override
  _State createState() => _State();
}

class _State extends State<VenueAvailabilityScreen> {
  List<ActivityTypeModel> resultList = [];
  int page = 1;
  String noDataFound = NO_DATA_FOUND;
  ScrollController scrollController = ScrollController();

  int currentStep = 8;
  final int totalSteps = 10;

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
  }

  @override
  void initState() {
    super.initState();
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

                      getStepBarCount(progress),

                      getText(),
                      getSubText(),

                      (resultList!=null && resultList.length>0)
                          ?
                      Expanded(
                        flex: 9,
                        child: getList(context),
                      ) :Container(),

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
                                        child: getBackButton(context, "Back", "venueAvailability"))
                                ),


                                Expanded(
                                  flex: 7,
                                  child: InkWell(
                                      onTap: ()
                                      {
                                        CommonUtilities.NavigateWithPush(context, LegalInformationScreen());
                                      },
                                      child: getButtonBlack(context, "Next", "venueAvailability")
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
        child: SvgPicture.asset("assets/activ_tm.svg",)
    );
  }

  Widget getStepBarCount(double progress)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Progress Bar
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey[300],
                  color: Colors.black,
                ),
              ),
            ),

            SizedBox(width: 10),

            // Step Count Text
            Text(
              "$currentStep/$totalSteps",
              style: TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'FontMedium',
                  color: AppColors.black1,
                  height: 1
              ),
            ),
          ],
        )
    );
  }

  Widget getText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 25, left: 15, right: 15, bottom: 0),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Set the venue’s availability",
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

  Widget getSubText()
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      child: const Text(
        "Tell us when the members can reserve your venue",
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'FontRegular',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  ///To get the List
  Widget getList(BuildContext context)
  {
    return Container(

        margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: LazyLoadScrollView(
          scrollDirection: Axis.vertical,
          scrollOffset: resultList.length,
          onEndOfPage:()
          {
          },
          child: GridView.builder
            (
              shrinkWrap: true,
              primary: false,
              physics: ClampingScrollPhysics(), // To desable List Scroll
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.only(top: 10),
              itemCount: resultList.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,mainAxisExtent: 113, mainAxisSpacing: 1.0, crossAxisSpacing: 1.0, childAspectRatio: 1.0,),
              itemBuilder: (BuildContext ctxt, int index)
              {
                return rowListItem(index: index, context: context);
              }
          ),
        )
    );
  }

  /// Row item View.
  Widget rowListItem({required int index , required BuildContext context})
  {
    ActivityTypeModel model = resultList[index];

    return Container(
      margin: const EdgeInsets.fromLTRB(5, 5, 5, 10),
      decoration: model.isSelected ? BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.borderGradient1, AppColors.borderGradient2],
        ),
        borderRadius: BorderRadius.circular(12),
      ):
      BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray,width: 1),
      ),
      child: Container(
        width: double.infinity,
        alignment: Alignment.topLeft,
        margin: model.isSelected ? EdgeInsets.fromLTRB(2, 2, 2, 2) : EdgeInsets.fromLTRB(0,0, 0, 0),
        decoration: BoxDecoration(
          color: model.isSelected ? AppColors.gray3 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),

        child: InkWell(onTap: ()
        {
          model.isSelected = !model.isSelected;
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



  /// Image Layout.
  Widget getImage(ActivityTypeModel model, BuildContext context)
  {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.fromLTRB(10, 5, 2, 0),
      child: Container(
        width: 28,
        height: 28,
        child: Image.asset(
          model.image,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget getTitle(ActivityTypeModel model, BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 5, 5, 5),
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

}