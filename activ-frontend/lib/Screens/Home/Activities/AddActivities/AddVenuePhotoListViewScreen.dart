import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../Utills/common_utilities.dart';
import '../../../../api_calling/api_request.dart';
import '../../../../api_calling/api_constant.dart';
import '../../../../api_calling/progress_bar/progress_bar.dart';
import '../../../CommonCode.dart';
import 'AddVenueTimingScreen.dart';
import '../../../onboarding_widgets.dart';

class _ActivityUploadException implements Exception {
  final String message;
  const _ActivityUploadException(this.message);
}

class AddVenuePhotoListViewScreen extends StatefulWidget {
  final List<XFile> images;
  final ValueChanged<List<XFile>>? onPhotosChanged;
  const AddVenuePhotoListViewScreen({super.key, required this.images, this.onPhotosChanged});

  @override
  State<AddVenuePhotoListViewScreen> createState() => _State();
}

class _State extends State<AddVenuePhotoListViewScreen> {
  late List<XFile> _images;
  int? _coverIndex = 0; // by default first image is cover
  final GlobalKey _imgKey = GlobalKey();
  String userMobileNumber = '', phoneCode="", activityName = "Activity";
  bool _isUploading = false;
  bool _loaderVisible = false;

  void _showUploadLoader() {
    if (!mounted || _loaderVisible) return;
    _loaderVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Center(child: CircularProgressIndicator()),
      ),
    ).whenComplete(() => _loaderVisible = false);
  }

  void _hideUploadLoader() {
    if (!mounted || !_loaderVisible) return;
    _loaderVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }


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
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));
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
    widget.onPhotosChanged?.call(List<XFile>.unmodifiable(_images));

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
                  fontFamily: 'Satoshi',
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
                fontFamily: 'Satoshi',
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
                                  const OnboardingHeader(),

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
                                                child: kIsWeb
                                                    ? Image.network(
                                                        _images[index].path,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: 200,
                                                      )
                                                    : Image.file(
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
                                                    fontFamily: 'Satoshi',
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
                                            if (_images.isEmpty || _isUploading) return;

                                            setState(() => _isUploading = true);

                                            // Show loader
                                            _showUploadLoader();
                                            await Future<void>.delayed(Duration.zero);

                                            try {
                                              final activityId = await _uploadActivityImagesToBackend(_images);

                                              // Upload complete, close loader
                                              _hideUploadLoader();

                                              print("activityId : $activityId");

                                              // Navigate to next screen
                                              CommonUtilities.NavigateWithPush(context, AddVenueTimingScreen(activityId: activityId));
                                            } catch (e) {
                                              // Close loader if error occurs
                                              _hideUploadLoader();

                                              // Show error message
                                              CommonUtilities.showLog("❌ Image upload failed111: $e");
                                              final message = e is _ActivityUploadException
                                                  ? e.message
                                                  : 'Image upload failed. Please try again.';
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(message)),
                                              );
                                            } finally {
                                              if (mounted) setState(() => _isUploading = false);
                                            }
                                          },
                                          child: _images.isNotEmpty && !_isUploading
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

  Future<String> _uploadActivityImagesToBackend(List<XFile> images) async {
    final venueId = checkString(await SharedPreference.readStr('venue_id'));
    final token = checkString(await SharedPreference.readStr('jwt_token'));
    final categoryName = activityName.trim();
    if (venueId.isEmpty || token.isEmpty || categoryName.isEmpty) {
      throw _ActivityUploadException('Your session or activity selection is unavailable. Please sign in again.');
    }

    final categoriesResponse = await http.get(
      Uri.parse(CATEGORIES_URL),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));
    if (categoriesResponse.statusCode == 401) {
      throw _ActivityUploadException('Your session has expired. Please sign in again.');
    }
    if (categoriesResponse.statusCode != 200) {
      throw _ActivityUploadException(
        'Activity setup failed (${categoriesResponse.statusCode}). Please sign in again and retry.',
      );
    }
    final decodedCategories = jsonDecode(categoriesResponse.body);
    final rawCategories = decodedCategories is Map ? decodedCategories['data'] : null;
    final categories = rawCategories is List ? rawCategories : const [];
    final category = categories.cast<Map>().firstWhere(
      (value) => value['name']?.toString().trim().toLowerCase() == categoryName.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    final categoryId = category['id']?.toString() ?? '';
    if (categoryId.isEmpty) {
      throw _ActivityUploadException('This activity is not available for your venue.');
    }

    final createResponse = await http.post(
      Uri.parse('$BASE_URL/venues/$venueId/activities'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'categoryId': categoryId}),
    ).timeout(const Duration(seconds: 30));
    if (createResponse.statusCode == 401) {
      throw _ActivityUploadException('Your session has expired. Please sign in again.');
    }
    if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
      throw _ActivityUploadException(
        'Activity setup failed (${createResponse.statusCode}). Please try again.',
      );
    }
    final created = jsonDecode(createResponse.body);
    final data = created is Map ? created['data'] : null;
    final serviceId = data is Map ? data['id']?.toString() : null;
    if (serviceId == null || serviceId.isEmpty) {
      throw _ActivityUploadException('Activity was created without an upload reference.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$BASE_URL/venues/activities/$serviceId/images'),
    )..headers['Authorization'] = 'Bearer $token';
    for (final image in images) {
      final bytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'images',
        bytes,
        filename: image.name.isEmpty ? 'activity_image.jpg' : image.name,
      ));
    }
    final uploadResponse = await request.send().timeout(const Duration(minutes: 2));
    final uploadBody = await uploadResponse.stream.bytesToString();
    if (uploadResponse.statusCode == 401) {
      throw _ActivityUploadException('Your session has expired. Please sign in again.');
    }
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw _ActivityUploadException(
        'Cloudinary upload failed (${uploadResponse.statusCode}). Please try again.',
      );
    }
    if (uploadBody.isEmpty) {
      throw _ActivityUploadException('Images could not be uploaded. Please try again.');
    }
    return serviceId;
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
      final file = File(imagePath);

      String fileName =
          "${folderName}_${DateTime.now().millisecondsSinceEpoch}.jpg";

      Reference ref = FirebaseStorage.instance
          .ref()
          .child(folderName)
          .child(realUid) // ✅ REAL UID
          .child(fileName);

      if (!await file.exists()) {
        throw StateError('Selected image file is no longer accessible');
      }
      final uploadTask = ref.putFile(file,
          SettableMetadata(contentType: 'image/jpeg'));
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e, stack) {
      CommonUtilities.showLog(
          'Firebase upload failed: code=${e.code}, plugin=${e.plugin}, message=${e.message}');
      CommonUtilities.showLog(stack.toString());
      rethrow;
    } catch (e, stack) {
      CommonUtilities.showLog('Image upload failed: ${e.runtimeType}: $e');
      CommonUtilities.showLog(stack.toString());
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> uploadActivityImages(
      List<XFile> images,
      String realUid,
      ) async {

    List<Map<String, dynamic>> uploadedImages = [];

    for (int i = 0; i < images.length; i++) {
      final img = images[i];

      String? url;
      if (kIsWeb) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('activity_images')
            .child(realUid)
            .child('activity_images_${DateTime.now().millisecondsSinceEpoch}.jpg');
        try {
          final task = ref.putData(
            await img.readAsBytes(),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          url = await (await task).ref.getDownloadURL();
        } on FirebaseException catch (e, stack) {
          CommonUtilities.showLog(
              'Firebase web upload failed: code=${e.code}, plugin=${e.plugin}, message=${e.message}');
          CommonUtilities.showLog(stack.toString());
          rethrow;
        } catch (e, stack) {
          CommonUtilities.showLog('Web image upload failed: ${e.runtimeType}: $e');
          CommonUtilities.showLog(stack.toString());
          rethrow;
        }
      } else {
        try {
          url = await uploadImageToFirebase(
            img.path,
            folderName: 'activity_images',
            realUid: realUid,
          );
        } on StateError {
          final ref = FirebaseStorage.instance
              .ref()
              .child('activity_images')
              .child(realUid)
              .child('activity_images_${DateTime.now().millisecondsSinceEpoch}.jpg');
          final task = ref.putData(
            await img.readAsBytes(),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          url = await (await task).ref.getDownloadURL();
        }
      }

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

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final rawDigits = phoneKey.replaceAll(RegExp(r'\D'), '');
    final nationalNumber = rawDigits.length >= 10
        ? rawDigits.substring(rawDigits.length - 10)
        : rawDigits;
    final canonicalKey = 'IND (+91)$nationalNumber';
    final legacyKey = 'IND (+91)${userMobileNumber.trim()}';
    final mappings = FirebaseFirestore.instance.collection('users_by_phone');

    // Resolve the canonical mapping first. The legacy formatted key is only
    // supported for records created by the older onboarding flow.
    DocumentSnapshot<Map<String, dynamic>> phoneDoc;
    try {
      phoneDoc = await mappings.doc(canonicalKey).get();
      if (!phoneDoc.exists && legacyKey != canonicalKey) {
        phoneDoc = await mappings.doc(legacyKey).get();
      }
    } on FirebaseException catch (e, stack) {
      CommonUtilities.showLog(
          'Phone mapping lookup failed: code=${e.code}, plugin=${e.plugin}, message=${e.message}');
      CommonUtilities.showLog(stack.toString());
      rethrow;
    }

    if (!phoneDoc.exists || phoneDoc.data()?['uid'] == null) {
      throw StateError('Partner phone mapping is unavailable');
    }

    final String realUid = phoneDoc.data()!['uid'].toString();

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


  Widget getText()
  {
    return Container(
      margin: EdgeInsets.only(top: 5),
      alignment: Alignment.centerLeft,
      child: Text(
        activityName,
        style: const TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'Satoshi',
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
            fontFamily: 'Satoshi',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}


