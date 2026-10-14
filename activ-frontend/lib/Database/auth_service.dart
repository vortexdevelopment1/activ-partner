import 'package:activ_app/Utills/common_utilities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'database_service.dart';

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  Future<void> ensureLoggedIn() async {
    if (firebaseAuth.currentUser == null) {
      await firebaseAuth.signInAnonymously();
      CommonUtilities.showLog("✅ Anonymous login successful");
    }
  }

  // Use This One
  Future<void> ensureAnonymousLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    CommonUtilities.showLog("✅ Firebase UID: ${FirebaseAuth.instance.currentUser!.uid}");
  }

  // login
  Future loginWithUserNameandPassword(String email, String password) async {
    try {
      User? user = (await firebaseAuth.signInWithEmailAndPassword(email: email, password: password)).user;

      if (user != null) {
        return true;
      }
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // register
  /*Future registerUserWithEmailandPassword(
     String countryCode,  String fullName, String email, String password) async {
    try {
      User? user = (await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password)).user;

      if (user != null) {
        // call our database service to update the user data.
       // await DatabaseService(uid: user.uid).savingUserData(countryCode, fullName, email, "");
        return true;
      }
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }*/

  Future<String> ensureFirebaseLogin() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      UserCredential cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    CommonUtilities.showLog("✅ Firebase UID: ${user!.uid}");
    return user.uid;
  }

  // Using Mobile Number
 /* Future registerWithNumber1(
      String countryCode,
      String number,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName
      ) async {
    try {
      //User? user = (await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password)).user;

      String last4DigitsMobileNumber = number.toString().trim().substring(number.toString().trim().length - 4);
      print("My Mobile Number : ${number.toString().trim()}");

      // call our database service to update the user data.
      await DatabaseService(uid: number).savingUserData(
          countryCode,
          number, "",
          last4DigitsMobileNumber,
          deviceType,
          appVersionName,
          appVersionCode,
          deviceName,
          deviceVersion,
          dateTime,
          screenName);
      return true;
    } on FirebaseAuthException catch (e) {
      print("111111111111 : " + e.message.toString());
      return e.message;
    }
  }*/

  /// Register / Login with mobile number
  Future registerWithNumber11(
      String countryCode,
      String number,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName,
      ) async {
    try {
      //  STEP 1: get Firebase UID
    //  String uid = await ensureFirebaseLogin();
      String uid = FirebaseAuth.instance.currentUser!.uid;

      String last4Digits =
      number.trim().substring(number.trim().length - 4);

      //  STEP 2: Save using UID (NOT number)
      await DatabaseService(uid: uid).savingUserData(
        uid,
        countryCode,
        number,
        "",
        last4Digits,
        deviceType,
        appVersionName,
        appVersionCode,
        deviceName,
        deviceVersion,
        dateTime,
        screenName,
      );

      return true;
    } catch (e) {
      CommonUtilities.showLog("❌ registerWithNumber error: $e");
      return e.toString();
    }
  }

  Future<void> resetAnonymousUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.isAnonymous) {
      await user.delete();
      CommonUtilities.showLog("🧹 Anonymous user deleted");
    }
  }


  Future<bool> registerWithNumber1(
      String countryCode,
      String number,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName,
      ) async {
    try {

      String uid = FirebaseAuth.instance.currentUser!.uid;

      String last4Digits = number.trim().substring(number.trim().length - 4);

      // STEP 2: Reference by UID
      final docRef = FirebaseFirestore.instance.collection("activ_user").doc(uid);

      final docSnapshot = await docRef.get();

      // ================= STEP 3: EXISTING USER =================
      if (docSnapshot.exists) {
        CommonUtilities.showLog("User already exists → updating metadata only");

        await docRef.set(
          {
            "uid": uid,
            "basic_details": {
              "deviceType": deviceType,
              "appVersionName": appVersionName,
              "appVersionCode": appVersionCode,
              "deviceName": deviceName,
              "deviceVersion": deviceVersion,
              "lastLogin": dateTime,
              "screenName": screenName,
            }
          },
          SetOptions(merge: true),
        );
      }
      // STEP 4: ================= NEW USER =================
      else {
        CommonUtilities.showLog("🆕 New user → creating document");

        await docRef.set({
          "uid": uid,
          "basic_details": {
            "countryCode": countryCode,
            "mobile": number,
            "otp": last4Digits,
            "deviceType": deviceType,
            "appVersionName": appVersionName,
            "appVersionCode": appVersionCode,
            "deviceName": deviceName,
            "deviceVersion": deviceVersion,
            "createdAt": dateTime,
            "screenName": screenName,
          }
        });
      }

      return true;

    } catch (e) {
      CommonUtilities.showLog("❌ registerWithNumber error: $e");
      return false;
    }
  }

  Future<bool> registerWithNumberPrevious1(
      String countryCode,
      String number,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName,
      ) async {
    try {

      String uid = FirebaseAuth.instance.currentUser!.uid;

      String last4Digits = number.trim().substring(number.trim().length - 4);

      // STEP 2: Reference by UID
      final docRef = FirebaseFirestore.instance.collection("activ_user").doc(uid);

      final docSnapshot = await docRef.get();

      // ================= STEP 3: EXISTING USER =================
      if (docSnapshot.exists) {
        CommonUtilities.showLog("User exists → update metadata");

        await docRef.update({
          "basic_details.deviceType": deviceType,
          "basic_details.appVersionName": appVersionName,
          "basic_details.appVersionCode": appVersionCode,
          "basic_details.deviceName": deviceName,
          "basic_details.deviceVersion": deviceVersion,
          "basic_details.lastLogin": dateTime,
          "basic_details.screenName": screenName,
        });
      }
      // STEP 4: ================= NEW USER =================
      else {
        CommonUtilities.showLog("🆕 New user");

        await docRef.set({
          "uid": uid,
          "basic_details": {
            "countryCode": countryCode,
            "mobile": number,
            "otp": last4Digits,
            "is_profile_completed": false, // ⭐ IMPORTANT
            "deviceType": deviceType,
            "appVersionName": appVersionName,
            "appVersionCode": appVersionCode,
            "deviceName": deviceName,
            "deviceVersion": deviceVersion,
            "createdAt": dateTime,
            "screenName": screenName,
          }
        });

        //  PHONE → UID MAP
        await FirebaseFirestore.instance
            .collection("users_by_phone")
            .doc("$countryCode$number")
            .set({
          "uid": uid,
          "is_profile_completed": false,
          "createdAt": Timestamp.now(),
        });
      }

      return true;

    } catch (e) {
      CommonUtilities.showLog("❌ registerWithNumber error: $e");
      return false;
    }
  }


  Future<bool> registerWithNumberddd(
      String countryCode,
      String number,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName,
      ) async {
    try {
      final String phoneKey = "$countryCode$number";

      // 🔹 Check if phone number already mapped
      final phoneDoc = await FirebaseFirestore.instance
          .collection("users_by_phone")
          .doc(phoneKey)
          .get();

      String uid;

      if (phoneDoc.exists) {
        // 🔁 Existing user → use old UID
        uid = phoneDoc["uid"];
        CommonUtilities.showLog("Existing number → use old UID: $uid");

        // Update metadata in activ_user
        await FirebaseFirestore.instance
            .collection("activ_user")
            .doc(uid)
            .update({
          "basic_details.deviceType": deviceType,
          "basic_details.appVersionName": appVersionName,
          "basic_details.appVersionCode": appVersionCode,
          "basic_details.deviceName": deviceName,
          "basic_details.deviceVersion": deviceVersion,
          "basic_details.lastLogin": dateTime,
          "basic_details.screenName": screenName,
        });

      } else {
        // 🔹 New user → use current Firebase UID
        uid = FirebaseAuth.instance.currentUser!.uid;
        CommonUtilities.showLog("New user → UID: $uid");

        String last4Digits = number.trim().substring(number.trim().length - 4);

        await FirebaseFirestore.instance
            .collection("activ_user")
            .doc(uid)
            .set({
          "uid": uid,
          "basic_details": {
            "countryCode": countryCode,
            "mobile": number,
            "otp": last4Digits,
            "is_profile_completed": false,
            "deviceType": deviceType,
            "appVersionName": appVersionName,
            "appVersionCode": appVersionCode,
            "deviceName": deviceName,
            "deviceVersion": deviceVersion,
            "createdAt": dateTime,
            "screenName": screenName,
          }
        });

        //  Map phone → UID
        await FirebaseFirestore.instance
            .collection("users_by_phone")
            .doc(phoneKey)
            .set({
          "uid": uid,
          "is_profile_completed": false,
          "createdAt": Timestamp.now(),
        });
      }

      return true;
    } catch (e) {
      CommonUtilities.showLog("❌ registerWithNumber error: $e");
      return false;
    }
  }


  Future<bool> registerWithNumber(
      String countryCode,
      String number,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName,
      ) async {
    try {
      final String phoneKey = "$countryCode$number";

      // Check if phone number already mapped
      final phoneDoc = await FirebaseFirestore.instance
          .collection("users_by_phone")
          .doc(phoneKey)
          .get();

      String uid;

      if (phoneDoc.exists) {
        // Existing user → use old UID
        uid = phoneDoc["uid"];
        CommonUtilities.showLog("Existing number → use old UID: $uid");

        // Update metadata in activ_user
        await FirebaseFirestore.instance.collection("activ_user").doc(uid).update({
          "basic_details.deviceType": deviceType,
          "basic_details.appVersionName": appVersionName,
          "basic_details.appVersionCode": appVersionCode,
          "basic_details.deviceName": deviceName,
          "basic_details.deviceVersion": deviceVersion,
          "basic_details.lastLogin": dateTime,
          "basic_details.screenName": screenName,
        });
      } else {
        // New user → use current Firebase UID
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          CommonUtilities.showLog("❌ User not signed in yet!");
          return false;
        }
        uid = currentUser.uid;
        CommonUtilities.showLog("New user → UID: $uid");

        String last4Digits = number.trim().substring(number.trim().length - 4);

        await FirebaseFirestore.instance.collection("activ_user").doc(uid).set({
          "uid": uid,
          "basic_details": {
            "countryCode": countryCode,
            "mobile": number,
            "otp": last4Digits,
            "is_profile_completed": false,
            "deviceType": deviceType,
            "appVersionName": appVersionName,
            "appVersionCode": appVersionCode,
            "deviceName": deviceName,
            "deviceVersion": deviceVersion,
            "createdAt": dateTime,
            "screenName": screenName,
          }
        });

        // Map phone → UID
        await FirebaseFirestore.instance.collection("users_by_phone").doc(phoneKey).set({
          "uid": uid,
          "is_profile_completed": false,
          "createdAt": Timestamp.now(),
        });

        CommonUtilities.showLog("Created users_by_phone document for $phoneKey");
      }

      return true;
    } catch (e) {
      CommonUtilities.showLog("❌ registerWithNumber error: $e");
      return false;
    }
  }



  Future uploadVenueOperateOption() async {
    try {

      // call our database service to update the user data.
      bool result = await DatabaseService().saveJsonArrayWithImages();

      if (result) {
        CommonUtilities.showLog("Users saved successfully!");
      } else {
        CommonUtilities.showLog("Error saving users.");
      }

      return true;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future uploadStateName() async {
    try {

      // call our database service to update the user data.
      bool result = await DatabaseService().saveJsonArrayState();

      if (result) {
        CommonUtilities.showLog("States saved successfully!");
      } else {
        CommonUtilities.showLog("Error saving users.");
      }

      return true;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future uploadFacilitiesName() async {
    try {

      // call our database service to update the user data.
      bool result = await DatabaseService().saveDummyFacilitiesToFirestore();

      if (result) {
        CommonUtilities.showLog("Facilities saved successfully!");
      } else {
        CommonUtilities.showLog("Error saving users.");
      }

      return true;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }


}




  // signout
  /*Future signOut() async {
    try {
      await HelperFunctions.saveUserLoggedInStatus(false);
      await HelperFunctions.saveUserEmailSF("");
      await HelperFunctions.saveUserNameSF("");
      await firebaseAuth.signOut();
    } catch (e) {
      return null;
    }
  }*/


