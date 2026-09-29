import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'ContactSupportFormScreen.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _State();
}

class _State extends State<ContactSupportScreen> {

  String _venueId = '';

  @override
  void initState() {
    super.initState();
    _loadVenueId();
  }

  Future<void> _loadVenueId() async {
    final id = checkString(await SharedPreference.readStr("venue_id"));
    if (mounted) setState(() => _venueId = id);
  }

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
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Expanded(
                              child: Container(
                                margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                    getActivIcon(),
                                    
                                    Container(
                                      margin: EdgeInsets.fromLTRB(10, 15, 10, 0),
                                      width: 224,
                                      height: 300,
                                      child: Image.asset('assets/reviewing.png'),
                                    ),

                                    getText(),

                                    getSubText(_venueId)


                                  ],
                                ),
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
                                          flex: 3,
                                          child: Container(
                                            margin: EdgeInsets.only(top: 0, left: 10),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              "Need Help?",
                                              style: TextStyle(
                                                  fontSize: AppSize.size_17,
                                                  fontFamily: 'FontBold',
                                                  color: AppColors.black,
                                                  height: 1.2
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                            onTap: ()
                                            {
                                              CommonUtilities.NavigateWithPush(context, ContactSupportFormScreen());
                                            },
                                            child: getButtonBlack(context, "Contact Support", "contactSupport")

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
      margin: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      color: AppColors.gray,
      height: 1,
    );
  }



  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.only(top: 10),
        child: SvgPicture.asset("assets/activ_tm.svg",)
    );
  }

  Widget getText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      alignment: Alignment.center,
      child: const Text(
        "🎉 You’re all set, we’re reviewing your venue!",
        style: TextStyle(
            fontSize: AppSize.size_28,
            fontFamily: 'FontSemiBold',
            color: AppColors.darkBlack,
            height: 1.2
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget getSubText(String venueId)
  {
    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.fromLTRB(0, 15, 0, 10),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: AppColors.darkBlack,   // different color
            fontFamily: 'FontRegular',
            fontSize: AppSize.size_16,
            height: 1.4
          ),
          children: [
            TextSpan(text: "Your venue registration "),
            TextSpan(
              text: "#$venueId", // dynamic id
              style: TextStyle(
                color: AppColors.black,   // different color
                fontFamily: 'FontSemiBold',
                  height: 1.4
              ),
            ),
            TextSpan(
              text:
              " is complete and under review. Come back in sometime to see your venue live and start receiving bookings from members.",
              style: TextStyle(
                color: AppColors.darkBlack,   // different color
                fontFamily: 'FontRegular',
                fontSize: AppSize.size_16,
                  height: 1.4
              ),
            ),
          ],
        ),
      )
    );
  }
}
