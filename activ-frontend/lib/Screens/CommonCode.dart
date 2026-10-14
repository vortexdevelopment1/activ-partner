import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../Style/app_colors.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_request.dart';
import 'StringExtensions.dart';
import 'custom_widget.dart';

Widget toolBarShadow()
{
  return Container(
    height: 0.1,
    decoration: BoxDecoration(
      color: AppColors.black16,
      boxShadow: [
        BoxShadow(
          color: AppColors.black16,
          spreadRadius: 0.8,
          blurRadius: 0.5,
          offset: Offset(0, 1), // changes position of shadow
        ),
      ],
    ),
  );
}

Widget bottomBarShadow()
{
  return Container(
    //height: 0.1,
    decoration: BoxDecoration(
      color: AppColors.black,
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withOpacity(0.3),
          spreadRadius: 1,
          blurRadius: 2,
          offset: Offset(0, -2), // changes position of shadow
        ),
      ],
    ),
  );
}

Widget getActivIcon(String icon)
{
  return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Image.asset(icon, width: 105, height: 60, fit: BoxFit.contain)
  );
}

Widget getTitleText(BuildContext context, String titleName, String screenName)
{
  return Text(
    titleName,
    style: TextStyle(
      fontSize:  CommonUtilities.increaseSizeBy2(AppSize.size_16),
      fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
      color: screenName == "Activities_Details" ? AppColors.white : AppColors.darkBlack,
    ),
  );
}

Widget getActivityStepLabel(int categoryIndex, int totalCategories, int subStep) {
  return Container(
    margin: const EdgeInsets.only(top: 16),
    alignment: Alignment.centerLeft,
    child: Text(
      'Configuring Activity $categoryIndex of $totalCategories \u2014 Step $subStep/4',
      style: const TextStyle(
        fontSize: AppSize.size_14,
        fontFamily: 'FontSemiBold',
        color: AppColors.hintColor,
        height: 1.3,
      ),
    ),
  );
}

Widget getStepBarCount(double progress, int currentStep, int totalSteps)
{
  return Container(
      margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Progress Bar
          /*Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.grey[300],
                color: AppColors.black,
              ),
            ),
          ),*/

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Background
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.lineGray,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
                  ),
                  // Gradient Overlay
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        width: constraints.maxWidth * progress,
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.lineGradientStart,
                              AppColors.lineGradientEnd,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),


          const SizedBox(width: 10),

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

Widget getText(String text)
{
  return Container(
    margin: const EdgeInsets.only(top: 10),
    alignment: Alignment.centerLeft,
    child: Text(
      text,
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

Widget getSubText(String subText)
{
  return Container(
    margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
    child: Text(
      subText,
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

Widget getButtonBlack(BuildContext context, String buttonName, String screenName)
{
  return Container(
    transform: Matrix4.translationValues(0, 0.0, 0.0),
    child: Container(
        height: 50,
        margin: screenName == "Home_Screen" ? const EdgeInsets.fromLTRB(12, 20, 15, 0) : const EdgeInsets.fromLTRB(12, 15, 15, 15),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: AppColors.black, width: 1),
          color: AppColors.black,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: Text(
                buttonName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenName == "Home_Screen" ? CommonUtilities.increaseSizeBy2(AppSize.size_16) : CommonUtilities.increaseSizeBy2(AppSize.size_18),
                  fontFamily: CommonUtilities.fontTypeAccordingToLang('FontBold'),
                  color: AppColors.yellow,
                ),
              ),
            ),
          ],
        )
    ),
  );
}

Widget getButtonGray(BuildContext context, String buttonName, String screenName)
{
  return Container(
    transform: Matrix4.translationValues(0, 0.0, 0.0),
    child: Container(
        height: 50,
        margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: AppColors.darkGray, width: 1),
          color: AppColors.darkGray,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: Text(
                buttonName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_18),
                  fontFamily: CommonUtilities.fontTypeAccordingToLang('FontBold'),
                  color: AppColors.lightGray,
                ),
              ),
            ),
          ],
        )
    ),
  );
}

Widget getLoginWithOTP(BuildContext context, String buttonName, String screenName)
{
  return Container(
    transform: Matrix4.translationValues(0, 0.0, 0.0),
    child: Container(
        height: 50,
        margin: EdgeInsets.fromLTRB(15, 15, 15, 15),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: AppColors.black, width: 1),
          color: AppColors.cream,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: Text(
                buttonName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_18),
                  fontFamily: CommonUtilities.fontTypeAccordingToLang('FontBold'),
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        )
    ),
  );
}

Widget getBackButton(BuildContext context, String buttonName, String screenName)
{
  return Container(
    transform: Matrix4.translationValues(0, 0.0, 0.0),
    child: Container(
        height: 50,
        margin: EdgeInsets.fromLTRB(15, 15, 5, 15),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: AppColors.black, width: 1),
          color: AppColors.cream,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              //margin: EdgeInsets.only(top: 1),
              child: Text(
                buttonName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_18),
                  fontFamily: CommonUtilities.fontTypeAccordingToLang('FontBold'),
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        )
    ),
  );
}

// Shimmer Layout Without Circle Icon Image
Widget getShimmerLayoutWithoutImage(BuildContext context)
{
  return Container(
    margin: EdgeInsets.fromLTRB(10, 10, 10, 5),
    child: Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Row(
            children: [
              getButton1(context),
              getButton2(context),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget getShimmerLayoutFotTextField(BuildContext context)
{
  return Container(
    margin: EdgeInsets.fromLTRB(10, 10, 10, 5),
    child: Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Row(
            children: [
              getTextField(context),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget getButton1(BuildContext context)
{
  return Expanded(
    child: Container(
      height: 130,
      margin: EdgeInsets.fromLTRB(10, 0, 5, 0),
      alignment: Alignment.centerLeft,
      child: CustomWidget.rectangular(
        height: 130,
        width: MediaQuery.of(context).size.width * 0.5,
      ),
    ),
  );
}

Widget getButton2(BuildContext context)
{
  return Expanded(
    child: Container(
      height: 130,
      margin: EdgeInsets.fromLTRB(5, 0, 5, 0),
      alignment: Alignment.centerLeft,
      child: CustomWidget.rectangular(
        height: 130,
        width: MediaQuery.of(context).size.width * 0.5,
      ),
    ),
  );
}

Widget getButton3(BuildContext context)
{
  return Expanded(
    child: Container(
      height: 30,
      margin: EdgeInsets.fromLTRB(5, 15, 5, 5),
      alignment: Alignment.centerLeft,
      child: CustomWidget.rectangular(
        height: 35,
        width: MediaQuery.of(context).size.width * 0.5,
      ),
    ),
  );
}

Widget getTextField(BuildContext context)
{
  return Expanded(
    child: Container(
      height: 50,
      margin: EdgeInsets.fromLTRB(10, 0, 5, 0),
      alignment: Alignment.centerLeft,
      child: CustomWidget.rectangular(
        height: 50,
        width: MediaQuery.of(context).size.width * 1,
      ),
    ),
  );
}

Widget getMenuScreenCardLayout(BuildContext context, String textName, String leftIcon, String rightIcon, String screenName)
{
  return Container(
    height: 60,
    decoration: context.showDecoration,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        Container(
          margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(leftIcon),
        ),

        Expanded(
          child: Container(
              margin: EdgeInsets.fromLTRB(5, 0, 10, 0),
              child: getMenuSettingsText(context, textName, screenName)
          ),
        ),

        Container(
          alignment: Alignment.centerRight,
          margin: EdgeInsets.fromLTRB(0, 0, 10, 0),
          child: SvgPicture.asset(rightIcon),
        ),
      ],
    ),
  );
}

Widget getMenuSettingsText(BuildContext context, String titleName, String screenName)
{
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        titleName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
          fontFamily: screenName == "Profile_Screen" ? CommonUtilities.fontTypeAccordingToLang('FontBold') : CommonUtilities.fontTypeAccordingToLang('FontRegular'),
          color: AppColors.darkBlack,
        ),
      ),
    ],
  );
}

Widget getMessage(BuildContext context, String message)
{
  return Container(
    margin: EdgeInsets.fromLTRB(8, 0, 8, 0),
    child: Text(
      message,
      style: TextStyle(
          fontSize:  CommonUtilities.increaseSizeBy2(AppSize.size_14),
          fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
          color: AppColors.darkBlack,height: 1.5), textAlign: TextAlign.center,),
  );
}

void showFullLog(String message)
{
  //  log("------Activ------Message :  $message");
}
