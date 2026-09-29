import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../Style/app_size.dart';
import '../../../../Style/constants_messages.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../CommonCode.dart';
import 'AddVenuePhotoUploadScreen.dart';


class AddSelectedVenueFormScreen extends StatefulWidget {
  const AddSelectedVenueFormScreen({super.key});

  @override
  State<AddSelectedVenueFormScreen> createState() => _State();
}

class _State extends State<AddSelectedVenueFormScreen> {

  TextEditingController numberOfController = TextEditingController();
  TextEditingController flooringTypeController = TextEditingController();
  TextEditingController maxCapacityController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  bool isButtonEnabled = false;
  bool isChecked = false;
  String phoneCode = "", userMobileNumber = "";

  _State()
  {
    getData();
  }

  @override
  void initState() {
    super.initState();
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    setState(() {});
  }

  @override
  void dispose() {
    numberOfController.dispose();
    flooringTypeController.dispose();
    maxCapacityController.dispose();
    descriptionController.dispose();
    super.dispose();
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

                                    getText(),

                                    getSubText(),


                                    getLabel('Number of Courts', 'number_of_court'),
                                    getEnterField(context, numberOfController, "Enter number of courts", "numberOfCourts"),

                                    getLabel('Flooring Type', ''),
                                    getEnterField(context, flooringTypeController, "Enter flooring type", "flooringType"),

                                    getLabel('Maximum Capacity', ''),
                                    getEnterField(context, maxCapacityController, "Enter maximum capacity", "maxCapacity"),
                                    getLocationUrlCopyText(),

                                    getLabel('Description', ''),
                                    getEnterField(context, descriptionController, "Enter description", "description"),

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
                                          child: InkWell(
                                              onTap: ()
                                              {
                                                Navigator.pop(context);
                                              },
                                              child: getBackButton(context, "Back", "tellUsAbout"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                            onTap: ()
                                            {
                                              if(validation(context))
                                              {
                                                SharedPreference.addStringToSF("number_of_court", checkString(numberOfController.text.trim().toString()));
                                                SharedPreference.addStringToSF("flooring_type", checkString(flooringTypeController.text.trim().toString()));
                                                SharedPreference.addStringToSF("maximum_capacity", checkString(maxCapacityController.text.trim().toString()));
                                                SharedPreference.addStringToSF("description", checkString(descriptionController.text.trim().toString()));

                                                CommonUtilities.NavigateWithPush(context, AddVenuePhotoUploadScreen());
                                                //CommonUtilities.NavigateWithPush(context, AddCustomerPlacesOffer());

                                              } else{}
                                            },
                                            child: getButtonBlack(context, "Next", "tellUsAbout")
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
      margin: EdgeInsets.only(top: 5),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Tell us about you, Venue Place!",
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
      margin: EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: const Text(
        "We will use these details for venue place",
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

  Widget getLabel(String label, String type) {
    return Row(
      children: [
        Container(
          margin: type == "number_of_court" ? EdgeInsets.fromLTRB(0, 15, 0, 0) : EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Text(
            label,
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),
        Container(
          margin: type == "number_of_court" ? EdgeInsets.fromLTRB(0, 15, 0, 0) : EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.red,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        )
      ],
    );
  }

  Widget getEnterField(BuildContext context, TextEditingController controller, String hint, String fieldNumber) {
    return Container(
      margin: fieldNumber == "description" ? const EdgeInsets.fromLTRB(0, 8, 0, 10) : const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: const Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray, width: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: controller,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: (fieldNumber == "numberOfCourts" || fieldNumber == "maxCapacity") ? TextInputType.number : TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            maxLines: fieldNumber == "description" ? 3 : 1,
            inputFormatters: (fieldNumber == "numberOfCourts" || fieldNumber == "maxCapacity")
                ? [FilteringTextInputFormatter.digitsOnly]
                : [],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: hint, // Set the hint label text
              hintStyle: TextStyle(
                fontSize:  AppSize.size_14,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor, // Text color of the hint label
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget getLocationUrlCopyText() {
    return Container(
      margin: EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
              width: 20,
              height: 20,
              child: Image.asset('assets/ic_question.png')
          ),
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.fromLTRB(0, 3, 0, 0),
            child: const Text(
              "Maximum people that can use this activity at once",
              style: TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'FontMedium',
                  color: AppColors.hintColor,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          )
        ],
      ),
    );
  }

  Widget getEmailLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Email Address",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        Container(
          margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.red,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        )
      ],
    );
  }

  bool validation(BuildContext context)
  {
    if (numberOfController.text.toString().toString().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.pleaseEnterNumberOfCourt);
      return false;
    }
    else if (flooringTypeController.text.toString().toString().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.pleaseEnterFlooringType);
      return false;
    }
    else if (maxCapacityController.text.toString().toString().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.pleaseEnterMaxCapacity);
      return false;
    }
    else if (descriptionController.text.toString().toString().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.pleaseEnterDescription);
      return false;
    }
    return true;
  }
}
