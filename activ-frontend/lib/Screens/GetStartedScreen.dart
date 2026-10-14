import 'package:activ_app/Screens/Home/HomeScreen.dart';
import 'package:activ_app/Screens/LoginScreen.dart';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import 'CommonCode.dart';
import 'GoogleMapScreen.dart';
import 'LoginScreenWithPassword.dart';
import 'MultiImagePickerExample.dart';
import 'VenuePhotoUploadScreen.dart';


class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;

                    bool isMobile = width < 600;
                    bool isTablet = width >= 600 && width < 1100;

                    double containerWidth =
                    isMobile ? width * 1 : (isTablet ? 500 : 600);

                    return Container(
                      //width: containerWidth,
                      //margin: const EdgeInsets.only(right: 20),
                      //padding: EdgeInsets.all(isMobile ? 20 : 30),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                    SizedBox(
                                      height: 108,
                                      child: Center(
                                        child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain),
                                      ),
                                    ),

                                    Container(
                                      alignment: Alignment.centerLeft,
                                      child: const Text(
                                        "📌 Let’s get your venue ACTIVated!",
                                        style: TextStyle(
                                            fontSize: AppSize.size_18,
                                            fontFamily: 'FontSemiBold',
                                            color: AppColors.darkBlack,
                                            height: 1.2
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),

                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 15, 0, 15),
                                      child: const Text(
                                        "Hundreds of fitness & wellness spaces going online with us. "
                                            "Set up in minutes and get discovered.",
                                        style: TextStyle(
                                            fontSize: AppSize.size_16,
                                            fontFamily: 'FontRegular',
                                            color: AppColors.darkBlack,
                                            height: 1.2
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),

                                    // Features
                                    buildFeature('assets/ic_ownership.png',
                                        "Add your ownership details and how members can reach you",
                                        isMobile),

                                    getDividerLine(),

                                    buildFeature('assets/ic_photo.png',
                                        "Showcase your venue with photos, amenities and highlights",
                                        isMobile),

                                    getDividerLine(),

                                    buildFeature('assets/ic_hour.png',
                                        "Set your operating hours and available booking slots",
                                        isMobile),

                                    getDividerLine(),

                                    buildFeature('assets/ic_uploading.png',
                                        "Quickly verify your identity by uploading proofs",
                                        isMobile),
                                  ],
                                ),
                              ),
                            ),


                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: Column(
                                children: [
                                  bottomBarShadow(),

                                  InkWell(
                                      onTap: ()
                                      async {

                                         // await FirebaseAuth.instance.signOut();

                                          CommonUtilities.NavigateWithPush(context, LoginScreen());


                                           //CommonUtilities.NavigateWithPush(context, HomeScreen());
                                          //CommonUtilities.NavigateWithPush(context, LoginScreenWithPassword());
                                          // CommonUtilities.NavigateWithPush(context, MultiImagePickerExample());
                                          // CommonUtilities.NavigateWithPush(context, GoogleMapScreen());
                                      },
                                      child: getButtonBlack(context, "Get Started", "getStarted"))
                                ],
                              ),
                            )

                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget getDividerLine()
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      color: AppColors.gray,
      height: 1,
    );
  }

  // Feature Row
  Widget buildFeature(String icon, String text, bool isMobile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: AppSize.size_16,
                  fontFamily: 'FontRegular',
                  color: AppColors.darkBlack,
                  height: 1.4
              ),
            ),
          ),

          Container(
            alignment: Alignment.topRight,
            width: 60,
            height: 60,
            child: Image.asset(icon),
          )
        ],
      ),
    );
  }
}
