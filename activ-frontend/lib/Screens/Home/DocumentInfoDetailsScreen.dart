import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';
import '../MobileNumberFormatter.dart';
import '../StringExtensions.dart';

class DocumentInfoDetailsScreen extends StatefulWidget {
  const DocumentInfoDetailsScreen({Key? key}) : super(key: key);

  @override
  State<DocumentInfoDetailsScreen> createState() => _State();
}

class _State extends State<DocumentInfoDetailsScreen> {

  // Controllers
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController venueOwnerMobileNumberController = TextEditingController();

  ScrollController scrollController = ScrollController();
  bool isButtonEnabled = false;
  bool isShimmerLoading = false;

  String phoneCode = "+91";

  _State()
  {
    getData();
    loadShimmer();
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    setState(() {});
  }

  void _validateNumber(String input) {
    String digits = input.replaceAll('-', '');
    if (digits.length == 10) {
      setState(() {
        isButtonEnabled = true;
      });
    } else {
      setState(() {
        isButtonEnabled = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchVenueDetails();
  }

  Future loadShimmer() async {
    isShimmerLoading = true;
  }

  /// FETCH DATA FROM FIRESTORE
  Future<void> fetchVenueDetails() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('activ_user')
          .doc(uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('legal_document')) {
        final data = doc['legal_document'];

        emailController.text = data['aadhaar_full_name'] ?? '';
        fullNameController.text = data['aadhaar_number'] ?? '';
        mobileNumberController.text = data['aadhaar_pdf_file'] ?? '';
        mobileNumberController.text = data['gstin_number'] ?? '';
        mobileNumberController.text = data['gstin_pdf_file'] ?? '';
        mobileNumberController.text = data['pan_card_number'] ?? '';
        mobileNumberController.text = data['pan_card_pdf_file'] ?? '';

      }
    } catch (e) {
      debugPrint("Error fetching document details: $e");
    }

    setState(() => isShimmerLoading = false);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    mobileNumberController.dispose();
    venueOwnerMobileNumberController.dispose();
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
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double width = constraints.maxWidth;

                        bool isMobile = width < 600;
                        bool isTablet = width >= 600 && width < 1100;
                        double containerWidth =
                        isMobile ? width * 1 : (isTablet ? 500 : 600)
                        ;
                        return Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              getToolTab(context),

                              isShimmerLoading == true ? buildShimmer(context) : Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(15, 5, 15, 10),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    children: [
                                      Column(
                                        children: [

                                          getFullNameLabel(),
                                          getFullNameField(context),

                                          getEmailLabel(),
                                          getEmailField(context),

                                          getPhoneNumberText(),
                                          getMobileNumberField(context),

                                          getOwnerPhoneNumberText(),
                                          getOwnerMobileNumberField(context),

                                        ],
                                      ),
                                    ],
                                  )
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      )
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

          getTitleText(context, 'Venue Details', 'Venue_Details')

        ],
      ),
    );
  }

  Widget getAstrickLayout()
  {
    return Container(
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
    );
  }

  Widget getFullNameLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
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

        //getAstrickLayout(),
      ],
    );
  }

  Widget getFullNameField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
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
              // Input formatter to allow Only Characters + Space // Using a regular expression
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

  Widget getEmailLabel() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Email Address",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        //getAstrickLayout(),
      ],
    );
  }

  Widget getEmailField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: emailController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.emailAddress,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              new LengthLimitingTextInputFormatter(100),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Email Address', // Set the hint label text
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

  Widget getPhoneNumberText()
  {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Phone Number",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        //getAstrickLayout(),
      ],
    );
  }

  Widget getMobileNumberField(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
          color: AppColors.gray2,
          borderRadius: const BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: const Radius.circular(8),
          ),
          border: Border.all(color: AppColors.gray2, width: 1)),
      child: Padding(
        padding: const EdgeInsets.only(left: 0, right: 0),
        child: Row(
          children: [
            // Country Code Layout
            Container(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
              margin: const EdgeInsets.fromLTRB(5, 0, 0, 0),
              child: Row(
                children: [
                  Container(
                    child: Text(
                      (phoneCode!=null && phoneCode!="") ? phoneCode : "",
                      style: TextStyle(
                        fontSize:  AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider Line.
            Container(
              height: 50,
              margin: EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: VerticalDivider(
                color: AppColors.gray,
                thickness: 1,
              ),
            ),

            Expanded(
              //flex: 4,
              child: Container(
                child: TextFormField(
                  enabled: false,
                  controller: mobileNumberController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.number,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    MobileNumberFormatter(),
                  ],
                  onChanged: _validateNumber,
                  validator: (value) {
                    String digits = value?.replaceAll('-', '') ?? '';
                    if (digits.length != 10) {
                      return "Enter valid 10-digit mobile number";
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XX-XXXX-XXXX', // Set the hint label text
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

            Container(
              width: 15,
              height: 15,
              margin: EdgeInsets.only(right: 10),
              child: Image.asset('assets/ic_right_green.png'),
            ),
          ],
        ),
      ),
    );
  }


  Widget getOwnerPhoneNumberText()
  {
    return Visibility(
      visible: true,
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: const Text(
              "Alternate Phone Number",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontMedium',
                  color: AppColors.black1,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          ),

          //getAstrickLayout(),
        ],
      ),
    );
  }

  Widget getOwnerMobileNumberField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 0, right: 0),
        child: Row(
          children: [
            // Country Code Layout
            Container(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
              margin: const EdgeInsets.fromLTRB(5, 0, 0, 0),
              child: Row(
                children: [
                  Container(
                    child: Text(
                      (phoneCode!=null && phoneCode!="") ? phoneCode : "",
                      style: TextStyle(
                        fontSize:  AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider Line.
            Container(
              height: 50,
              margin: EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: VerticalDivider(
                color: AppColors.gray,
                thickness: 1,
              ),
            ),

            Expanded(
              //flex: 4,
              child: Container(
                child: TextFormField(
                  controller: venueOwnerMobileNumberController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.number,
                  cursorColor: AppColors.cursorBlack,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    MobileNumberFormatter(),
                  ],
                  onChanged: _validateNumber,
                  validator: (value) {
                    String digits = value?.replaceAll('-', '') ?? '';
                    if (digits.length != 10) {
                      return "Enter valid 10-digit mobile number";
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize:  AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XX-XXXX-XXXX', // Set the hint label text
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
          ],
        ),
      ),
    );
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
