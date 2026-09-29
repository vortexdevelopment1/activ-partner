import 'dart:io';
import 'package:activ_app/Screens/PdfViewerPage.dart';
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
import 'package:file_picker/file_picker.dart';

import '../../Style/app_size.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_request.dart';
import '../AadhaarNumberFormatter.dart';
import '../CommonCode.dart';
import 'PdfViewerPageByUrl.dart';


class ShowLegalInformationScreen extends StatefulWidget {
  const ShowLegalInformationScreen({super.key});

  @override
  State<ShowLegalInformationScreen> createState() => _State();
}

class _State extends State<ShowLegalInformationScreen> {

  TextEditingController fullNameController = TextEditingController();
  TextEditingController aadhaarNumberController = TextEditingController();
  TextEditingController panCardNumberController = TextEditingController();
  TextEditingController gstINController = TextEditingController();
  bool isButtonEnabled = false;
  bool isChecked = false;
  String phoneCode = "", userMobileNumber = "";

  ScrollController scrollController = ScrollController();

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

  final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

  bool isShimmerLoading = false;
  String aadhaarPdfFileURL = "",gstPdfFileURL="", panPdfFileURL="";

  _State(){
    getData();
    loadShimmer();
  }

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future loadShimmer() async {
    isShimmerLoading = true;
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    setState(() {});
  }

  /// FETCH DATA FROM FIRESTORE
  Future<void> fetchDetails() async {
    try {

      userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
      final String phoneKey = 'IND (+91)'+ userMobileNumber;

      // 2️⃣ Get UID from users_by_phone
      final phoneDoc = await FirebaseFirestore.instance
          .collection('users_by_phone')
          .doc(phoneKey)
          .get();

      if (!phoneDoc.exists) {
        debugPrint("❌ Phone mapping not found for $phoneKey");
        return;
      }

      final String realUid = phoneDoc['uid'];


      //final uid = FirebaseAuth.instance.currentUser!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('activ_user')
          .doc(realUid)
          .get();

      if (!userDoc.exists) {
        debugPrint("❌ Legal document not found for UID: $realUid");
        return;
      }

      final data = userDoc.data()?['legal_document'];

      if (data != null && data is Map<String, dynamic>) {
        fullNameController.text = data['aadhaar_full_name'] ?? '';
        aadhaarNumberController.text = data['aadhaar_number'] ?? '';
        aadhaarPdfFileURL = data['aadhaar_pdf_file'] ?? '';
        panCardNumberController.text = data['pan_card_number'] ?? '';
        panPdfFileURL = data['pan_card_pdf_file'] ?? '';
        gstINController.text = data['gstin_number'] ?? '';
        gstPdfFileURL = data['gstin_pdf_file'] ?? '';
      } else {
        fullNameController.text = '';
        aadhaarNumberController.text = '';
        panCardNumberController.text = '';
        gstINController.text = '';
      }
    } catch (e) {
      debugPrint("Error fetching venue details: $e");
    }

    setState(() => isShimmerLoading = false);
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

                            getToolTab(context),

                            isShimmerLoading == true ? buildShimmer(context) :  Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(15, 5, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

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


                                    // Aadhaar Card View and View Layout
                                    getAadhaarCardBrowseLayout(context),

                                    //Aadhaar Card Label
                                    getViewAadhaarCardLabel(context),

                                    // View Aadhaar Card Click
                                    getViewAadhaarCardPDF(context),


                                    //getGSTRegisterLabel(),
                                    //getAadhaarProviderEarlierText(),

                                    getGSTINLabel(),
                                    getGSTINField(context),

                                    getViewGSTINCardLabel(context),

                                    // GSTIN Card View and View Layout
                                    Visibility(
                                      visible: gstINController.text.toString().trim() != "" ? true : false,
                                      child: Visibility(
                                        visible: (_pickedGSTINCardFile == null && gstPdfFileURL == "") ? true : false,
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
                                                      "Please upload clear wide-angle photos in PDF formats up-to 5 MB",
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
                                    ),

                                    Visibility(
                                      visible: (_pickedGSTINCardFile!=null || gstPdfFileURL!="") ? true : false,
                                      child: InkWell(
                                        onTap: ()
                                        {
                                          CommonUtilities.NavigateWithPush(context, PdfViewerPageByUrl(gstPdfFileURL, "GSTIN Card"));
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
                                                      Text('GSTIN Number' ?? "",
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              fontFamily: 'FontMedium',
                                                              color: AppColors.darkBlack)
                                                      ),
                                                      /*Text(_fileGSTINCardSize ?? "",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              fontFamily: 'FontMedium',
                                                              color: AppColors.hintColor)
                                                      ),*/
                                                    ],
                                                  ),
                                                ),

                                                InkWell(
                                                  onTap: ()
                                                  {
                                                    setState(() {
                                                      _pickedGSTINCardFile = null;
                                                      _fileGSTINCardName = null;
                                                      _fileGSTINCardSize = null;
                                                    });
                                                  },
                                                  child: Visibility(
                                                    visible: (gstPdfFileURL!=null && gstPdfFileURL!="") ? false : true,
                                                    child: Container(
                                                      padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                                                      width: 35,
                                                      height: 35,
                                                      child: Image.asset('assets/ic_delete.png'),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
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

  // To show the toolbar
  Widget getToolTab(BuildContext context)
  {
    return Container(
      height: AppSize.toolTabSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: InkWell(onTap: ()
              {
                Navigator.pop(context);
              },
                  child: Container(
                    padding: EdgeInsets.fromLTRB(15,10,15,10),
                    child: SvgPicture.asset('assets/ic_back.svg',),
                  )
              ),
            ),
          ),

          getTitleText(context, 'Documents', 'View_Document')

        ],
      ),
    );
  }

  //------------------------------------------------------Start Upload Document-----------------------------------------------------



  Future<String?> uploadPdfToFirebase(String filePath, String folderName) async {
    try {

      //await AuthService().ensureAnonymousLogin();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      File file = File(filePath);

      String fileName =
          "${folderName}_${DateTime.now().millisecondsSinceEpoch}.pdf";

      Reference ref = FirebaseStorage.instance
          .ref()
          .child("legal_documents")
          .child(uid)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      CommonUtilities.showLog("✅ PDF Uploaded: $downloadUrl");

      return downloadUrl;
    } catch (e) {
      CommonUtilities.showLog("❌ PDF upload failed: $e");
      return null;
    }
  }

  Future<void> saveLegalDocumentToFirestore1({
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

  Future<void> saveLegalDocumentToFirestore({
    required String aadhaarFullName,
    required String aadhaarNumber,
    required String panNumber,
    required String gstinNumber,
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

      // 2️⃣ Upload PDFs
      String? panPdfUrl = await uploadPdfToFirebase(panPdfPath, "pan_card");
      String? aadhaarPdfUrl =
      await uploadPdfToFirebase(aadhaarPdfPath, "aadhaar");
      String? gstinPdfUrl = await uploadPdfToFirebase(gstinPdfPath, "gstin");

      // 3️⃣ Build legal_document object
      Map<String, dynamic> legalDocument = {
        "aadhaar_full_name": aadhaarFullName,
        "aadhaar_number": aadhaarNumber,
        "pan_card_number": panNumber,
        "gstin_number": gstinNumber,
        "pan_card_pdf_file": panPdfUrl,
        "aadhaar_pdf_file": aadhaarPdfUrl,
        "gstin_pdf_file": gstinPdfUrl,
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





  Widget getFullNameLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
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
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
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

  Widget getAadhaarNumberLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
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
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
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
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
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
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
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
              new LengthLimitingTextInputFormatter(12),
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
      visible: (_pickedPanCardFile == null && panPdfFileURL == "") ? true : false,
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
                  child: const Text(
                    "Upload your PAN Card*",
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
                    "Please upload clear wide-angle photos in PDF formats up-to 5 MB",
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
      visible: (_pickedPanCardFile!=null || panPdfFileURL!="") ? true : false,
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
      visible: (_pickedPanCardFile!=null || panPdfFileURL!="") ? true : false,
      child: InkWell(
        onTap: ()
        {

          CommonUtilities.NavigateWithPush(context, PdfViewerPageByUrl(panPdfFileURL, "Pan Card"));
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
            padding: (panPdfFileURL!=null && panPdfFileURL!="") ? const EdgeInsets.fromLTRB(10, 15, 8, 15) : const EdgeInsets.fromLTRB(10, 10, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pan Card' ?? "",
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'FontMedium',
                              color: AppColors.darkBlack)
                      ),
                      /*Text(_filePanCardSize ?? "",
                          style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'FontMedium',
                              color: AppColors.hintColor)
                      ),*/
                    ],
                  ),
                ),

                InkWell(
                  onTap: ()
                  {
                    setState(() {
                      _pickedPanCardFile = null;
                      _filePanCardName = null;
                      _filePanCardSize = null;
                    });
                  },
                  child: Visibility(
                    visible: (panPdfFileURL!=null && panPdfFileURL!="") ? false : true,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                      width: 35,
                      height: 35,
                      child: Image.asset('assets/ic_delete.png'),
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

  Widget getAadhaarCardBrowseLayout(BuildContext context)
  {
    return Visibility(
      visible: (_pickedAadhaarCardFile == null && aadhaarPdfFileURL=="") ? true : false,
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
                  child: const Text(
                    "Upload your Aadhaar Card*",
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
                    "Please upload clear wide-angle photos in PDF formats up-to 5 MB",
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
      visible: (_pickedAadhaarCardFile!=null || aadhaarPdfFileURL!="") ? true : false,
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
      visible: (_pickedAadhaarCardFile!=null || aadhaarPdfFileURL!="") ? true : false,
      child: InkWell(
        onTap: ()
        {
          CommonUtilities.NavigateWithPush(context, PdfViewerPageByUrl(aadhaarPdfFileURL, "Aadhaar Card"));
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
            padding: (aadhaarPdfFileURL!=null && aadhaarPdfFileURL!="") ? const EdgeInsets.fromLTRB(10, 15, 8, 15) : const EdgeInsets.fromLTRB(10, 10, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aadhaar Card' ?? "",
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'FontMedium',
                              color: AppColors.darkBlack)
                      ),
                      /*Text(_fileAadhaarCardSize ?? "",
                          style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'FontMedium',
                              color: AppColors.hintColor)
                      ),*/
                    ],
                  ),
                ),

                InkWell(
                  onTap: ()
                  {
                    setState(() {
                      _pickedAadhaarCardFile = null;
                      _fileAadhaarCardName = null;
                      _fileAadhaarCardSize = null;
                    });
                  },
                  child: Visibility(
                    visible: (aadhaarPdfFileURL!=null && aadhaarPdfFileURL!="") ? false : true,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                      width: 35,
                      height: 35,
                      child: Image.asset('assets/ic_delete.png'),
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
    return Visibility(
      visible: gstINController.text.toString().trim() != "" ? true : false,
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 25, 0, 0),
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
      ),
    );
  }

  Widget getGSTINField(BuildContext context) {
    return Visibility(
      visible: gstINController.text.toString().trim() != "" ? true : false,
      child: Container(
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
      ),
    );
  }

  Widget getViewGSTINCardLabel(BuildContext context)
  {
    return Visibility(
      visible: (_pickedGSTINCardFile!=null || gstPdfFileURL!="") ? true : false,
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
    else if (_pickedPanCardFile == null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationPanCardPDF);
      return false;
    }
    else if (_pickedAadhaarCardFile == null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationAadhaarCardPDF);
      return false;
    }
    else if (gstINController.text.toString().trim().isEmpty && _pickedGSTINCardFile != null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationGSTINCardPDF);
      return false;
    }
    else if (gstINController.text.toString().trim().isNotEmpty && _pickedGSTINCardFile == null) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.validationGSTINCardPDF);
      return false;
    }
    return true;
  }


  Future<void> _pickDocument(String documentType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      //allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);

      setState(() {
        if(documentType == "panCard")
        {
          _pickedPanCardFile = file;
          _filePanCardName = result.files.single.name;
          _filePanCardSize = _getFileSize(file.lengthSync(), 2);
        }
        else if(documentType == "aadhaarCard")
        {
          _pickedAadhaarCardFile = file;
          _fileAadhaarCardName = result.files.single.name;
          _fileAadhaarCardSize = _getFileSize(file.lengthSync(), 2);
        }
        else if(documentType == "gstINCard")
        {
          _pickedGSTINCardFile = file;
          _fileGSTINCardName = result.files.single.name;
          _fileGSTINCardSize = _getFileSize(file.lengthSync(), 2);
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

  Widget buildShimmer(BuildContext context) =>
      Expanded(
        flex: 9,
        child: Container(
          color: AppColors.bgColor,
          margin: EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: ListView(
            controller: scrollController, //set controller
            shrinkWrap: true,
            children: List.generate(
                10, // or any desired number of items
                    (index) => getShimmerLayoutFotTextField(context)
            ),
          ),
        ),
      );

}
