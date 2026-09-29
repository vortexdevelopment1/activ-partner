import 'package:activ_app/Screens/Home/HomeScreen.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../Beans/activity_model.dart';
import '../../../Style/app_colors.dart';
import '../../../Style/app_size.dart';
import '../../../api_calling/api_request.dart';
import '../../CommonCode.dart';
import '../../StringExtensions.dart';
import 'ActivityDetailsScreen.dart';
import 'AddActivities/AddListActivityTypeScreen.dart';


class VenueActivityListScreen extends StatefulWidget {
  const VenueActivityListScreen({super.key});

  @override
  State<VenueActivityListScreen> createState() => _State();
}

class _State extends State<VenueActivityListScreen> {
  List< ActivityModel> activities = [];
  bool isLoading = true;
  String userMobileNumber = "";

  @override
  void initState() {
    super.initState();
    fetchActivities();
  }

  Future<void> fetchActivities() async {

    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    final String phoneKey = 'IND (+91)'+ userMobileNumber;

    // 2️⃣ Get UID from users_by_phone
    final phoneDoc = await FirebaseFirestore.instance
        .collection('users_by_phone')
        .doc(phoneKey)
        .get();

    if (!phoneDoc.exists) {
      debugPrint("❌ Phone mapping not found for $phoneKey");
      return;
    }

    final String realUid = phoneDoc['uid'];


    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(realUid)
        .get();

    final data = doc.data();
    if (data == null) return;

    final List list = data['activity_list'] ?? [];

    activities = list
        .map((e) => ActivityModel.fromJson(e))
        .toList();

    setState(() => isLoading = false);
  }


  // =======================
  // UI
  // =======================
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          /*To Set Top Header Color*/
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 100,
              color: AppColors.yellowTop,
            ),
          ),
          /*To Set Bottom Header Color*/
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              color: AppColors.white,
            ),
          ),

          SafeArea(
            top: true,
            bottom: true,
            left: false,
            right: false,
            child: Scaffold(
              body: Container(
                decoration: context.getYellowGradient,
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double width = constraints.maxWidth;

                        bool isMobile = width < 600;
                        bool isTablet = width >= 600 && width < 1100;

                        double containerWidth =
                        isMobile ? width * 1 : (isTablet ? 500 : 600);

                        return Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              getToolTab(context),

                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                                  child: isLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : activities.isEmpty
                                      ? const Center(child: Text("No Activities found", style: TextStyle(fontSize: AppSize.size_16,
                                        fontFamily: 'FontBold', color: AppColors.darkBlack,),
                                   )
                                  )
                                      : ListView.builder(
                                    itemCount: activities.length,
                                    itemBuilder: (context, index) {

                                      return rowListItem(context: context, index: index);

                                      /*final activity = activities[index];

                                      return ListTile(
                                        leading: const Icon(Icons.sports),
                                        title: Text(
                                          activity.title, // 👈 Football / Gym / Cricket
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        trailing: const Icon(Icons.arrow_forward_ios),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ActivityDetailsScreen(activity: activity),
                                            ),
                                          );
                                        },
                                      );*/
                                    },
                                  )
                                ),
                              ),

                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                child: Column(
                                  children: [
                                    bottomBarShadow(),

                                    Row(
                                      children: [

                                        Expanded(
                                          flex: 1,
                                          child: InkWell(
                                              onTap: ()
                                              {
                                                SharedPreference.addStringToSF("number_of_court", "");
                                                SharedPreference.addStringToSF("flooring_type", "");
                                                SharedPreference.addStringToSF("maximum_capacity", "");
                                                SharedPreference.addStringToSF("description", "");
                                                SharedPreference.addStringToSF("operate_value", "");
                                                SharedPreference.addStringToSF("place_offer", "");

                                                CommonUtilities.NavigateWithPush(context, AddListActivityTypeScreen());

                                              },
                                              child: Container(
                                                margin: EdgeInsets.only(left: 5),
                                                  child: getButtonBlack(context, "Add More Activity", "Activities_List_Screen")
                                              )
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      }
                    )
                  ],
                )
              ),
            ),
          )
        ],
      ),
    );
  }

  void goToBackScreen(BuildContext)
  {
    if(CommonUtilities.addActivitySuccessfully == "yes")
    {
      CommonUtilities.addActivitySuccessfully = "";
      CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, HomeScreen());
    }
    else{
      CommonUtilities.addActivitySuccessfully = "";
      Navigator.pop(context);
    }
  }

  // To show the toolbar
  Widget getToolTab(BuildContext context)
  {
    return Container(
      height: AppSize.toolTabSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: InkWell(onTap: ()
              {
                goToBackScreen(context);
              },
                  child: Container(
                    padding: EdgeInsets.fromLTRB(15,10,15,10),
                    child: SvgPicture.asset('assets/ic_back.svg',),
                  )
              ),
            ),
          ),

          getTitleText(context, 'Activities Name', 'Activities_List_Screen')

        ],
      ),
    );
  }

  // =======================
  // IMAGE ITEM (LIST)
  // =======================
  Widget rowListItem({required BuildContext context, required int index})
  {
    ActivityModel model = activities[index];

    return InkWell(
      onTap: ()
      {
        //print("participantsFollow : " + activities[index].participantsFollow);
        CommonUtilities.NavigateWithPush(context, ActivityDetailsScreen(activity: activities[index], activityName: model.title,));
      },
      child: Visibility(
        visible: model.activityStatus == "true" ? true : false,
        child: Container(
          alignment: Alignment.topLeft,
          child: Container(
              alignment: Alignment.topLeft,
              margin: EdgeInsets.fromLTRB(0, 0, 0, 25),
              padding: EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.white40,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gray_border2,
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [

                                    const Icon(Icons.sports_gymnastics),

                                    getTitle(context, model),

                                    Container(
                                      margin: EdgeInsets.only(right: 5),
                                        width: 15,
                                        //height: 20,
                                        child: const Icon(Icons.arrow_forward_ios)
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ]
              )
          ),
        ),
      ),
    );
  }

  Widget getTitle(BuildContext context, ActivityModel model)
  {
    return Expanded(
      child: Container(
        margin: EdgeInsets.fromLTRB(8, 0, 2, 0),
        child: Text(
          (model.title!=null && model.title!="") ? model.title : "",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'FontBold',
            color: AppColors.darkBlack,
          ),
        ),
      ),
    );
  }

}

