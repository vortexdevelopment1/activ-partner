import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../api_calling/api_request.dart';

class CommonUtilities
{
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const double padding =20;
  static int limit = 20;
  static int setIndex=0;
  static String mobile_auth_token = "";
  static String callVenueImagesClear = "";
  static String firstTimeLoginSignup = "";
  static String selectedActivityName = "";
  static String addActivitySuccessfully = "";

  static Future<String> getValueFromSharedPreference(String key) async
  {
    String? value = await SharedPreference.readStr(key);
    if(value==null){
      value = "";
    }
    else if(value=="" || value=="null")
    {
      value = "";
    }else{}

    return value;
  }

  static void createSnackBar(BuildContext context, String message)
  {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0
    );
  }

  static void createSnackBarLong(BuildContext context, String message)
  {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0
    );
  }



  static void logout(BuildContext context, String message)
  {
    //FCMNotification.user_id = "";
    createSnackBar(context, message);
    updateSharedPreference();
    //CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, HomeScreen());
  }

  static NavigateWithPush(BuildContext context, Widget obj)
  {
    Navigator.push(context,PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => obj,
      transitionDuration: Duration.zero,reverseTransitionDuration: Duration.zero,
    ),
    );
  }

  static NavigateWithPushReplacment(BuildContext context, Widget obj)
  {
    Navigator.pushReplacement(context,PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => obj as Widget,
      transitionDuration: Duration.zero,reverseTransitionDuration: Duration.zero,
    ),
    );
  }

  static NavigateWithPushAndKillAllPriviousScreens(BuildContext context, Widget obj)
  {
    Navigator.pushAndRemoveUntil<dynamic>(context,MaterialPageRoute<dynamic>(
      builder: (BuildContext context) => obj,
    ),
          (route) => false,//if you want to disable back feature set to false
    );
  }

  static Future<void> updateSharedPreference() async
  {
    String? is_remember = await SharedPreference.readStr("is_remember");
    String? is_app_tour_show = await SharedPreference.readStr("is_app_tour_show");
    String? email = await SharedPreference.readStr("email");

    String? lastNotificationPermissionPopupDate = await SharedPreference.readStr("lastNotificationPermissionPopupDate"); // Before shared preference clear Notification Popup Show Onece's a Day Value Get

    SharedPreference.addStringToSF("user_id","");
    SharedPreference.clearSF();

    if(is_remember=='true')
    {
      //SharedPreference.addStringToSF("is_remember",is_remember);
      SharedPreference.addStringToSF("is_remember", is_remember ?? "false");
      SharedPreference.addStringToSF("email",email ?? "");
    }
    else{}

    SharedPreference.addStringToSF("is_app_tour_show",is_app_tour_show ?? "");

    SharedPreference.addStringToSF("lastNotificationPermissionPopupDate",lastNotificationPermissionPopupDate ?? ""); // After shared preference clear Notification Popup Show Onece's a Day Value Set Again
  }


  static void showLog(String message)
  {
    print("------Activ------Message :  $message");
  }


  static bool emailVaidatation(String email)
  {
    bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
    return emailValid;
  }

  static bool passwordVaidatation(String value)
  {
    String  pattern = r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$';
    RegExp regExp = new RegExp(pattern);
    return regExp.hasMatch(value);
  }

  /*-----------------------Date Formator - Start----------------------*/

  static String converDateFormate(String value, String sourceFormate, String targetFormet)
  {
    if (value!=null && !value.isEmpty)
    {
      var dateTime = DateTime.parse(value);
      final DateTime now = dateTime;
      //final DateTime now = DateTime.now();
      //final DateFormat formatter = DateFormat('yyyy-MM-dd');// HH:mm:ss
      final DateFormat formatter = DateFormat(targetFormet); // HH:mm:ss
      final String formatted = formatter. format(now);
      //print(formatted); // something like 2013-04-20

      return formatted==null?"":formatted;
    } else {
      return "";
    }
  }

  static TargetPlatform getPlatform(BuildContext context)
  {
    var platform1 = Theme.of(context).platform;
    var platform = TargetPlatform.iOS;
    return platform1;
  }

  static TargetPlatform getCurrentPlatform() {
    if (Platform.isAndroid) {
      return TargetPlatform.android;
    } else {
      return TargetPlatform.iOS;
    }
  }

  static double increaseSizeBy2(double size)
  {
    double finalSize = 0;

    finalSize = size;

    return finalSize;
  }

  static String fontTypeAccordingToLang(String fontType)
  {
    String finalFontType = "";

    finalFontType = fontType;

    return finalFontType;
  }

  static FontWeight fontWeightAccordingToLang(FontWeight fontWeight)
  {
    FontWeight finalFontWeight;

    finalFontWeight = FontWeight.w700;

    return finalFontWeight;
  }
}



