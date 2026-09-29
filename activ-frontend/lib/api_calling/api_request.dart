import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../Style/app_size.dart';


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
  var data = null;
  ParserBasic({required this.status, required this.message, this.data});
  ParserBasic.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    //data = json['data'] != null ? json['data'] : null;
    //data = json;
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['message'] = this.message;
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
    // prefs = await SharedPreferences.getInstance();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }

  static getStringValuesSF(String key) async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return String
    String? stringValue = prefs.getString(key);

    AppSize.user_id = stringValue!;
    return stringValue;
    //return Future.delayed(Duration(seconds: 2), () => stringValue);
  }

  static clearSF() async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  static remove(String key) async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(key);
  }

  static Future<String?> readStr(keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = keys;
      final value = prefs.getString(key) ?? null;
      return value;
    } catch (e) {
     // print(e);
      return null;
    }
  }

}

