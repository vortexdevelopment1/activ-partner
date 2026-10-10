import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';
import '../GetStartedScreen.dart';
import '../Home/VenueDetailsScreen.dart';
import '../Home/VenueOwnerDetailsScreen.dart';
import '../Home/VenueTimingListScreen.dart';
import '../Home/VenueViewImageScreen.dart';
import '../StringExtensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  _State createState() => _State();
}

class _State extends State<SettingsScreen> {

  ScrollController scrollController = ScrollController();

  _State() {}

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //Using PopScope for hard backPress
    return PopScope(
      // Setting canPop to false means pop action can't happen directly
      canPop: false,
      // onPopInvokedWithResult handles the back button or pop gesture
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return; // If the pop is already handled, do nothing
        }
        Navigator.pop(context);
        // Return true to allow the pop action to proceed
        return Future.value(true);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent, // Replace with your desired color
        ),
        child: Container(
          color: AppColors.bgColor, //To change the status Bar Color.
          //Scaffold use for basic lifecycle of activity
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
                  color: AppColors.bgColor,
                ),
              ),

              SafeArea(
                left: false,
                top: true,
                bottom: true,
                right: false,
                child: Scaffold(
                    body: Container(
                      decoration: context.getYellowGradient,
                      child: Padding(
                          padding: EdgeInsets.all(0),
                          child: Column(
                            children: [

                              getToolTab(context),

                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(top: 5),
                                  child: ListView(
                                    controller: scrollController, //set controller
                                    padding: EdgeInsets.all(0),
                                    shrinkWrap: true,
                                    children: [
                                      getLogout(context),
                                      getDeleteAccount(context),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                      ),
                    )
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                Navigator.pop(context);
              },
                  child: Container(
                    padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                    child: SvgPicture.asset('assets/ic_back.svg',),
                  )
              ),
            ),
          ),

          getTitleText(context, "Settings Screen", 'Settings_Screen')

        ],
      ),
    );
  }

  Widget getLogout(BuildContext context)
  {
    return InkWell(
      onTap: ()
      {
        showLogoutPopup(context);
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
        child: getMenuScreenCardLayout(context, 'Logout', '', '', 'Menu_Screen')
      ),
    );
  }

  Widget getDeleteAccount(BuildContext context)
  {
    return InkWell(
      onTap: ()
      {

      },
      child: Container(
          margin: EdgeInsets.fromLTRB(15, 20, 15, 0),
          child: getMenuScreenCardLayout(context, 'Delete Account', '', '', 'Menu_Screen')
      ),
    );
  }

  Widget getText(String textName)
  {
    return Container(
        margin: EdgeInsets.fromLTRB(15, 0, 10, 0),
        child: getMenuSettingsText(context, textName, "Menu_Screen")
    );
  }

  //-------------------------------------------------------Start Logout Popup-----------------------------------------------------------------------------------------------
  void showLogoutPopup(context)
  {
    showModalBottomSheet(
        context: context,
        isDismissible: false,  // Disable dismiss on tapping outside
        isScrollControlled: true,
        builder: (BuildContext bc){
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom ?? 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: const Radius.circular(25),
                  topRight: const Radius.circular(25),
                ),
              ),

              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[

                    // Divider Line
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Container(
                          width: 50,
                          margin: const EdgeInsets.only(top: 0),
                          child: Divider(
                            color: AppColors.yellowTop,
                            thickness: 10,
                            height: 8
                            ,
                          ),
                        ),
                      ),
                    ),

                    // Cross Icon and Title Text
                    Container(
                      height: 52,
                      child: Stack(alignment: Alignment.center,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                fontSize:  CommonUtilities.increaseSizeBy2(AppSize.size_16),
                                fontFamily: CommonUtilities.fontTypeAccordingToLang('FontBold'),
                                color: AppColors.darkBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),


                    Container(
                      color: AppColors.bgColor,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Column(
                            children: [

                              Container(
                                margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                child: Text(
                                  'Are You Sure You Want to Logout this Account?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                                    fontFamily: CommonUtilities.fontTypeAccordingToLang('FontRegular'),
                                    color: AppColors.darkBlack,
                                  ),
                                ),
                              ),

                              InkWell(
                                onTap: ()
                                {
                                  logoutUser(context);
                                },
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
                                  child: getButtonBlack(context, 'Yes', "Setting_Screen"),
                                ),
                              ),

                              InkWell(
                                onTap: ()
                                {
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(5, 0, 10, 0),
                                  child: getBackButton(context, 'Cancel', "Setting_Screen"),
                                ),
                              ),

                            ],
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
    );
  }
  //-------------------------------------------------------End Logout Popup-----------------------------------------------------------------------------------------------

  Future<void> logoutUser(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // Clear all previous screens
    SharedPreference.addStringToSF("userMobileNumber", "");
    SharedPreference.clearSF();
    CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, GetStartedScreen());
  }

}