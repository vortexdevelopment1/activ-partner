import 'dart:convert';
import 'dart:io';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../../api_calling/progress_bar/progress_bar.dart';
import '../../../CommonCode.dart';
import 'AddVenueTimingScreen.dart';

class AddVenuePhotoListViewScreen extends StatefulWidget {
  final List<XFile> images;
  const AddVenuePhotoListViewScreen({super.key, required this.images});

  @override
  State<AddVenuePhotoListViewScreen> createState() => _State();
}

class _State extends State<AddVenuePhotoListViewScreen> {
  late List<XFile> _images;
  int? _coverIndex = 0; // by default first image is cover
  GlobalKey _imgKey = GlobalKey();
  String userMobileNumber = '', phoneCode="", activityName = "Activity";


  @override
  void initState() {
    super.initState();
    getData();
    _images = List.from(widget.images); // copy images
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    final raw = checkString(await SharedPreference.readStr("operate_value"));
    if (raw.isNotEmpty) {
      try {
        activityName = checkString(jsonDecode(raw)["title"]);
      } catch (_) {}
    }
    setState(() {});
  }

  void setAsCover(int index) {
    setState(() {
      //_coverIndex = index;
      _coverIndex = 0; // new cover will always be at top

      // Remove selected image from current position
      final selectedImage = _images.removeAt(index);

      // Insert selected image at first position
      _images.insert(0, selectedImage);

      // Update cover index
      _coverIndex = 0;
    });
  }

  void deletePhoto(int index) {
    setState(() {
      _images.removeAt(index);

      if (_coverIndex == index) {
        _coverIndex = _images.isNotEmpty ? 0 : null;
      } else if (_coverIndex != null && index < _coverIndex!) {
        _coverIndex = _coverIndex! - 1;
      }
    });

    if (_images.isEmpty)
    {
      CommonUtilities.callVenueImagesClear = "yes";
      Navigator.pop(context);
    }
  }


  void _showCustomMenu(BuildContext context, Offset position, int index) async {
    final screenWidth = MediaQuery.of(context).size.width;
    const rightMargin = 20;
    const topMargin = 17;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, // x position
        position.dy + topMargin,
        screenWidth - position.dx - rightMargin,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [

        if (_coverIndex != index)
          PopupMenuItem<String>(
            value: 'cover',
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
              child: Text(
                "Set as cover photo",
                style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontMedium',
                  color: AppColors.darkBlack,
                ),
              ),
            ),
          ),

        if (_coverIndex != index)const PopupMenuDivider(height: 0.5),

        PopupMenuItem(
          value: 'delete',
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
            child: Text(
              "Delete photo",
              style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.darkBlack,
              ),
            ),
          ),
        ),
      ],
    );

    if (selected == 'cover') {
      setAsCover(index);
    } else if (selected == 'delete') {
      deletePhoto(index);
    }
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
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                              child: Column(
                                children: [
                                  getActivIcon(),

                                  getStepBarCount(3 / 6, 3, 6),

                                  getText(),

                                  getSubText(),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Container(
                                margin: EdgeInsets.fromLTRB(5, 0, 5, 0),
                                child: _images.isEmpty
                                    ? const Center(child: Text("No images uploaded"))
                                    : ListView.builder(
                                  itemCount: _images.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        Card(
                                          margin: const EdgeInsets.all(10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            children: [

                                              AspectRatio(
                                                aspectRatio: 16/9,
                                                child: Image.file(
                                                  File(_images[index].path),
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: 200,
                                                ),
                                              ),

                                              // "Set as Cover Photo" button
                                             /* if (_coverIndex != index)
                                                TextButton(
                                                  onPressed: () => _setAsCover(index),
                                                  child: const Text(
                                                    "Set as Cover Photo",
                                                    style: TextStyle(color: Colors.purple),
                                                  ),
                                                )
                                              else
                                                const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text(
                                                    "Currently Cover Photo",
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),*/
                                            ],
                                          ),
                                        ),

                                        // Cover Photo label
                                        if (_coverIndex == index)
                                          Positioned(
                                            top: 20,
                                            left: 20,
                                            child: Container(
                                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                              decoration: BoxDecoration(
                                                color: AppColors.darkGray,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.white, width: 1),
                                              ),
                                              child: const Text(
                                                "Cover Photo",
                                                style: TextStyle(
                                                    fontSize: AppSize.size_14,
                                                    fontFamily: 'FontSemiBold',
                                                    color: AppColors.white,
                                                    height: 1
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Delete button
                                        /*Positioned(
                                          top: 15,
                                          right: 15,
                                          child: InkWell(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              padding: const EdgeInsets.all(6),
                                              child: Image.asset('assets/ic_three_dot.png')
                                            ),
                                          ),
                                        ),*/

                                        Positioned(
                                          right: 15,
                                          top: 15,
                                          child: GestureDetector(
                                            onTapDown: (TapDownDetails details) {
                                              _showCustomMenu(context, details.globalPosition, index);
                                            },
                                            child: Container(
                                                width: 50,
                                                height: 50,
                                                padding: const EdgeInsets.all(6),
                                                child: Image.asset('assets/ic_three_dot.png')
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Top Progress

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
                                              child: getBackButton(context, "Back", "venuePhoto"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                          onTap: () async {
                                            if (_images.isEmpty) return; // No images, do nothing

                                            // Show loader
                                            ProgressBar().showLoader(context);

                                            try {
                                              // Get user mobile number
                                              userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));

                                              // Upload images and save to Firestore
                                              /*await saveVenueImagesToFirestore(
                                                userMobileNumber,
                                                _images,
                                              );*/

                                              final user = FirebaseAuth.instance.currentUser;
                                              print("UID: ${user?.uid}");
                                              print("isAnonymous: ${user?.isAnonymous}");

                                              final activityId = await saveActivityWithImages(_images, 'IND (+91)' + userMobileNumber);

                                              // Upload complete, close loader
                                              Navigator.of(context).pop();

                                              print("activityId : " + activityId);

                                              // Navigate to next screen
                                              CommonUtilities.NavigateWithPush(context, AddVenueTimingScreen(activityId: activityId));
                                            } catch (e) {
                                              // Close loader if error occurs
                                              Navigator.of(context).pop();

                                              // Show error message
                                              CommonUtilities.showLog("❌ Image upload failed111: $e");
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("Image upload failed. Please try again.")),
                                              );
                                            }
                                          },
                                          child: _images.isNotEmpty
                                              ? getButtonBlack(context, "Next", "venuePhoto")
                                              : getButtonGray(context, "Next", "venuePhoto"),
                                        )
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),

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

  //----------------------------------------------Start DataBase Image Upload Code----------------------------------------------------

  /*Future<void> ensureAnonymousLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    print("✅ Firebase UID: ${FirebaseAuth.instance.currentUser!.uid}");
  }*/

  Future<String?> uploadImageToFirebase1(String imagePath) async {
    try {

     // await AuthService().ensureAnonymousLogin();

      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      File file = File(imagePath);

      String fileName =
          "venue_${DateTime.now().millisecondsSinceEpoch}.jpg";

      Reference ref = FirebaseStorage.instance
          .ref()
          .child("venue_images")
          .child(uid) // ✅ UID
          .child(fileName);

      UploadTask uploadTask = ref.putFile(file);

      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();

      CommonUtilities.showLog("✅ Uploaded: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      CommonUtilities.showLog("❌ Image upload failed: $e");
      return null;
    }
  }

  Future<void> saveVenueImagesToFirestore1(
      String userNumber,
      List<XFile> images
      ) async {

    //await AuthService().ensureAnonymousLogin();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    List<String> uploadedUrls = [];

    for (var img in images) {
      String? url = await uploadImageToFirebase(
        img.path,
        folderName: "activity_images",
        realUid: "",
      );
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    if (uploadedUrls.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("activ_user")
          .doc(uid) // ✅ UID as doc
          .set(
        {
          //"mobile_number": userNumber, //  business data
          "venue_images": FieldValue.arrayUnion(uploadedUrls),
          "uid": uid,
        },
        SetOptions(merge: true),
      );

      CommonUtilities.showLog("✅ Venue images saved in Firestore");
    }
  }

  /*Future<void> saveVenueImagesToFirestore(
      String userNumber,
      List<XFile> images,
      ) async {

  //  await AuthService().ensureAnonymousLogin();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    List<Map<String, dynamic>> uploadedImages = [];

    for (int i = 0; i < images.length; i++) {
      final img = images[i];

      String? url = await uploadImageToFirebase(img.path);

      if (url != null) {
        uploadedImages.add({
          "url": url,
          "coverPhoto": i == 0, // FIRST IMAGE = COVER
        });
      }
    }

    if (uploadedImages.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("activ_user")
          .doc(uid)
          .set(
        {
          "venue_images": uploadedImages,
          //"uid": uid,
        },
        SetOptions(merge: true),
      );

      CommonUtilities.showLog("✅ Venue images with cover flag saved");
    }
  }*/


  Future<String?> uploadImageToFirebase(
      String imagePath, {
        required String folderName,
        required String realUid, // 👈 ADD THIS
      }) async {
    try {
      File file = File(imagePath);

      String fileName =
          "${folderName}_${DateTime.now().millisecondsSinceEpoch}.jpg";

      Reference ref = FirebaseStorage.instance
          .ref()
          .child(folderName)
          .child(realUid) // ✅ REAL UID
          .child(fileName);

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      CommonUtilities.showLog("❌ Image upload failed: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> uploadActivityImages(
      List<XFile> images,
      String realUid,
      ) async {

    List<Map<String, dynamic>> uploadedImages = [];

    for (int i = 0; i < images.length; i++) {
      final img = images[i];

      String? url = await uploadImageToFirebase(
        img.path,
        folderName: "activity_images",
        realUid: realUid,
      );

      if (url != null) {
        uploadedImages.add({
          "url": url,
          "coverPhoto": i == 0,
        });
      }
    }

    return uploadedImages;
  }


  Future<Map<String, dynamic>> buildActivityPayloadWithImages(
      List<XFile> images,
      String realUid,
      ) async {

    final operateJson = checkString(await SharedPreference.readStr("operate_value"));
    final placeOfferJson = checkString(await SharedPreference.readStr("place_offer"));


    final operateValue = jsonDecode(operateJson);
    final placeOfferMap = placeOfferJson.isEmpty
        ? <String, dynamic>{'place_offer': []}
        : jsonDecode(placeOfferJson);

    final imageList = await uploadActivityImages(images, realUid);

    print("operateValue : $operateValue");
   // print("placeOfferMap : $placeOfferMap");
    print("imageList : $imageList");

    return {
      "activity_id": "act_${DateTime.now().millisecondsSinceEpoch}",

      "operate_value": operateValue,
      "place_offer": placeOfferMap["place_offer"] ?? [],

      "number_of_court": checkString(await SharedPreference.readStr("number_of_court")),
      "flooring_type": checkString(await SharedPreference.readStr("flooring_type")),
      "maximum_capacity": checkString(await SharedPreference.readStr("maximum_capacity")),
      "description": checkString(await SharedPreference.readStr("description")),
      "activity_status": "true",

      "images": imageList,
      //"created_at": Timestamp.now(),
    };
  }

  Future<String> saveActivityWithImages(
      List<XFile> images,
      String phoneKey, // "+91XXXXXXXXXX"
      ) async {

    print("phoneKey : " + phoneCode+userMobileNumber);
    print("phoneKey1 : " + phoneKey);

    // 1️⃣ Resolve REAL UID
    final phoneDoc = await FirebaseFirestore.instance
        .collection("users_by_phone")
        .doc(phoneKey)
        .get();

    if (!phoneDoc.exists) {
      throw Exception("❌ Phone mapping not found");
    }

    final String realUid = phoneDoc["uid"];

    // 2️⃣ Build activity
    final activityData =
    await buildActivityPayloadWithImages(images, realUid);


    // 3️⃣ Save under REAL UID
    await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(realUid)
        .set(
      {
        "activity_list": FieldValue.arrayUnion([activityData]),
      },
      SetOptions(merge: true),
    );

    CommonUtilities.showLog("✅ Activity saved for real UID act_${DateTime.now().millisecondsSinceEpoch}");

    return activityData["activity_id"];
  }


//----------------------------------------------End DataBase Image Upload Code----------------------------------------------------

  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.only(top: 10),
        child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain)
    );
  }

  Widget getText()
  {
    return Container(
      margin: EdgeInsets.only(top: 5),
      alignment: Alignment.centerLeft,
      child: Text(
        activityName,
        style: const TextStyle(
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
        "Upload this activity's images",
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
}


