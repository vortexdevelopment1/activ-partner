import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';
import '../StringExtensions.dart';

class VenueDetailsScreen extends StatefulWidget {
  const VenueDetailsScreen({Key? key}) : super(key: key);

  @override
  State<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends State<VenueDetailsScreen> {

  // Controllers
  TextEditingController venueNameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController venueLocationURLController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController areaController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController pinCodeController = TextEditingController();

  ScrollController scrollController = ScrollController();

  bool isShimmerLoading = false;
  String userMobileNumber = "";

  _VenueDetailsScreenState()
  {
    loadShimmer();
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
        debugPrint("❌ Venue Details not found for UID: $realUid");
        return;
      }

      final data = userDoc.data()?['venue_details'];

      if (data != null && data is Map<String, dynamic>) {
        venueNameController.text = data['venue_name'] ?? '';
        descriptionController.text = data['venue_description'] ?? '';
        venueLocationURLController.text = data['venue_location_url'] ?? '';
        addressController.text = data['venue_address'] ?? '';
        areaController.text = data['venue_area'] ?? '';
        cityController.text = data['venue_city'] ?? '';
        stateController.text = data['venue_state'] ?? '';
        pinCodeController.text = data['venue_pin_code'] ?? '';
      } else {
        venueNameController.text = '';
        descriptionController.text = '';
        venueLocationURLController.text = '';
        addressController.text = '';
        areaController.text = '';
        cityController.text = '';
        stateController.text = '';
        pinCodeController.text = '';
      }

      /*if (doc.exists && doc.data()!.containsKey('venue_details')) {
        final data = doc['venue_details'];

        venueNameController.text = data['venue_name'] ?? '';
        descriptionController.text = data['venue_description'] ?? '';
        venueLocationURLController.text = data['venue_location_url'] ?? '';
        addressController.text = data['venue_address'] ?? '';
        areaController.text = data['venue_area'] ?? '';
        cityController.text = data['venue_city'] ?? '';
        stateController.text = data['venue_state'] ?? '';
        pinCodeController.text = data['venue_pin_code'] ?? '';
      }*/
    } catch (e) {
      debugPrint("Error fetching venue details: $e");
    }

    setState(() => isShimmerLoading = false);
  }

  @override
  void dispose() {
     venueNameController.dispose();
     descriptionController.dispose();
     venueLocationURLController.dispose();
     addressController.dispose();
     areaController.dispose();
     cityController.dispose();
     stateController.dispose();
     pinCodeController.dispose();
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

                                          getVenueNameLabel(),
                                          getVenueNameField(context),

                                          getDescriptionLabel(),
                                          getDescriptionField(context),

                                          getLocationUrlLabel(),
                                          getLocationURLField(context),
                                          getLocationUrlCopyText(),

                                          getAddressLabel(),
                                          getAddressField(context),

                                          getAreaLabel(),
                                          getAreaField(context),

                                          getCityLabel(),
                                          getCityField(context),

                                          getStateLabel(),
                                          getStateField(context),

                                          getPinCodeLabel(),
                                          getPinCodeField(context),
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


  Widget getVenueNameLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: const Text(
            "Venue Name",
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

  Widget getVenueNameField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: venueNameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
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
              hintText: 'Enter Venue Name', // Set the hint label text
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

  Widget getDescriptionLabel() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: const Text(
              "Description (optional)",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontMedium',
                  color: AppColors.black1,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget getDescriptionField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: context.getTextFieldGradient,
      child: TextFormField(
        controller: descriptionController,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        cursorColor: AppColors.cursorBlack,
        /*inputFormatters: [
          LengthLimitingTextInputFormatter(50),
        ],*/
        maxLines: 3,
        maxLength: 200,
        style: TextStyle(
          fontSize:  AppSize.size_14,
          fontFamily: 'FontRegular',
          color: AppColors.darkBlack,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Briefly describe your venue',
          hintStyle: TextStyle(
            fontSize:  AppSize.size_14,
            fontFamily: 'FontRegular',
            color: AppColors.hintColor, // Text color of the hint label
          ),
        ),
      ),
    );
  }

  Widget getLocationUrlLabel() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: const Text(
              "Location URL",
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
      ),
    );
  }

  Widget getLocationURLField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: venueLocationURLController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Location URL', // Set the hint label text
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

  Widget getLocationUrlCopyText() {
    return Container(
      margin: EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
              width: 20,
              height: 20,
              child: Image.asset('assets/ic_question.png')
          ),
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.fromLTRB(0, 3, 0, 0),
            child: const Text(
              "Copy & add your venue’s location from Google Search.",
              style: TextStyle(
                  fontSize: AppSize.size_12,
                  fontFamily: 'FontMedium',
                  color: AppColors.hintColor,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          )
        ],
      ),
    );
  }

  Widget getAddressLabel() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: const Text(
              "Flat/Building, Floor Number (optional)",
              style: TextStyle(
                  fontSize: AppSize.size_14,
                  fontFamily: 'FontMedium',
                  color: AppColors.black1,
                  height: 1
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget getAddressField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: addressController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Flat/Building Number', // Set the hint label text
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

  Widget getAreaLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Area, Sector, Locality",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),

        /*Container(
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
        )*/
      ],
    );
  }

  Widget getAreaField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: areaController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Area, Sector, Locality', // Set the hint label text
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

  Widget getCityLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "City/Town",
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

  Widget getCityField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: cityController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter City/Town', // Set the hint label text
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

  Widget getStateLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "State",
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

  Widget getStateField(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            enabled: false,
            controller: stateController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Select State', // Set the hint label text
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

  Widget getPinCodeLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: const Text(
            "Pin Code",
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

  Widget getPinCodeField(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 8, 0, 8),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: pinCodeController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.number,
            cursorColor: AppColors.cursorBlack,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: TextStyle(
              fontSize:  AppSize.size_14,
              fontFamily: 'FontRegular',
              color: AppColors.darkBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter Pin Code', // Set the hint label text
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
