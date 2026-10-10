// file: string_extensions.dart

import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import '../Style/app_colors.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';

extension CapitalizeExtension on String {
  String capitalize() {
    if (this.isEmpty) return '';
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

extension ReverseExtension on String {
  String reverse() {
    return split('').reversed.join();
  }
}

/*extension CleanStringExtension on Object? {
  String checkString() {
    final value = this?.toString().toLowerCase();
    if (value == null || value == 'null' || value == 'nil') {
      return '';
    } else {
      return this.toString();
    }
  }
}*/

// extension.dart
extension CleanStringExtension on Object? {
  String checkString() {
    final str = this?.toString().trim().toLowerCase();
    if (str == null || str == 'null' || str == 'nil') return '';
    return this.toString();
  }
}

// helper.dart or same file
String checkString(Object? value) => value.checkString(); // uses extension internally


extension ToLowerCaseExtension on String {
  String toSmall() {
    return toLowerCase();
  }
}

// Gradient Extension Code
extension GradientExtension on BuildContext {
  Decoration get getYellowGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.3, 1],
      colors: [
        AppColors.yellowTop,
        AppColors.yellowBottom,
      ],
    ),
  );

  Decoration get getTextFieldGradient => BoxDecoration(
      color: AppColors.white,
      borderRadius:  BorderRadius.only(
        topLeft:  Radius.circular(8),
        topRight:  Radius.circular(8),
        bottomLeft:  Radius.circular(8),
        bottomRight:  Radius.circular(8),
      ),
      border: Border.all(color: AppColors.gray, width: 1)
  );

  Decoration get showDecoration => const BoxDecoration(
    color: AppColors.white,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(12),
      bottomRight: Radius.circular(12),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.gray_border2,
        blurRadius: 10,
        spreadRadius: 0,
        offset: Offset(0, 2),
      ),
    ],
  );

  Decoration get showDecorationMenu => const BoxDecoration(
    color: AppColors.white,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
      bottomLeft: Radius.circular(10),
      bottomRight: Radius.circular(10),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowColor,
        blurRadius:10,
        spreadRadius: 0,
        offset: Offset(0, 2),
      ),
    ],
  );
}


extension DateTimeFormatExtension on DateTime {
  String getCurrentTodayDate(String targetFormat) {
    final DateFormat formatter = DateFormat(targetFormat);
    final String formatted = formatter.format(this);
    //print("InAppReviewStatusChecked_Current_formatted_Date : $formatted");
    return formatted;
  }

  String getCurrentDate(String targetFormat) {
    final DateFormat formatter = DateFormat(targetFormat);
    final String formatted = formatter.format(this);
    return formatted;
  }
}


//----------------------------------------------Start Convert Date Format Code--------------------------------------------------------------
extension DateParsingExtension on String {
  String convertDateFormat(String sourceFormat, String targetFormat) {

    if (this.isEmpty) return "";

    try {
     /* DateTime dateTime = DateFormat(sourceFormat).parse(this);
      return DateFormat(targetFormat).format(dateTime);*/

      DateTime dateTime = DateTime.parse(this);
      return DateFormat(targetFormat).format(dateTime);

    } catch (e) {
      CommonUtilities.showLog("convertDateFormat error: $e");
      return "";
    }
  }
}

String converDateFormate(String value, String sourceFormat, String targetFormat)
{
  return value.convertDateFormat(sourceFormat, targetFormat);
}
//----------------------------------------------End Convert Date Format Code--------------------------------------------------------------

//----------------------------------------------Start UTC to Local Date Format Code--------------------------------------------------------------
extension UTCToLocalStringExtension on String {
  String UTCtoLocal(String sourceFormat, String targetFormat)
  {
    if (this.isEmpty) return "";

    try {
      // Parse UTC date string
      DateTime utcDate = DateFormat(sourceFormat).parse(this, true); // true = parse as UTC
      DateTime localDate = utcDate.toLocal();
      return DateFormat(targetFormat).format(localDate);
    } catch (e) {
      CommonUtilities.showLog("UTCtoLocal error: $e");
      return "";
    }
  }
}

String UTCtoLocal(String date1, String sourceFormat, String targetFormat) {
  return date1.UTCtoLocal(sourceFormat, targetFormat);
}

//----------------------------------------------End UTC to Local Date Format Code--------------------------------------------------------------



// Calling like this
// String formatted = originalDate.convertDateFormat("yyyy-MM-dd HH:mm", "dd MMM yyyy, hh:mm a");

extension DateFormatExtension on String? {
  String convertSlotDateFormat(String sourceFormat, String targetFormat) {
    if (this == null || this!.isEmpty) return '';

    try {
      DateTime dateTime = DateFormat(sourceFormat).parse(this!);
      final DateFormat formatter = DateFormat(targetFormat);
      return formatter.format(dateTime);
    } catch (e) {
      CommonUtilities.showLog("Date parsing error: $e");
      return '';
    }
  }
}

//-------------------------------------------------Start Screen Navigation Calling------------------------------------------------------
// Move Screen to Screen Code, Replace Previous Screen and Remove All Screens Code.
extension NavigationExtension on BuildContext {
  // Move One Screen to Next Screen
  void navigateWithPush(Widget page) {
    Navigator.push(
      this,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // Move One Screen to Next Screen and Previous Screen Replace
  void navigateWithPushReplacement(Widget page) {
    Navigator.pushReplacement(
      this,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // Move One Screen to Next Screen and All Previous Screen Remove
  void navigateWithPushAndKillAllPreviousScreens(Widget page) {
    Navigator.pushAndRemoveUntil(
      this,
      MaterialPageRoute(builder: (_) => page),
          (route) => false,
    );
  }
}
//-------------------------------------------------End Screen Navigation Calling------------------------------------------------------

//-------------------------------------------------Start No Data Found and No Internet Image Show Function------------------------------------------------------
// Extension on String
extension NotDataFoundExtension on String {
  Widget toNotDataFoundWidget(String? currentLanguageCode) {
    switch (this) {
      case NO_DATA_FOUND:
        return SvgPicture.asset(
          (currentLanguageCode != null && currentLanguageCode == "hi")
              ? 'assets/no_data_found_hindi.svg'
              : 'assets/no_data_found.svg',
        );
      case NO_INTERNET:
        return SvgPicture.asset(
          'assets/no_internet.svg',
        );
      default:
        return SvgPicture.asset('');
    }
  }
}

// Top-level function for simplified use
Widget notDataFound(String type, String currentLanguageCode) {
  return type.toNotDataFoundWidget(currentLanguageCode);
}

// Calling Like this
// notDataFound(noDataFound, currentLanguage)

//-------------------------------------------------End No Data Found and No Internet Image Show Function-----------------------------------------------------------