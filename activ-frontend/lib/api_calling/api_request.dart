import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../Style/app_size.dart';
import '../Utills/browser_session.dart';


//Response call back
class Response {
  final bool status;
  final String? message;
  final int status_code;
  String? response_data;
  Response(this.status, this.message, this.status_code, this.response_data);


  Response.fromJson(Map<String, dynamic> json)
      : status = json['status'],
        message = json['message'],
        status_code = json['status_code'],
        response_data = json['response_data'];

  Map<String, dynamic> toJson() =>
      {
        'status': status,
        'message': message,
        'status_code': status_code,
        'response_data': response_data,
      };
}

//Basic parser
class ParserBasic {
  String? status;
  String? message;
  var data;
  ParserBasic({required this.status, required this.message, this.data});
  ParserBasic.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    //data = json['data'] != null ? json['data'] : null;
    //data = json;
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    //data = this.data;
    return data;
  }
}

//Main API calling Class
class ApiRequest {
  int connectTimeout = 10;
  int writeTimeout = 10;
  int readTimeout = 30;

}

class SharedPreference
{
  // Here you create your sharepref instance to be used for further uses
  static Future<SharedPreferences> storage(){
    return SharedPreferences.getInstance();
  }

  static addStringToSF(String key, String value) async
  {
    if (isBrowserSession) {
      writeBrowserSession(key, value);
      return;
    }
    // prefs = await SharedPreferences.getInstance();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static getStringValuesSF(String key) async
  {
    if (isBrowserSession) {
      final value = readBrowserSession(key);
      AppSize.user_id = value ?? '';
      return value;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return String
    String? stringValue = prefs.getString(key);

    AppSize.user_id = stringValue!;
    return stringValue;
    //return Future.delayed(Duration(seconds: 2), () => stringValue);
  }

  static clearSF() async
  {
    if (isBrowserSession) {
      clearBrowserSession();
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static remove(String key) async
  {
    if (isBrowserSession) {
      removeBrowserSession(key);
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<String?> readStr(keys) async {
    if (isBrowserSession) return readBrowserSession(keys.toString());
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = keys;
      final value = prefs.getString(key);
      return value;
    } catch (e) {
     // print(e);
      return null;
    }
  }

}

