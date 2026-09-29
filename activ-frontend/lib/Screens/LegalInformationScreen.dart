import 'dart:io';
import 'package:activ_app/Screens/PdfViewerPage.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/api_calling/progress_bar/progress_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'AadhaarNumberFormatter.dart';
import 'CommonCode.dart';
import 'ReviewVenueDetailsScreen.dart';
import 'package:file_picker/file_picker.dart';


class LegalInformationScreen extends StatefulWidget {
  const LegalInformationScreen({super.key});

  @override
  State<LegalInformationScreen> createState() => _State();
}

class _State extends State<LegalInformationScreen> {

  TextEditingController fullNameController = TextEditingController();
  TextEditingController aadhaarNumberController = TextEditingController();
  TextEditingController panCardNumberController = TextEditingController();
  TextEditingController gstINController = TextEditingController();
  bool isButtonEnabled = false;
  bool isChecked = false;
  String phoneCode = "", userMobileNumber = "";
  String? panCardFileExtension = "";
  String? aadhaarCardFileExtension = "";
  String? gstInCardFileExtension = "";
  String? img_url = "";
  File? _thumbnailImage;
  File? _image;
  final _picker = ImagePicker();
  File? fileImage;
  File? originalFileImage;

  File? _pickedPanCardFile;
  String? _filePanCardName;
  String? _filePanCardSize;

  File? _pickedAadhaarCardFile;
  String? _fileAadhaarCardName;
  String? _fileAadhaarCardSize;

  File? _pickedGSTINCardFile;
  String? _fileGSTINCardName;
  String? _fileGSTINCardSize;

  // Bytes for web-compatible multipart upload
  Uint8List? _panCardBytes;
  Uint8List? _aadhaarCardBytes;
  Uint8List? _gstinCardBytes;

  final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

  int currentStep = 9;
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
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));

  }

  @override
  void dispose() {
    fullNameController.dispose();
    aadhaarNumberController.dispose();
    panCardNumberController.dispose();
    gstINController.dispose();
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

                                    getFullNameLabel(),
                                    getFullNameField(context),

                                    getAadhaarNumberLabel(),
                                    getAadhaarNumberField(context),

                                    getPanCardNumberLabel(),
                                    getPanCardNumberField(context),


                                    // Pan Card View and View Layout
                                    getPanCardBrowseLayout(context),

                                    //Pan Card Label
                                    getViewPanCardLabel(context),

                                    // View Pan Card Click
                                    getViewPanCardPDF(context),

                                    _panCardBytes != null ?   Visibility(
                                      visible: (panCardFileExtension == "jpg" || panCardFileExtension == "png" || panCardFileExtension == "jpeg") ? true : false,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        child: AspectRatio(
                                          aspectRatio: 16/9,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8), // 👈 corner radius
                                            child: Image.memory(
                                              _panCardBytes!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 100,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ):Container(),

                                    // Aadhaar Card View and View Layout
                                    getAadhaarCardBrowseLayout(context),

                                    //Aadhaar Card Label
                                    getViewAadhaarCardLabel(context),

                                    // View Aadhaar Card Click
                                    getViewAadhaarCardPDF(context),

                                    _aadhaarCardBytes != null ?   Visibility(
                                      visible: (aadhaarCardFileExtension == "jpg" || aadhaarCardFileExtension == "png" || aadhaarCardFileExtension == "jpeg") ? true : false,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        child: AspectRatio(
                                          aspectRatio: 16/9,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8), // 👈 corner radius
                                            child: Image.memory(
                                              _aadhaarCardBytes!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 100,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ):Container(),

                                    getGSTRegisterLabel(),
                                    getAadhaarProviderEarlierText(),

                                    getGSTINLabel(),
                                    getGSTINField(context),

                                    getViewGSTINCardLabel(context),

                                    // GSTIN Card View and View Layout
                                    Visibility(
                                      visible: _gstinCardBytes == null ? true : false,
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(0, 5, 0, 15),
                                        child: DottedBorder(
                                          color: AppColors.purple,
                                          strokeWidth: 1.5,
                                          dashPattern: [6, 4],
                                          borderType: BorderType.RRect,
                                          radius: const Radius.circular(12),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Upload Icon

                                                Container(
                                                  width: 74,
                                                  height: 58,
                                                  child: Image.asset('assets/ic_pan.png'),
                                                ),

                                                Container(
                                                  margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                                                  child: const Text(
                                                    "Upload your GSTIN Details",
                                                    style: TextStyle(
                                                        fontSize: AppSize.size_16,
                                                        fontFamily: 'FontSemiBold',
                                                        color: AppColors.darkBlack,
                                                        height: 1
                                                    ),
                                                  ),
                                                ),

                                                // Sub Text
                                                Container(
                                                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                                                  child: const Text(
                                                    "pdf formats up to 5MB",
                                                    style: TextStyle(
                                                        fontSize: AppSize.size_14,
                                                        fontFamily: 'FontRegular',
                                                        color: AppColors.black1,
                                                        height: 1
                                                    ),
                                                  ),
                                                ),


                                                // Browser Button to Pick Images
                                                InkWell(
                                                  onTap: ()
                                                  {
                                                    //_getImageFrom(source: ImageSource.gallery, context: context);
                                                    _pickDocument("gstINCard");
                                                  },
                                                  child: Container(
                                                      height: 45,
                                                      margin: const EdgeInsets.fromLTRB(65, 15, 65, 5),
                                                      decoration: BoxDecoration(
                                                        borderRadius: const BorderRadius.only(
                                                          topLeft: Radius.circular(12),
                                                          topRight: Radius.circular(12),
                                                          bottomLeft: Radius.circular(12),
                                                          bottomRight: Radius.circular(12),
                                                        ),
                                                        border: Border.all(color: AppColors.purple, width: 1),
                                                        color: AppColors.white,
                                                      ),
                                                      child: Container(
                                                          alignment: Alignment.center,
                                                          child: const Text(
                                                            "Browse",
                                                            style: TextStyle(
                                                                fontSize: AppSize.size_16,
                                                                fontFamily: 'FontSemiBold',
                                                                color: AppColors.purple,
                                                                height: 1
                                                            ),
                                                          )
                                                      )
                                                  ),
                                                ),

                                                Container(
                                                  alignment: Alignment.center,
                                                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                                                  child: const Text(
                                                    "Supported formats: PDF, JPG, JPEG, PNG (Max 5 MB).\nPlease upload a clear image or PDF of your document.",
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontSize: AppSize.size_14,
                                                        fontFamily: 'FontRegular',
                                                        color: AppColors.black1,
                                                        height: 1.4
                                                    ),
                                                  ),
                                                ),

                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    Visibility(
                                      visible: _gstinCardBytes!=null ? true : false,
                                      child: InkWell(
                                        onTap: ()
                                        {
                                          File _pickedPanCardFile1 = File(_pickedGSTINCardFile!.path);
                                          CommonUtilities.NavigateWithPush(context, PdfViewerPage(_pickedPanCardFile1, "GSTIN Card"));
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(0, 8, 0, 15),
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
                                          child: Container(
                                            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(_fileGSTINCardName ?? "",
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              fontFamily: 'FontMedium',
                                                              color: AppColors.darkBlack)
                                                      ),
                                                      Text(_fileGSTINCardSize ?? "",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              fontFamily: 'FontMedium',
                                                              color: AppColors.hintColor)
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                InkWell(
                                                  onTap: ()
                                                  {
                                                    setState(() {
                                                      _pickedGSTINCardFile = null;
                                                      _gstinCardBytes = null;
                                                      _fileGSTINCardName = null;
                                                      _fileGSTINCardSize = null;
                                                      gstInCardFileExtension = "";
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                                                    width: 35,
                                                    height: 35,
                                                    child: Image.asset('assets/ic_delete.png'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    _gstinCardBytes != null ?   Visibility(
                                      visible: (gstInCardFileExtension == "jpg" || gstInCardFileExtension == "png" || gstInCardFileExtension == "jpeg") ? true : false,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        child: AspectRatio(
                                          aspectRatio: 16/9,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8), // 👈 corner radius
                                            child: Image.memory(
                                              _gstinCardBytes!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 100,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ):Container(),

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
                                              child: getBackButton(context, "Back", "legalInformation"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                            onTap: ()
                                            async {
                                              if(validation(context))
                                              {
                                                _saveLegalInfoToApi();
                                              }
                                            },
                                            child: getButtonBlack(context, "Next", "legalInformation")
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

  //------------------------------------------------------Start Upload Document-----------------------------------------------------

  /*Future<void> ensureAnonymousLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    print("✅ Firebase UID: ${FirebaseAuth.instance.currentUser!.uid}");
  }*/

  Future<String?> uploadPdfToFirebase({
    required String filePath,
    required String folderName,
  }) async {
    try {

      print("Upload File Path : $filePath");

      final uid = FirebaseAuth.instance.currentUser!.uid;
      File file = File(filePath);

      final extension = filePath.split('.').last.toLowerCase();

      final fileName =
          "${folderName}_${DateTime.now().millisecondsSinceEpoch}.$extension";

      Reference ref = FirebaseStorage.instance
          .ref()
          .child("legal_documents")
          .child(uid)
          .child(fileName);

      /*UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;*/

      UploadTask uploadTask;

      //  Content-Type handling
      if (extension == "pdf") {
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: "application/pdf"),
        );
      } else {
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: "image/$extension"),
        );
      }

      final snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      CommonUtilities.showLog("✅ File uploaded: $downloadUrl");

      return downloadUrl;
    } catch (e) {
      CommonUtilities.showLog("❌ PDF upload failed: $e");
      return null;
    }
  }

  /*Future<void> saveLegalDocumentToFirestore1({
    required String aadhaarFullName,
    required String aadhaarNumber,
    required String panNumber,
    required String gstinNumber,
    required String panPdfPath,
    required String aadhaarPdfPath,
    required String gstinPdfPath,
    required String mobileNumber,
  }) async {

    //await AuthService().ensureAnonymousLogin();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    //  Upload PDFs
    String? panPdfUrl =
    await uploadPdfToFirebase(panPdfPath, "pan_card");

    String? aadhaarPdfUrl =
    await uploadPdfToFirebase(aadhaarPdfPath, "aadhaar");

    String? gstinPdfUrl =
    await uploadPdfToFirebase(gstinPdfPath, "gstin");

    //  Build legal_document object
    Map<String, dynamic> legalDocument = {
      "aadhaar_full_name": aadhaarFullName,
      "aadhaar_number": aadhaarNumber,
      "pan_card_number": panNumber,
      "gstin_number": gstinNumber,
      "pan_card_pdf_file": panPdfUrl,
      "aadhaar_pdf_file": aadhaarPdfUrl,
      "gstin_pdf_file": gstinPdfUrl,
    };

    //  Save in Firestore (same UID)
    await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .set({
      "uid": uid,
      "mobile_number": mobileNumber,
      "legal_document": legalDocument,
    }, SetOptions(merge: true));

    CommonUtilities.showLog("✅ Legal document saved successfully");
  }
*/
  Future<void> saveLegalDocumentToFirestore({
    required String aadhaarFullName,
    required String aadhaarNumber,
    required String panNumber,
    required String gstinNumber,
    required String panImagePath,
    required String aadhaarImagePath,
    required String gstinImagePath,
    required String panPdfPath,
    required String aadhaarPdfPath,
    required String gstinPdfPath,
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

      final String realUid = phoneDoc["uid"];

      // 2️⃣ Upload PDFs Or Images
      /*String? panPdfUrl = await uploadPdfToFirebase(panPdfPath, "pan_card");
      String? aadhaarPdfUrl = await uploadPdfToFirebase(aadhaarPdfPath, "aadhaar");
      String? gstinPdfUrl = await uploadPdfToFirebase(gstinPdfPath, "gstin");*/

      // PAN
      String? panUrl = await uploadPdfToFirebase(
        filePath: panPdfPath.isNotEmpty ? panPdfPath : panImagePath,
        folderName: "pan_card",
      );

      // Aadhaar
      String? aadhaarUrl = await uploadPdfToFirebase(
        filePath: aadhaarPdfPath.isNotEmpty ? aadhaarPdfPath : aadhaarImagePath,
        folderName: "aadhaar",
      );

      // GSTIN
      String? gstinUrl = await uploadPdfToFirebase(
        filePath: gstinPdfPath.isNotEmpty ? gstinPdfPath : gstinImagePath,
        folderName: "gstin",
      );

      // 3️⃣ Build legal_document object
      Map<String, dynamic> legalDocument = {
        "aadhaar_full_name": aadhaarFullName,
        "aadhaar_number": aadhaarNumber,
        "pan_card_number": panNumber,
        "gstin_number": gstinNumber,
        "pan_card_pdf_file": panUrl,
        "pan_card_file_extension": panCardFileExtension,
        "aadhaar_pdf_file": aadhaarUrl,
        "aadhaar_pdf_file_extension": aadhaarCardFileExtension,
        "gstin_pdf_file": gstinUrl,
        "gstin_pdf_file_extension": gstInCardFileExtension,
      };

      // 4️⃣ Save in Firestore under actual UID
      await FirebaseFirestore.instance
          .collection("activ_user")
          .doc(realUid)
          .set({
        "uid": realUid,
        "mobile_number": phoneKey,
        "legal_document": legalDocument,
      }, SetOptions(merge: true));

      CommonUtilities.showLog(
          "✅ Legal document saved successfully for phone: $phoneKey");
    } catch (e) {
      CommonUtilities.showLog("❌ Error saving legal document: $e");
    }
  }


  //------------------------------------------------------End Upload Document-----------------------------------------------------

  Widget getStepBar(double progress)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.only(top: 10),
        child: SvgPicture.asset("assets/activ_tm.svg",)
    );
  }

  Widget getText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 25),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Provide legal information",
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
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: const Text(
        "We will use these details to verify venue's legitimacy",
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
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
          child: const Text(
            "Full Name As Per Aadhaar",
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
          margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
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
          border: Border.all(color: AppColors.gray, width: 1)
      ),
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
              LengthLimitingTextInputFormatter(40),
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

  Widget getAadhaarNumberLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Aadhaar Number",
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
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
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

  Widget getAadhaarNumberField(BuildContext context)  {
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
            controller: aadhaarNumberController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.number,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14), // 12 digits + 2 hyphens
              AadhaarNumberFormatter(),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Aadhaar Number', // Set the hint label text
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

  Widget getPanCardNumberLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "PAN Number",
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
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
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

  Widget getPanCardNumberField(BuildContext context) {
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
            controller: panCardNumberController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Pan Name', // Set the hint label text
              hintStyle: TextStyle(
                fontSize:  AppSize.size_14,
                fontFamily: 'FontRegular',
                color: AppColors.hintColor, // Text color of the hint label
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter PAN Number';
              } else if (!panRegex.hasMatch(value)) {
                return 'Invalid PAN format';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget getPanCardBrowseLayout(BuildContext context)
  {
    return Visibility(
      visible: _panCardBytes == null ? true : false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 25, 0, 0),
        child: DottedBorder(
          color: AppColors.purple,
          strokeWidth: 1.5,
          dashPattern: [6, 4],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upload Icon

                Container(
                  width: 74,
                  height: 58,
                  child: Image.asset('assets/ic_pan.png'),
                ),

                Container(
                  margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Upload your PAN Card",
                          style: TextStyle(fontSize: AppSize.size_16, fontFamily: 'FontSemiBold', color: AppColors.darkBlack, height: 1),
                        ),
                        TextSpan(
                          text: "*",
                          style: TextStyle(fontSize: AppSize.size_16, fontFamily: 'FontSemiBold', color: AppColors.red, height: 1),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sub Text
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: const Text(
                    "pdf formats up to 5MB",
                    style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.black1,
                        height: 1
                    ),
                  ),
                ),


                // Browser Button to Pick Images
                InkWell(
                  onTap: ()
                  {
                    //_getImageFrom(source: ImageSource.gallery, context: context);
                    _pickDocument("panCard");
                  },
                  child: Container(
                      height: 45,
                      margin: const EdgeInsets.fromLTRB(65, 15, 65, 5),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border.all(color: AppColors.purple, width: 1),
                        color: AppColors.white,
                      ),
                      child: Container(
                          alignment: Alignment.center,
                          child: const Text(
                            "Browse",
                            style: TextStyle(
                                fontSize: AppSize.size_16,
                                fontFamily: 'FontSemiBold',
                                color: AppColors.purple,
                                height: 1
                            ),
                          )
                      )
                  ),
                ),

                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: const Text(
                    "Supported formats: PDF, JPG, JPEG, PNG (Max 5 MB).\nPlease upload a clear image or PDF of your document.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.black1,
                        height: 1.4
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getViewPanCardLabel(BuildContext context)
  {
    return Visibility(
      visible: _panCardBytes!=null ? true : false,
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
        child: const Text(
          "View PAN Card",
          style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget getViewPanCardPDF(BuildContext context)
  {
    return Visibility(
      visible: _panCardBytes!=null ? true : false,
      child: InkWell(
        onTap: ()
        {
          if(panCardFileExtension == "pdf" || panCardFileExtension == "PDF")
          {
            File _pickedPanCardFile1 = File(_pickedPanCardFile!.path);
            CommonUtilities.NavigateWithPush(context, PdfViewerPage(_pickedPanCardFile1, "Pan Card"));
          }else{}
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_filePanCardName ?? "",
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'FontMedium',
                              color: AppColors.darkBlack)
                      ),
                      Text(_filePanCardSize ?? "",
                          style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'FontMedium',
                              color: AppColors.hintColor)
                      ),
                    ],
                  ),
                ),

                InkWell(
                  onTap: ()
                  {
                    setState(() {
                      _pickedPanCardFile = null;
                      _panCardBytes = null;
                      _filePanCardName = null;
                      _filePanCardSize = null;
                      panCardFileExtension = "";
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                    width: 35,
                    height: 35,
                    child: Image.asset('assets/ic_delete.png'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getAadhaarCardBrowseLayout(BuildContext context)
  {
    return Visibility(
      visible: _aadhaarCardBytes == null ? true : false,
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 25, 0, 0),
        child: DottedBorder(
          color: AppColors.purple,
          strokeWidth: 1.5,
          dashPattern: [6, 4],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upload Icon

                Container(
                  width: 74,
                  height: 58,
                  child: Image.asset('assets/ic_pan.png'),
                ),

                Container(
                  margin: EdgeInsets.fromLTRB(0, 12, 0, 0),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Upload your Aadhaar Card",
                          style: TextStyle(fontSize: AppSize.size_16, fontFamily: 'FontSemiBold', color: AppColors.darkBlack, height: 1),
                        ),
                        TextSpan(
                          text: "*",
                          style: TextStyle(fontSize: AppSize.size_16, fontFamily: 'FontSemiBold', color: AppColors.red, height: 1),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sub Text
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: const Text(
                    "pdf formats up to 5MB",
                    style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.black1,
                        height: 1
                    ),
                  ),
                ),


                // Browser Button to Pick Images
                InkWell(
                  onTap: ()
                  {
                    //_getImageFrom(source: ImageSource.gallery, context: context);
                    _pickDocument("aadhaarCard");
                  },
                  child: Container(
                      height: 45,
                      margin: const EdgeInsets.fromLTRB(65, 15, 65, 5),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border.all(color: AppColors.purple, width: 1),
                        color: AppColors.white,
                      ),
                      child: Container(
                          alignment: Alignment.center,
                          child: const Text(
                            "Browse",
                            style: TextStyle(
                                fontSize: AppSize.size_16,
                                fontFamily: 'FontSemiBold',
                                color: AppColors.purple,
                                height: 1
                            ),
                          )
                      )
                  ),
                ),

                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: const Text(
                    "Supported formats: PDF, JPG, JPEG, PNG (Max 5 MB).\nPlease upload a clear image or PDF of your document.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.black1,
                        height: 1.4
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getViewAadhaarCardLabel(BuildContext context)
  {
    return Visibility(
      visible: _aadhaarCardBytes!=null ? true : false,
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
        child: const Text(
          "View Aadhaar Card",
          style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget getViewAadhaarCardPDF(BuildContext context)
  {
    return Visibility(
      visible: _aadhaarCardBytes!=null ? true : false,
      child: InkWell(
        onTap: ()
        {
          if(aadhaarCardFileExtension == "pdf" || aadhaarCardFileExtension == "PDF")
          {
            File _pickedPanCardFile1 = File(_pickedAadhaarCardFile!.path);
            CommonUtilities.NavigateWithPush(context, PdfViewerPage(_pickedPanCardFile1, 'Aadhaar Card'));
          }else{}
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fileAadhaarCardName ?? "",
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'FontMedium',
                              color: AppColors.darkBlack)
                      ),
                      Text(_fileAadhaarCardSize ?? "",
                          style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'FontMedium',
                              color: AppColors.hintColor)
                      ),
                    ],
                  ),
                ),

                InkWell(
                  onTap: ()
                  {
                    setState(() {
                      _pickedAadhaarCardFile = null;
                      _aadhaarCardBytes = null;
                      _fileAadhaarCardName = null;
                      _fileAadhaarCardSize = null;
                      aadhaarCardFileExtension = "";
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                    width: 35,
                    height: 35,
                    child: Image.asset('assets/ic_delete.png'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getGSTRegisterLabel()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: const Text(
        "Are you GST registered? (Optional)",
        style: TextStyle(
            fontSize: AppSize.size_16,
            fontFamily: 'FontSemiBold',
            color: AppColors.black1,
            height: 1
        ),
        textAlign: TextAlign.left,
      ),
    );
  }


  Widget getAadhaarProviderEarlierText()
  {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: const Text(
        "This should be linked to the Aadhaar provided earlier",
        style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontRegular',
            color: AppColors.black1,
            height: 1.4
        ),
        textAlign: TextAlign.left,
      ),
    );
  }


  Widget getGSTINLabel() {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: const Text(
        "GSTIN",
        style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontMedium',
            color: AppColors.black1,
            height: 1
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getGSTINField(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 8, 0, 15),
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
            controller: gstINController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              new LengthLimitingTextInputFormatter(15),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter GSTIN Number', // Set the hint label text
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

  Widget getViewGSTINCardLabel(BuildContext context)
  {
    return Visibility(
      visible: _gstinCardBytes!=null ? true : false,
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: const Text(
          "View GSTIN Card",
          style: TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'FontMedium',
              color: AppColors.black1,
              height: 1
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  bool validation(BuildContext context) {

    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

    if (fullNameController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationFullNameEnter);
      return false;
    }
    else if (!RegExp(r'^[a-zA-Z][a-zA-Z ]{0,38}[a-zA-Z]$').hasMatch(fullNameController.text.trim())) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationFullNameInvalid);
      return false;
    }
    else if (aadhaarNumberController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationAadhaarNumberEnter);
      return false;
    }
    else if (panCardNumberController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationPanCardNumberEnter);
      return false;
    }
    else if (!panRegex.hasMatch(panCardNumberController.text.trim())) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationPanCardNumberEnterInvalid);
      return false;
    }
    else if (_panCardBytes == null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationPanCardPDF);
      return false;
    }
    else if (_aadhaarCardBytes == null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationAadhaarCardPDF);
      return false;
    }
    else if (gstINController.text.toString().trim().isEmpty && _gstinCardBytes != null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationGSTINCardPDF);
      return false;
    }
    else if (gstINController.text.toString().trim().isNotEmpty && _gstinCardBytes == null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationGSTINCardPDF);
      return false;
    }
    return true;
  }


  // ─── Save Legal Info to REST API ─────────────────────────────────────────

  Future<void> _saveLegalInfoToApi() async {
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
      final formData = dio_pkg.FormData();
      // Text fields (per API spec)
      formData.fields.add(MapEntry('aadhaarName', fullNameController.text.trim()));
      formData.fields.add(MapEntry('aadhaarNumber', aadhaarNumberController.text.trim().replaceAll('-', '')));
      formData.fields.add(MapEntry('panNumber', panCardNumberController.text.trim()));
      if (gstINController.text.trim().isNotEmpty) {
        formData.fields.add(MapEntry('gstNumber', gstINController.text.trim()));
      }
      // File fields (per API spec: panCard, aadhaarCard, gstinDoc)
      if (_panCardBytes != null) {
        formData.files.add(MapEntry('panCard', dio_pkg.MultipartFile.fromBytes(
          _panCardBytes!,
          filename: _filePanCardName ?? 'panCard.${panCardFileExtension ?? 'pdf'}',
        )));
      }
      if (_aadhaarCardBytes != null) {
        formData.files.add(MapEntry('aadhaarCard', dio_pkg.MultipartFile.fromBytes(
          _aadhaarCardBytes!,
          filename: _fileAadhaarCardName ?? 'aadhaarCard.${aadhaarCardFileExtension ?? 'pdf'}',
        )));
      }
      if (_gstinCardBytes != null) {
        formData.files.add(MapEntry('gstinDoc', dio_pkg.MultipartFile.fromBytes(
          _gstinCardBytes!,
          filename: _fileGSTINCardName ?? 'gstinDoc.${gstInCardFileExtension ?? 'pdf'}',
        )));
      }

      CommonUtilities.showLog('Sending fields: ${formData.fields.map((e) => e.key).toList()}');
      CommonUtilities.showLog('Sending files: ${formData.files.map((e) => e.key).toList()}');

      final dio = dio_pkg.Dio();
      final response = await dio.patch(
        '$BASE_URL/venues/$venueId/legal',
        data: formData,
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer $jwtToken'},
          validateStatus: (_) => true,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog('Legal info status: ${response.statusCode}');
      CommonUtilities.showLog('Legal info response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        CommonUtilities.showLog('✅ Legal info saved successfully');
        CommonUtilities.NavigateWithPush(context, ReviewVenueDetailsScreen());
      } else {
        final data = response.data;
        String msg = 'Failed to save legal information.';
        if (data is Map) {
          final m = data['message'];
          msg = m is List ? m.join(', ') : m?.toString() ?? msg;
        }
        CommonUtilities.createSnackBar(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog('❌ Legal info error: $e');
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  Future<void> _pickDocument(String documentType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      //allowedExtensions: ['pdf'],
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // required on Flutter Web to populate PlatformFile.bytes
    );

    if (result != null) {
      final platformFile = result.files.single;

      final ext = platformFile.extension?.toLowerCase() ?? '';
      if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, 'Please upload a file in PDF, JPG, or PNG format.');
        return;
      }

      // Use bytes directly (web) or read from file path (mobile/desktop)
      Uint8List? fileBytes = platformFile.bytes;
      File? file;
      // Only use dart:io File on non-web where bytes may be null
      if (fileBytes == null && platformFile.path != null) {
        file = File(platformFile.path!);
        fileBytes = file.readAsBytesSync();
      }
      final int fileLength = fileBytes?.length ?? 0;

      setState(() {
        if(documentType == "panCard")
        {
          panCardFileExtension = platformFile.extension;
          _pickedPanCardFile = file;
          _panCardBytes = fileBytes;
          _filePanCardName = platformFile.name;
          _filePanCardSize = _getFileSize(fileLength, 2);
        }
        else if(documentType == "aadhaarCard")
        {
          aadhaarCardFileExtension = platformFile.extension;
          _pickedAadhaarCardFile = file;
          _aadhaarCardBytes = fileBytes;
          _fileAadhaarCardName = platformFile.name;
          _fileAadhaarCardSize = _getFileSize(fileLength, 2);
        }
        else if(documentType == "gstINCard")
        {
          gstInCardFileExtension = platformFile.extension;
          _pickedGSTINCardFile = file;
          _gstinCardBytes = fileBytes;
          _fileGSTINCardName = platformFile.name;
          _fileGSTINCardSize = _getFileSize(fileLength, 2);
        }
      });
    }
  }

  /// File Size readable format.
  String _getFileSize(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (bytes.bitLength / 10).floor();
    var size = (bytes / (1 << (10 * i)));
    return size.toStringAsFixed(decimals) + ' ' + suffixes[i];
  }

}
