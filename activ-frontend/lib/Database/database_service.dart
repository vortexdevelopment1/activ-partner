import 'dart:io';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../Utills/common_utilities.dart';


class DatabaseService {
  final String? uid;
  DatabaseService({this.uid});

  // reference for our collections
  final CollectionReference usersCollections  = FirebaseFirestore.instance.collection("activ_user");
  final CollectionReference venueOperateTypeCollection = FirebaseFirestore.instance.collection("venue_operate_type");
  final CollectionReference venueFacilitiesTypeCollection = FirebaseFirestore.instance.collection("venue_facilities_type");

  final CollectionReference userCollection = FirebaseFirestore.instance.collection("users");
  //final CollectionReference mobileCollection = FirebaseFirestore.instance.collection("mobile");
  final CollectionReference playersCollection = FirebaseFirestore.instance.collection("players");
  final CollectionReference groupCollection = FirebaseFirestore.instance.collection("groups");

  // saving the userdata
  /// 💾 Save / Update user data
  Future savingUserData(
      String uid,
      String countryCode,
      String mobile,
      String fullName,
      String otp,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName,
      ) async {
    try {
      return await usersCollections.doc(uid).set({
        "uid": uid,
        "country_code": countryCode,
        "mobile_number": mobile,
        "full_name": fullName,
        "otp": otp,
        "deviceType": deviceType,
        "appVersionName": appVersionName,
        "appVersionCode": appVersionCode,
        "deviceName": deviceName,
        "deviceVersion": deviceVersion,
        "dateTime": dateTime,
        "screenName": screenName,
      }, SetOptions(merge: true));
    } catch (e) {
      CommonUtilities.showLog("❌ Firestore Error: $e");
      rethrow;
    }
  }


  Future savingUserData1(
      String countryCode,
      String mobile,
      String fullName,
      String otp,
      String deviceType,
      String appVersionName,
      String appVersionCode,
      String deviceName,
      String deviceVersion,
      String dateTime,
      String screenName) async {
    try {
      return await usersCollections.doc(uid).set({
        "countryCode": countryCode,
        "mobileNumber": mobile,
        "fullName": fullName,
        "otp": otp,
        "deviceType": deviceType,
        "appVersionName": appVersionName,
        "appVersionCode": appVersionCode,
        "deviceName": deviceName,
        "deviceVersion": deviceVersion,
        "dateTime": dateTime,
        "screenName": screenName,
      }, SetOptions(merge: true));
    } catch (e) {
      CommonUtilities.showLog("Firestore Error111111111111 : $e");
      rethrow;
    }
  }


  Future<bool> checkIfUserExists(String mobileNumber) async {
    try {
      QuerySnapshot snapshot = await usersCollections
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      CommonUtilities.showLog("Error checking user existence: $e");
      return false;
    }
  }


  // Function to save venue options with images
  Future<bool> saveJsonArrayWithImages() async {
    try {
     /* await FirebaseFirestore.instance.collection("venue_operate_type").add({
        "venue_type": [
          {"id": "1", "title": "Swimming pool", "type": "pool", "description": "Indoor or outdoor pool facility", "image": ""},
          {"id": "2", "title": "Gym", "type": "gym", "description": "Fitness centre with equipment", "image": ""},
          {"id": "3", "title": "Badminton Court", "type": "court", "description": "Indoor or outdoor court", "image": ""},
          {"id": "4", "title": "Football Turf", "type": "football", "description": "Ground for football", "image": ""},
          {"id": "5", "title": "Yoga Studio", "type": "yoga", "description": "Space for yoga or wellness", "image": ""},
          {"id": "6", "title": "Martial Arts", "type": "arts", "description": "Dojo or training facility", "image": ""},
          {"id": "7", "title": "Dance Studio", "type": "dance", "description": "Space for dance & movement", "image": ""},
          {"id": "8", "title": "Others", "type": "others", "description": "Other type of fitness venue", "image": ""},
        ]
      });*/

      // Example: convert asset to file
      File poolFile = await assetToFile("assets/ic_pool.png");
      String poolUrl = await uploadImage(poolFile.path, "pool.png");

      File gymFile = await assetToFile("assets/ic_gym.png");
      String gymUrl = await uploadImage(gymFile.path, "gym.png");

      File cockFile = await assetToFile("assets/ic_cock.png");
      String cockUrl = await uploadImage(cockFile.path, "ic_cock.png");

      File footballFile = await assetToFile("assets/ic_football.png");
      String footballUrl = await uploadImage(footballFile.path, "ic_football.png");

      File yogaFile = await assetToFile("assets/ic_yoga.png");
      String yogaUrl = await uploadImage(yogaFile.path, "ic_yoga.png");

      File artsFile = await assetToFile("assets/ic_arts.png");
      String artsUrl = await uploadImage(artsFile.path, "ic_arts.png");

      File danceFile = await assetToFile("assets/ic_dance.png");
      String danceUrl = await uploadImage(danceFile.path, "ic_dance.png");

      File otherFile = await assetToFile("assets/ic_other.png");
      String otherUrl = await uploadImage(otherFile.path, "ic_other.png");


      await FirebaseFirestore.instance
          .collection("venue_operate_type")
          .doc("main_document")
          .set({
        "venue_type": [
          {"id": "1", "title": "Swimming pool", "type": "pool", "description": "Indoor or outdoor pool facility", "image": poolUrl, "active": true},
          {"id": "2", "title": "Gym", "type": "gym", "description": "Fitness centre with equipment", "image": gymUrl, "active": true},
          {"id": "3", "title": "Badminton Court", "type": "court", "description": "Indoor or outdoor court", "image": cockUrl, "active": true},
          {"id": "4", "title": "Football Turf", "type": "football", "description": "Ground for football", "image": footballUrl, "active": true},
          {"id": "5", "title": "Yoga Studio", "type": "yoga", "description": "Space for yoga or wellness", "image": yogaUrl, "active": true},
          {"id": "6", "title": "Martial Arts", "type": "arts", "description": "Dojo or training facility", "image": artsUrl, "active": true},
          {"id": "7", "title": "Dance Studio", "type": "dance", "description": "Space for dance & movement", "image": danceUrl, "active": true},
          {"id": "8", "title": "Others", "type": "others", "description": "Other type of fitness venue", "image": otherUrl, "active": true},
        ]
      }, SetOptions(merge: true)); // merge:true → field update only

      return true; // Success
    } catch (e) {
      CommonUtilities.showLog("Error saving venue options: $e");
      return false;
    }
  }

  // Upload single image to Firebase Storage
  Future<String> uploadImage(String filePath, String fileName) async {
    Reference ref = FirebaseStorage.instance.ref().child("images/$fileName");
    UploadTask uploadTask = ref.putFile(File(filePath));
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  // Convert asset to temporary file
  Future<File> assetToFile(String assetPath) async {
    ByteData byteData = await rootBundle.load(assetPath);
    final file = File('${(await getTemporaryDirectory()).path}/${assetPath.split('/').last}');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  // State Name
  Future<bool> saveJsonArrayState() async {
    try {
      await FirebaseFirestore.instance
          .collection("activ_state_name")
          .doc("state_document")
          .set({
        "state_name": [
          {"id": "1", "name": "Andaman and Nicobar Islands", "active": true},
          {"id": "2", "name": "Andhra Pradesh", "active": true},
          {"id": "3", "name": "Arunachal Pradesh", "active": true},
          {"id": "4", "name": "Assam", "active": true},
          {"id": "5", "name": "Bihar", "active": true},
          {"id": "6", "name": "Chandigarh", "active": true},
          {"id": "7", "name": "Chhattisgarh", "active": true},
          {"id": "8", "name": "Dadra and Nagar Haveli and Daman and Diu", "active": true},
          {"id": "9", "name": "Delhi (NCT of Delhi)", "active": true},
          {"id": "10", "name": "Goa", "active": true},
          {"id": "11", "name": "Gujarat", "active": true},
          {"id": "12", "name": "Haryana", "active": true},
          {"id": "13", "name": "Himachal Pradesh", "active": true},
          {"id": "14", "name": "Jammu and Kashmir", "active": true},
          {"id": "15", "name": "Jharkhand", "active": true},
          {"id": "16", "name": "Karnataka", "active": true},
          {"id": "17", "name": "Kerala", "active": true},
          {"id": "18", "name": "Ladakh", "active": true},
          {"id": "19", "name": "Lakshadweep", "active": true},
          {"id": "20", "name": "Madhya Pradesh", "active": true},
          {"id": "21", "name": "Maharashtra", "active": true},
          {"id": "22", "name": "Manipur", "active": true},
          {"id": "23", "name": "Meghalaya", "active": true},
          {"id": "24", "name": "Mizoram", "active": true},
          {"id": "25", "name": "Nagaland", "active": true},
          {"id": "26", "name": "Odisha", "active": true},
          {"id": "27", "name": "Punjab", "active": true},
          {"id": "28", "name": "Rajasthan", "active": true},
          {"id": "29", "name": "Sikkim", "active": true},
          {"id": "30", "name": "Tamil Nadu", "active": true},
          {"id": "31", "name": "Telangana", "active": true},
          {"id": "32", "name": "Tripura", "active": true},
          {"id": "33", "name": "Uttar Pradesh", "active": true},
          {"id": "34", "name": "Uttarakhand", "active": true},
          {"id": "35", "name": "West Bengal", "active": true},
          {"id": "36", "name": "Puducherry", "active": true}
        ]
      }, SetOptions(merge: true)); // merge:true → field update only
      return true; // Success
    } catch (e) {
      CommonUtilities.showLog("Error saving state options: $e");
      return false;
    }
  }

  // Function to save customers facilities type
  Future<bool> saveDummyFacilitiesToFirestore1() async {

    // Example: convert asset to file
    File parking = await assetToFile("assets/placeOffer/ic_parking.png");
    String parkingUrl = await uploadImage(parking.path, "ic_parking.png");

    File kitFile = await assetToFile("assets/placeOffer/ic_health.png");
    String kitUrl = await uploadImage(kitFile.path, "ic_health.png");

    File wifiFile = await assetToFile("assets/placeOffer/ic_wifi.png");
    String wifiUrl = await uploadImage(wifiFile.path, "ic_wifi.png");

    File airFile = await assetToFile("assets/placeOffer/ic_air.png");
    String airUrl = await uploadImage(airFile.path, "ic_air.png");

    File roomFile = await assetToFile("assets/placeOffer/ic_locker.png");
    String roomUrl = await uploadImage(roomFile.path, "ic_locker.png");

    File room1File = await assetToFile("assets/placeOffer/ic_lounge.png");
    String room1Url = await uploadImage(room1File.path, "ic_lounge.png");

    File trainingFile = await assetToFile("assets/placeOffer/ic_trainer.png");
    String trainingUrl = await uploadImage(trainingFile.path, "ic_trainer.png");

    File fencingFile = await assetToFile("assets/placeOffer/ic_fencing.png");
    String fencingUrl = await uploadImage(fencingFile.path, "ic_fencing.png");

    File lightingFile = await assetToFile("assets/placeOffer/ic_lighting.png");
    String lightingUrl = await uploadImage(lightingFile.path, "ic_lighting.png");

    File showerFile = await assetToFile("assets/placeOffer/ic_shower_room.png");
    String showerUrl = await uploadImage(showerFile.path, "ic_shower_room.png");

    File soundFile = await assetToFile("assets/placeOffer/ic_sound.png");
    String soundUrl = await uploadImage(soundFile.path, "ic_sound.png");

    File childCareFile = await assetToFile("assets/placeOffer/ic_child_care.png");
    String childCareUrl = await uploadImage(childCareFile.path, "ic_child_care.png");

    File securityFile = await assetToFile("assets/placeOffer/ic_security_camera.png");
    String securityUrl = await uploadImage(securityFile.path, "ic_security_camera.png");

    File rentalFile = await assetToFile("assets/placeOffer/ic_rental.png");
    String rentalUrl = await uploadImage(rentalFile.path, "ic_rental.png");


    try {
      await FirebaseFirestore.instance
          .collection("customer_facilities_type")
          .doc("facilities_type")
          .set({
        "facilities": [
          {
            "id": "1",
            "title": "Free Parking",
            "type": "parking",
            "description": "Facility for free parking",
            "image": parkingUrl,
            "active": true
          },
          {
            "id": "2",
            "title": "First Aid Kit",
            "type": "health",
            "description": "Availability of first aid kit",
            "image": kitUrl,
            "active": true
          },
          {
            "id": "3",
            "title": "Wifi",
            "type": "wifi",
            "description": "Free wifi facility",
            "image": wifiUrl,
            "active": true
          },
          {
            "id": "4",
            "title": "Air Conditioned",
            "type": "ac",
            "description": "Air conditioned rooms",
            "image": airUrl,
            "active": true
          },
          {
            "id": "5",
            "title": "Locker Room",
            "type": "locker",
            "description": "Locker room facility",
            "image": roomUrl,
            "active": true
          },
          {
            "id": "6",
            "title": "Lounge Room",
            "type": "lounge",
            "description": "Lounge area",
            "image": room1Url,
            "active": true
          },
          {
            "id": "7",
            "title": "Personal Training",
            "type": "trainer",
            "description": "Personal training facility",
            "image": trainingUrl,
            "active": true
          },
          {
            "id": "8",
            "title": "Fencing",
            "type": "fencing",
            "description": "Fencing area",
            "image": fencingUrl,
            "active": true
          },
          {
            "id": "9",
            "title": "Proper Lighting",
            "type": "lighting",
            "description": "Proper lighting facility",
            "image": lightingUrl,
            "active": true
          },
          {
            "id": "10",
            "title": "Shower Room",
            "type": "shower",
            "description": "Shower room facility",
            "image": showerUrl,
            "active": true
          },
          {
            "id": "11",
            "title": "Sound System",
            "type": "sound",
            "description": "Sound system facility",
            "image": soundUrl,
            "active": true
          },
          {
            "id": "12",
            "title": "Childcare",
            "type": "childcare",
            "description": "Childcare facility",
            "image": childCareUrl,
            "active": true
          },
          {
            "id": "13",
            "title": "Surveillance cameras",
            "type": "security",
            "description": "Surveillance cameras for safety",
            "image": securityUrl,
            "active": true
          },
          {
            "id": "14",
            "title": "Rental Equipments",
            "type": "rental",
            "description": "Rental equipments available",
            "image": rentalUrl,
            "active": true
          }
        ]
      }, SetOptions(merge: true));

      CommonUtilities.showLog("Facilities saved successfully in desired format!");
      return true;
    } catch (e) {
      CommonUtilities.showLog("Error saving facilities: $e");
      return false;
    }
  }


  Future<bool> saveDummyFacilitiesToFirestore() async {
    try {
      CommonUtilities.showLog("🚀 Starting facilities upload...");

      // Upload images safely
      String parkingUrl = await _safeUpload("assets/placeOffer/ic_parking.png", "ic_parking.png");
      String kitUrl = await _safeUpload("assets/placeOffer/ic_health.png", "ic_health.png");
      String wifiUrl = await _safeUpload("assets/placeOffer/ic_wifi.png", "ic_wifi.png");
      String airUrl = await _safeUpload("assets/placeOffer/ic_air.png", "ic_air.png");
      String roomUrl = await _safeUpload("assets/placeOffer/ic_locker.png", "ic_locker.png");
      String room1Url = await _safeUpload("assets/placeOffer/ic_lounge.png", "ic_lounge.png");
      String trainingUrl = await _safeUpload("assets/placeOffer/ic_trainer.png", "ic_trainer.png");
      String fencingUrl = await _safeUpload("assets/placeOffer/ic_fencing.png", "ic_fencing.png");
      String lightingUrl = await _safeUpload("assets/placeOffer/ic_lighting.png", "ic_lighting.png");
      String showerUrl = await _safeUpload("assets/placeOffer/ic_shower_room.png", "ic_shower_room.png");
      String soundUrl = await _safeUpload("assets/placeOffer/ic_sound.png", "ic_sound.png");
      String childCareUrl = await _safeUpload("assets/placeOffer/ic_child_care.png", "ic_child_care.png");
      String securityUrl = await _safeUpload("assets/placeOffer/ic_security_camera.png", "ic_security_camera.png");
      String rentalUrl = await _safeUpload("assets/placeOffer/ic_rental.png", "ic_rental.png");

      //  Firestore insert (THIS WAS NEVER REACHED EARLIER)
      await FirebaseFirestore.instance
          .collection("customer_facilities_type")
          .doc("facilities_type")
          .set({
        "facilities": [
          {
            "id": "1",
            "title": "Free Parking",
            "type": "parking",
            "image": parkingUrl,
            "active": true
          },
          {
            "id": "2",
            "title": "First Aid Kit",
            "type": "health",
            "image": kitUrl,
            "active": true
          },
          {
            "id": "3",
            "title": "Wifi",
            "type": "wifi",
            "image": wifiUrl,
            "active": true
          },
          {
            "id": "4",
            "title": "Air Conditioned",
            "type": "ac",
            "image": airUrl,
            "active": true
          },
          {
            "id": "5",
            "title": "Locker Room",
            "type": "locker",
            "image": roomUrl,
            "active": true
          },
          {
            "id": "6",
            "title": "Lounge Room",
            "type": "lounge",
            "image": room1Url,
            "active": true
          },
          {
            "id": "7",
            "title": "Personal Training",
            "type": "trainer",
            "image": trainingUrl,
            "active": true
          },
          {
            "id": "8",
            "title": "Fencing",
            "type": "fencing",
            "image": fencingUrl,
            "active": true
          },
          {
            "id": "9",
            "title": "Proper Lighting",
            "type": "lighting",
            "image": lightingUrl,
            "active": true
          },
          {
            "id": "10",
            "title": "Shower Room",
            "type": "shower",
            "image": showerUrl,
            "active": true
          },
          {
            "id": "11",
            "title": "Sound System",
            "type": "sound",
            "image": soundUrl,
            "active": true
          },
          {
            "id": "12",
            "title": "Childcare",
            "type": "childcare",
            "image": childCareUrl,
            "active": true
          },
          {
            "id": "13",
            "title": "Surveillance cameras",
            "type": "security",
            "image": securityUrl,
            "active": true
          },
          {
            "id": "14",
            "title": "Rental Equipments",
            "type": "rental",
            "image": rentalUrl,
            "active": true
          }
        ]
      }, SetOptions(merge: true));

      CommonUtilities.showLog("✅ Facilities saved successfully in Firestore");
      return true;
    } catch (e) {
      CommonUtilities.showLog("❌ saveDummyFacilitiesToFirestore error => $e");
      return false;
    }
  }

  Future<String> _safeUpload(String assetPath, String fileName) async {
    try {
      File file = await assetToFile1(assetPath);
      return await uploadImage1(file.path, fileName);
    } catch (e) {
      CommonUtilities.showLog("⚠️ Image upload failed ($fileName), using empty url");
      return ""; //  Firestore insert WILL STILL WORK
    }
  }

  Future<String> uploadImage1(String filePath, String fileName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    try {
      Reference ref =
      FirebaseStorage.instance.ref().child("/images/$fileName");

      TaskSnapshot snapshot = await ref.putFile(File(filePath));
      String url = await snapshot.ref.getDownloadURL();

      CommonUtilities.showLog("✅ Uploaded $fileName");
      return url;
    } catch (e) {
      CommonUtilities.showLog("❌ uploadImage failed for $fileName => $e");
      rethrow;
    }
  }

  Future<File> assetToFile1(String assetPath) async {
    ByteData byteData = await rootBundle.load(assetPath);
    final file = File(
      '${(await getTemporaryDirectory()).path}/${assetPath.split('/').last}',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }


  // getting user data
  Future gettingUserData(String email) async {
    QuerySnapshot snapshot =
    await userCollection.where("email", isEqualTo: email).get();
    return snapshot;
  }

  // get group members
  getGroupMembers(groupId) async {
    return usersCollections.doc(groupId).snapshots();
  }

  ///  Get current user document by UID
  Stream<DocumentSnapshot> getUserData() {
    return usersCollections.doc(uid).snapshots();
  }
}

