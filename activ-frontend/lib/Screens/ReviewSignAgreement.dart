import 'dart:convert';

import 'package:activ_app/Screens/ContactSupportScreen.dart';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import '../api_calling/progress_bar/progress_bar.dart';
import 'CommonCode.dart';

class ReviewSignAgreement extends StatefulWidget {
  const ReviewSignAgreement({super.key});

  @override
  State<ReviewSignAgreement> createState() => _State();
}

class _State extends State<ReviewSignAgreement> {

  TextEditingController fullNameController = TextEditingController();

  bool isButtonEnabled = false;
  bool isChecked = false;
  String phoneCode = "", userMobileNumber = "", fullNameSign="", todayDate="", fromDate="", setSelectDate="";

  String physicalSetup = "", activityVariation = "", equipmentProvided = "", participantsFollow = "", safetyMeasures = "", activitySuited = "",
  anythingElse = "", ownerFullName = "", ownerEmail = "", ownerMobileNumber = "", sameAsOwnerNumber = "", operateSaveValueStr = "", venueDetailsSaveValueStr = "",
  placeOfferSaveValueStr = "", sameAsOwnerNumberChecked="";

  dynamic operateSaveValue = <String, dynamic>{};
  Map<String, dynamic> venueDetailsSaveValue = {};
  Map<String, dynamic> placeOfferSaveValue = {};

  int currentStep = onboardingReviewStep;
  final int totalSteps = totalSetup;

  void nextStep() {
    if (currentStep < totalSteps) {
      setState(() {
        currentStep++;
      });
    }
  }

  void prevStep() {
    if (currentStep > 1) {
      setState(() {
        currentStep--;
      });
    }
  }

  _State()
  {
    getData();
  }

  @override
  void initState() {
    super.initState();

    // Listener to update text automatically
    fullNameController.addListener(() {
      setState(() {
        fullNameSign = fullNameController.text;
      });
    });
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));

    /*physicalSetup = checkString(await SharedPreference.readStr("physical_setup"));
    activityVariation = checkString(await SharedPreference.readStr("activity_variation"));
    equipmentProvided = checkString(await SharedPreference.readStr("equipment_provided"));
    participantsFollow = checkString(await SharedPreference.readStr("participants_follow"));
    safetyMeasures = checkString(await SharedPreference.readStr("safety_measures"));
    activitySuited = checkString(await SharedPreference.readStr("activity_suited"));
    anythingElse = checkString(await SharedPreference.readStr("anything_else"));*/

    ownerFullName = checkString(await SharedPreference.readStr("owner_full_name"));
    ownerEmail = checkString(await SharedPreference.readStr("owner_email"));
    ownerMobileNumber = checkString(await SharedPreference.readStr("owner_mobile_number"));
    sameAsOwnerNumber = checkString(await SharedPreference.readStr("same_as_owner_number"));
    sameAsOwnerNumberChecked = checkString(await SharedPreference.readStr("same_as_owner_number_checked"));

    print("------sameAsOwnerNumber : " + sameAsOwnerNumber.toString());

    if(sameAsOwnerNumber == "true")
    {
      sameAsOwnerNumber = checkString(await SharedPreference.readStr("owner_mobile_number"));
    }
    else{}

    operateSaveValueStr = checkString(await SharedPreference.readStr("operate_value"));
    venueDetailsSaveValueStr = checkString(await SharedPreference.readStr("venue_details"));
    placeOfferSaveValueStr = checkString(await SharedPreference.readStr("place_offer"));

    if (operateSaveValueStr.isNotEmpty) {
      operateSaveValue = jsonDecode(operateSaveValueStr);
    }

    if (venueDetailsSaveValueStr.isNotEmpty) {
      venueDetailsSaveValue = jsonDecode(venueDetailsSaveValueStr);
    }

    if (placeOfferSaveValueStr.isNotEmpty) {
      placeOfferSaveValue = jsonDecode(placeOfferSaveValueStr);
    }

    getCurrentDate();
  }

  Future<void> _showLegalPopup(String type) async {
    try {
      await initializeApiBaseUrl();
      if (!mounted) return;
      final response = await http.get(Uri.parse(LEGAL_URL))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Failed to load content.');
        return;
      }
      final body = jsonDecode(response.body);
      final List<dynamic> items = body['data'] ?? [];
      Map<String, dynamic>? item;
      for (final entry in items) {
        if (entry is Map<String, dynamic> && entry['type'] == type) {
          item = entry;
          break;
        }
      }
      if (item == null) {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Content not available.');
        return;
      }
      final String title = (type == 'terms_and_conditions') ? 'Terms & Conditions' : 'Privacy Policy';
      final String rawContent = item['content'] ?? '';
      final String cleanContent = rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: AppSize.size_16,
                          fontFamily: 'FontSemiBold',
                          color: AppColors.darkBlack,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.darkBlack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    cleanContent,
                    style: const TextStyle(
                      fontSize: AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.darkBlack,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      CommonUtilities.showLog('Legal popup error: $e');
      if (!mounted) return;
      CommonUtilities.createSnackBar(context, 'Network error. Please try again.');
    }
  }

  void getCurrentDate()
  {
    DateTime today = DateTime.now(); // Get Today Date
    todayDate = today.toString();
    String formatedDate1 = CommonUtilities.converDateFormate(todayDate, "DD-MM-YYYY", "yyyy-MM-dd HH:mm:ss"); //2022-09-29T08:07:48.000Z
    fromDate = CommonUtilities.converDateFormate(formatedDate1, "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd");
    setSelectDate = CommonUtilities.converDateFormate(fromDate, "yyyy-MM-dd", "MMMM dd, yyyy");
  }

  @override
  void dispose() {
    fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    double progress = currentStep / totalSteps;

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
                        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                    getActivIcon(),

                                    getStepBar(progress),

                                    getText(),

                                    getSubText(),

                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          /*Checkbox(
                                            value: isChecked,
                                            onChanged: (value) {
                                              setState(() {
                                                isChecked = value ?? false;
                                              });
                                            },
                                          ),*/
                                          Transform.translate(
                                            offset: const Offset(0, 0),
                                            child: Checkbox(
                                              value: isChecked,
                                              onChanged: (value) {
                                                setState(() {
                                                  isChecked = value!;
                                                });
                                              },
                                              activeColor: AppColors.black, // Tick color
                                              checkColor: AppColors.white,  // Tick icon color
                                              side: BorderSide(color: AppColors.black, width: 2), // Border style
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              margin: const EdgeInsets.only(left: 8, top: 2),
                                              child: RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
                                                    fontSize: AppSize.size_16,
                                                    fontFamily: 'FontRegular',
                                                    color: AppColors.darkBlack,
                                                  ),
                                                  children: [
                                                    const TextSpan(text: "I agree to the ",
                                                      style: TextStyle(
                                                          fontSize: AppSize.size_14,
                                                          fontFamily: 'FontRegular',
                                                          color: AppColors.darkBlack,
                                                          height: 1
                                                      ),),
                                                    TextSpan(
                                                      text: "Terms of Service",
                                                      style: const TextStyle(
                                                          fontSize: AppSize.size_14,
                                                          fontFamily: 'FontMedium',
                                                          color: AppColors.purple
                                                      ),
                                                      recognizer: TapGestureRecognizer()
                                                        ..onTap = () {
                                                          _showLegalPopup('terms_and_conditions');
                                                        },
                                                    ),
                                                    const TextSpan(text: " and ",style: TextStyle(
                                                        fontSize: AppSize.size_14,
                                                        fontFamily: 'FontRegular',
                                                        color: AppColors.darkBlack,
                                                        height: 1
                                                    ),),
                                                    TextSpan(
                                                      text: "Privacy Policy",
                                                      style: const TextStyle(
                                                          fontSize: AppSize.size_14,
                                                          fontFamily: 'FontMedium',
                                                          color: AppColors.purple
                                                      ),
                                                      recognizer: TapGestureRecognizer()
                                                        ..onTap = () {
                                                          _showLegalPopup('privacy_policy');
                                                        },
                                                    ),
                                                    const TextSpan(text: "."),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Electronic Signature Layout
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                                      decoration: BoxDecoration(
                                          color: AppColors.white,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: const Radius.circular(8),
                                            topRight: const Radius.circular(8),
                                            bottomLeft: const Radius.circular(8),
                                            bottomRight: const Radius.circular(8),
                                          ),
                                          border: Border.all(color: AppColors.gray, width: 1)
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                                        child: Column(
                                          children: [
                                            Container(
                                              margin: EdgeInsets.only(top: 0),
                                              alignment: Alignment.centerLeft,
                                              child: const Text(
                                                "Electronic Signature",
                                                style: TextStyle(
                                                    fontSize: AppSize.size_16,
                                                    fontFamily: 'FontSemiBold',
                                                    color: AppColors.darkBlack,
                                                    height: 1.2
                                                ),
                                                textAlign: TextAlign.left,
                                              ),
                                            ),

                                            getFullNameLabel(),
                                            getFullNameField(context),

                                            Container(
                                              margin: EdgeInsets.only(top: 8),
                                              child: Row(
                                                children: [

                                                  Container(
                                                    width:15,
                                                    height: 15,
                                                    child: Image.asset('assets/ic_question.png'),
                                                  ),

                                                  Container(
                                                    alignment: Alignment.centerLeft,
                                                    margin: EdgeInsets.fromLTRB(3, 0, 5, 0),
                                                    child: const Text(
                                                      "Type your full name as per govt records",
                                                      style: TextStyle(
                                                          fontSize: AppSize.size_12,
                                                          fontFamily: 'FontSemiBold',
                                                          color: AppColors.hintColor,
                                                          height: 1
                                                      ),
                                                      textAlign: TextAlign.left,
                                                    ),
                                                  )

                                                ],
                                              ),
                                            ),

                                            // Your Sign Layout
                                            Container(
                                              decoration: BoxDecoration(
                                                  color: AppColors.gray3,
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: const Radius.circular(8),
                                                    topRight: const Radius.circular(8),
                                                    bottomLeft: const Radius.circular(8),
                                                    bottomRight: const Radius.circular(8),
                                                  ),
                                                  border: Border.all(color: AppColors.gray, width: 1)
                                              ),
                                              margin: EdgeInsets.only(top: 15),
                                              child: Container(
                                                margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      alignment: Alignment.centerLeft,
                                                      margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                      child: Text(
                                                        fullNameSign.isNotEmpty ? fullNameSign : "Your Sign",
                                                        style: const TextStyle(
                                                            fontSize: AppSize.size_16,
                                                            fontFamily: 'FontSemiBold',
                                                            color: AppColors.hintColor,
                                                            fontStyle: FontStyle.italic,
                                                            height: 1.2
                                                        ),
                                                        textAlign: TextAlign.left,
                                                      ),
                                                    ),

                                                    Container(
                                                      alignment: Alignment.centerLeft,
                                                      margin: EdgeInsets.fromLTRB(0, 5, 0, 0),
                                                      child: Text(
                                                        (setSelectDate!=null && setSelectDate!="") ? "Signed on  " + setSelectDate : "Signed on ",
                                                        style: TextStyle(
                                                            fontSize: AppSize.size_12,
                                                            fontFamily: 'FontRegular',
                                                            color: AppColors.darkBlack,
                                                            height: 1.2
                                                        ),
                                                        textAlign: TextAlign.left,
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Note Text Layout
                                            Container(
                                              decoration: BoxDecoration(
                                                  color: AppColors.white,
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: const Radius.circular(8),
                                                    topRight: const Radius.circular(8),
                                                    bottomLeft: const Radius.circular(8),
                                                    bottomRight: const Radius.circular(8),
                                                  ),
                                                  border: Border.all(color: AppColors.purple1, width: 1)
                                              ),
                                              margin: EdgeInsets.only(top: 15),
                                              child: Container(
                                                margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                                child: Container(
                                                  alignment: Alignment.centerLeft,
                                                  margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                  child: const Text(
                                                    "Note: By signing here, you acknowledge that this constitutes a legally binding electronic signature equivalent to a handwritten signature, with the same force and effect.",
                                                    style: TextStyle(
                                                        fontSize: AppSize.size_12,
                                                        fontFamily: 'FontMedium',
                                                        color: AppColors.purple1,
                                                        height: 1.4
                                                    ),
                                                    textAlign: TextAlign.left,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          ],
                                        ),
                                      ),
                                    ),

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
                                              child: getBackButton(context, "Back", "reviewSignAgreement"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                            onTap: () async {
                                              if (validation(context)) {
                                                await _acceptTermsAndSubmit();
                                              }
                                            },
                                            child: (isChecked && fullNameController.text.toString().trim()!="")
                                                ? getButtonBlack(context, "Finish", "reviewSignAgreement") :
                                            getButtonGray(context, "Finish", "reviewSignAgreement")
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

  Future<void> _acceptTermsAndSubmit() async {
    final venueId = checkString(await SharedPreference.readStr("venue_id"));
    final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));

    if (venueId.isEmpty) {
      if (!mounted) return;
      CommonUtilities.createSnackBar(context, 'Venue not found. Please restart setup.');
      return;
    }

    if (!mounted) return;
    ProgressBar().showLoader(context);

    try {
      // Step 1 — Accept terms + electronic signature
      final termsRes = await http.patch(
        Uri.parse('$BASE_URL/venues/$venueId/terms'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'electronicSignature': fullNameController.text.trim(),
          'termsAccepted': true,
        }),
      );

      CommonUtilities.showLog('acceptTerms status: ${termsRes.statusCode}');
      CommonUtilities.showLog('acceptTerms response: ${termsRes.body}');

      if (termsRes.statusCode != 200 && termsRes.statusCode != 201) {
        if (!mounted) return;
        Navigator.pop(context);
        final body = jsonDecode(termsRes.body);
        final msg = body['message'] ?? 'Failed to accept terms.';
        CommonUtilities.createSnackBar(context, msg is List ? msg.join(', ') : msg.toString());
        return;
      }

      // Step 2 — Submit venue for admin review
      final submitRes = await http.post(
        Uri.parse('$BASE_URL/venues/$venueId/submit'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      CommonUtilities.showLog('submitForReview status: ${submitRes.statusCode}');
      CommonUtilities.showLog('submitForReview response: ${submitRes.body}');

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      if (submitRes.statusCode == 200 || submitRes.statusCode == 201) {
        CommonUtilities.showLog('✅ Venue submitted for review');
        CommonUtilities.firstTimeLoginSignup = "yes";
        CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, ContactSupportScreen());
      } else {
        final body = jsonDecode(submitRes.body);
        final msg = body['message'] ?? 'Failed to submit venue.';
        CommonUtilities.createSnackBar(context, msg is List ? msg.join(', ') : msg.toString());
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      CommonUtilities.showLog('❌ Submit error: $e');
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  //-----------------------------------------------------Start Upload Sign Agreement Under Database---------------------------------

  /*Future<void> ensureAnonymousLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    CommonUtilities.showLog("✅ Firebase UID: ${FirebaseAuth.instance.currentUser!.uid}");
  }*/

  Future<void> saveSignAgreement1({
    required bool agreeTerms,
    required String electronicSign,
  }) async {
    // ensure user logged in
    /*if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }*/

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final docRef = FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid);


    /*await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .set(
      {

        "sign_agreement": {
          "agree_terms_condition": agreeTerms,
          "electronic_sign": electronicSign,
        },

        "venue_place_facilities": {
          "physical_setup": checkString(physicalSetup),
          "activity_variation": checkString(activityVariation),
          "equipment_provided": checkString(equipmentProvided),
          "participants_follow": checkString(participantsFollow),
          "safety_measures": checkString(safetyMeasures),
          "activity_suited": checkString(activitySuited),
          "anything_else": checkString(anythingElse),
        },

        "owner_detail": {
          "owner_full_name": checkString(ownerFullName),
          "owner_email": checkString(ownerEmail),
          "owner_mobile_number": checkString(ownerMobileNumber),
          "same_as_owner_number": checkString(sameAsOwnerNumber),
        },

        "operate_value" : operateSaveValue,
        "venue_details" : venueDetailsSaveValue,
        "venue_offer": placeOfferSaveValue,
      },
      SetOptions(merge: true),
    );*/

    // ✅ 1. First save all normal data
    await docRef.set(
      {
        "sign_agreement": {
          "agree_terms_condition": agreeTerms,
          "electronic_sign": electronicSign,
        },

        /*"venue_place_facilities": {
          "physical_setup": checkString(physicalSetup),
          "activity_variation": checkString(activityVariation),
          "equipment_provided": checkString(equipmentProvided),
          "participants_follow": checkString(participantsFollow),
          "safety_measures": checkString(safetyMeasures),
          "activity_suited": checkString(activitySuited),
          "anything_else": checkString(anythingElse),
        },*/

        "owner_detail": {
          "owner_full_name": checkString(ownerFullName),
          "owner_email": checkString(ownerEmail),
          "owner_mobile_number": checkString(ownerMobileNumber),
          "same_as_owner_number": checkString(sameAsOwnerNumber),
        },

       // "operate_value": operateSaveValue,
          "venue_details": venueDetailsSaveValue,
          "venue_amenities": placeOfferSaveValue,
          "status": 'pending',
          "createdAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Proper nested update (IMPORTANT)
    await docRef.update({
      "basic_details.is_profile_completed": true,
    });

    CommonUtilities.showLog("✅ Sign agreement saved successfully");
  }


  Future<void> saveSignAgreement({
    required bool agreeTerms,
    required String electronicSign,
    required String phoneKey, // 📞 phone number key
  }) async {
    try {
      // 1️⃣ Resolve REAL UID from phone
      final phoneDoc = await FirebaseFirestore.instance
          .collection("users_by_phone")
          .doc(phoneKey)
          .get();

      if (!phoneDoc.exists) {
        throw Exception("❌ Phone mapping not found for $phoneKey");
      }

      print("FieldValue.serverTimestamp() : ${FieldValue.serverTimestamp()}");

      final String realUid = phoneDoc["uid"];

      // 2️⃣ Reference the actual user document by UID
      final docRef =
      FirebaseFirestore.instance.collection("activ_user").doc(realUid);

      // ✅ 3. Save all normal data
      await docRef.set({
        "sign_agreement": {
          "agree_terms_condition": agreeTerms,
          "electronic_sign": electronicSign,
        },

        "owner_detail": {
          "owner_full_name": checkString(ownerFullName),
          "owner_email": checkString(ownerEmail),
          "owner_mobile_number": checkString(ownerMobileNumber),
          "same_as_owner_number": checkString(sameAsOwnerNumber),
          "same_as_owner_number_checked": sameAsOwnerNumberChecked,
        },

        "venue_details": venueDetailsSaveValue,
        "venue_amenities": placeOfferSaveValue,
        "status": 'pending',
        "createdAt": FieldValue.serverTimestamp(),

      }, SetOptions(merge: true));

      // 4️⃣ Proper nested update
      await docRef.update({
        "basic_details.is_profile_completed": true,
      });

      CommonUtilities.showLog(
          "✅ Sign agreement saved successfully for phone: $phoneKey");
    } catch (e) {
      CommonUtilities.showLog("❌ Error saving sign agreement: $e");
    }
  }


  //-----------------------------------------------------End Upload Sign Agreement Under Database---------------------------------

  Widget getDividerLine()
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      color: AppColors.gray,
      height: 1,
    );
  }


  Widget getStepBar(double progress)
  {
    return Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

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
      margin: const EdgeInsets.only(top: 25),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Review & Sign Agreement",
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
        "Review your partnership details and sign to complete registration",
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

  Widget getFullNameLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "Full Name",
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

  Widget getFullNameField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
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
            controller: fullNameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("[a-zA-Z ]")),
              new LengthLimitingTextInputFormatter(50),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Full Name', // Set the hint label text
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

  bool validation(BuildContext context) {
    if (!isChecked) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationTermsAndPrivacyPolicy);
      return false;
    }
    else if (fullNameController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationFullNameEnter);
      return false;
    }
    return true;
  }
}
