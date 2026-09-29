import 'dart:async';
import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:http/http.dart' as http;
import 'package:activ_app/Style/app_colors.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Beans/state_model.dart';
import '../Style/app_size.dart';
import '../Utills/common_utilities.dart';
import '../api_calling/api_constant.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'CurvePopupDesign.dart';
import 'CustomerPlacesOffer.dart';

class VenueScreen extends StatefulWidget {
  const VenueScreen({super.key});

  @override
  State<VenueScreen> createState() => _State();
}

class _State extends State<VenueScreen> {

  TextEditingController venueNameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController venueAddressSearchController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController areaController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController pinCodeController = TextEditingController();

  String _selectedPlaceUrl = '';
  double? _selectedLat;
  double? _selectedLon;
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _showSuggestions = false;
  Timer? _searchDebounce;
  static const String _mapsApiKey = 'AIzaSyB8CL4cLELFreHWPY_NnmjwCo_mWS7T6Ng';

  List<StateModel> stateNameResultList = [];


  bool isButtonEnabled = false;
  bool isChecked = false;
  String phoneCode = "", userMobileNumber = "";

  double _commissionPct = 10.0;
  bool _commissionLoading = false;
  bool _pincodeResolved = false;
  bool _pincodeError = false;
  Timer? _debounce;

  int currentStep = 5;
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
    fetchStates();
    super.initState();
  }

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
  }

  Future<void> _fetchCommission(String city) async {
    if (city.isEmpty) return;
    setState(() => _commissionLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$COMMISSION_BY_CITY_URL/${Uri.encodeComponent(city)}'),
        headers: {'accept': '*/*'},
      );
      CommonUtilities.showLog("Commission status: ${response.statusCode}");
      CommonUtilities.showLog("Commission response: ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final pct = (body['data']?['commissionPercentage'] as num?)?.toDouble();
        if (pct != null && mounted) {
          setState(() {
            _commissionPct = pct;
            _commissionLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      CommonUtilities.showLog("Commission fetch error: $e");
    }
    if (mounted) setState(() => _commissionLoading = false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    venueNameController.dispose();
    descriptionController.dispose();
    venueAddressSearchController.dispose();
    addressController.dispose();
    areaController.dispose();
    cityController.dispose();
    stateController.dispose();
    pinCodeController.dispose();
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
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Expanded(
                              child: Container(
                                margin: EdgeInsets.fromLTRB(15, 0, 15, 0),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [

                                    getActivIcon('assets/activ_tm.svg'),

                                    getStepBarCount(progress, currentStep, totalSteps),

                                    getText('Tell us about your venue'),

                                    getSubText("Let's get your venue details ready for members"),

                                    getVenueNameLabel(),
                                    getVenueNameField(context),

                                    getDescriptionLabel(),
                                    getDescriptionField(context),

                                    getLocationUrlLabel(),
                                    getAddressSearchField(context),

                                    getAddressLabel(),
                                    getAddressField(context),

                                    getAreaLabel(),
                                    getAreaField(context),

                                    getPinCodeLabel(),
                                    getPinCodeField(context),

                                    getCityLabel(),
                                    getCityField(context),

                                    getStateLabel(),
                                    getStateField(context),

                                    Container(
                                      margin: EdgeInsets.fromLTRB(0, 20, 0, 15),
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
                                        margin: EdgeInsets.fromLTRB(10, 10, 10, 15),
                                        child: Column(
                                          children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  margin: EdgeInsets.only(right: 2),
                                                  alignment: Alignment.centerLeft,
                                                  child: const Text(
                                                    "Activ's Commission Structure",
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: AppSize.size_16,
                                                        fontFamily: 'FontSemiBold',
                                                        color: AppColors.darkBlack,
                                                    ),
                                                    textAlign: TextAlign.left,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
                                                margin: const EdgeInsets.only(top: 2),
                                                decoration: BoxDecoration(
                                                    color: AppColors.redBG,
                                                    borderRadius: const BorderRadius.only(
                                                      topLeft: const Radius.circular(25),
                                                      topRight: const Radius.circular(25),
                                                      bottomLeft: const Radius.circular(25),
                                                      bottomRight: const Radius.circular(25),
                                                    ),
                                                    border: Border.all(color: AppColors.redBG, width: 1)
                                                ),
                                                child: const Text(
                                                  "IMPORTANT",
                                                  style: TextStyle(
                                                      fontSize: AppSize.size_10,
                                                      fontFamily: 'FontBold',
                                                      color: AppColors.red,
                                                  ),
                                                  textAlign: TextAlign.left,
                                                ),
                                              ),
                                            ],
                                          ),
                                            Container(
                                              margin: EdgeInsets.only(top: 15),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Container(
                                                        alignment: Alignment.centerLeft,
                                                        margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                        child: const Text(
                                                          "For your venue",
                                                          style: TextStyle(
                                                              fontSize: AppSize.size_14,
                                                              fontFamily: 'FontMedium',
                                                              color: AppColors.darkBlack,
                                                              height: 1
                                                          ),
                                                          textAlign: TextAlign.left,
                                                        ),
                                                      ),

                                                      _commissionLoading
                                                          ? const SizedBox(
                                                              width: 14,
                                                              height: 14,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            )
                                                          : Text(
                                                              "${_commissionPct.toStringAsFixed(_commissionPct == _commissionPct.truncateToDouble() ? 0 : 1)}%",
                                                              style: const TextStyle(
                                                                  fontSize: AppSize.size_14,
                                                                  fontFamily: 'FontMedium',
                                                                  color: AppColors.purple,
                                                                  height: 1
                                                              ),
                                                              textAlign: TextAlign.left,
                                                            )
                                                    ],
                                                  ),
                                                  Container(
                                                    margin: EdgeInsets.only(top: 8),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          alignment: Alignment.centerLeft,
                                                          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                          child: const Text(
                                                            "Standard rate",
                                                            style: TextStyle(
                                                                fontSize: AppSize.size_12,
                                                                fontFamily: 'FontMedium',
                                                                color: AppColors.hintColor,
                                                                height: 1
                                                            ),
                                                            textAlign: TextAlign.left,
                                                          ),
                                                        ),

                                                        Container(
                                                          alignment: Alignment.centerLeft,
                                                          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                          child: const Text(
                                                            "Per booking",
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
                                                  ),

                                                  Container(
                                                    margin: EdgeInsets.only(top: 15),
                                                    color: AppColors.gray,
                                                    height: 1,
                                                  ),

                                                  Container(
                                                    margin: EdgeInsets.only(top: 15),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          alignment: Alignment.centerLeft,
                                                          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                          child: const Text(
                                                            "Your earnings",
                                                            style: TextStyle(
                                                                fontSize: AppSize.size_14,
                                                                fontFamily: 'FontMedium',
                                                                color: AppColors.darkBlack,
                                                                height: 1
                                                            ),
                                                            textAlign: TextAlign.left,
                                                          ),
                                                        ),

                                                        _commissionLoading
                                                            ? const SizedBox(
                                                                width: 14,
                                                                height: 14,
                                                                child: CircularProgressIndicator(strokeWidth: 2),
                                                              )
                                                            : Builder(
                                                                builder: (context) {
                                                                  final net = (100 - _commissionPct).toStringAsFixed(
                                                                      (100 - _commissionPct) == (100 - _commissionPct).truncateToDouble() ? 0 : 1);
                                                                  return Text(
                                                                    "₹$net",
                                                                    style: const TextStyle(
                                                                        fontSize: AppSize.size_14,
                                                                        fontFamily: 'FontMedium',
                                                                        color: AppColors.purple,
                                                                        height: 1
                                                                    ),
                                                                    textAlign: TextAlign.left,
                                                                  );
                                                                },
                                                              )
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    margin: EdgeInsets.only(top: 8),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          alignment: Alignment.centerLeft,
                                                          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                          child: const Text(
                                                            "Example: For every ₹100 booking",
                                                            style: TextStyle(
                                                                fontSize: AppSize.size_12,
                                                                fontFamily: 'FontMedium',
                                                                color: AppColors.hintColor,
                                                                height: 1
                                                            ),
                                                            textAlign: TextAlign.left,
                                                          ),
                                                        ),

                                                        Container(
                                                          alignment: Alignment.centerLeft,
                                                          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                                                          child: const Text(
                                                            "Net amount",
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
                                                  ),

                                                  Container(
                                                    margin: EdgeInsets.only(top: 15),
                                                    color: AppColors.gray,
                                                    height: 1,
                                                  ),
                                                ],
                                              )
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
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      alignment: Alignment.centerLeft,
                                                      child: const Text(
                                                        "Note: Commission rates vary by city to ensure pricing and operational coverage across India.",
                                                        style: TextStyle(
                                                            fontSize: AppSize.size_14,
                                                            fontFamily: 'FontMedium',
                                                            color: AppColors.purple1,
                                                            height: 1.4
                                                        ),
                                                        textAlign: TextAlign.left,
                                                      ),
                                                    ),

                                                    GestureDetector(
                                                      onTap: _showCommissionInfoDialog,
                                                      child: Container(
                                                        margin: EdgeInsets.only(top: 5),
                                                        alignment: Alignment.centerLeft,
                                                        child: const Text(
                                                          "Learn more about how commissions work →",
                                                          style: TextStyle(
                                                              fontSize: AppSize.size_13,
                                                              fontFamily: 'FontBold',
                                                              color: AppColors.purple,
                                                              height: 1
                                                          ),
                                                          textAlign: TextAlign.left,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
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
                                              child: getBackButton(context, "Back", "venueScreen"))
                                      ),


                                      Expanded(
                                        flex: 7,
                                        child: InkWell(
                                            onTap: ()
                                            async {
                                              if(validation(context))
                                              {
                                               /* AuthService authService = AuthService();
                                                 authService.uploadFacilitiesName().then((value) async
                                                {
                                                });*/

                                                // JSON object
                                                Map<String, dynamic> venueDetails = {
                                                  "venue_name": venueNameController.text.toString().trim(),
                                                  "venue_description": descriptionController.text.toString().trim(),
                                                  "venue_location_url": _selectedPlaceUrl,
                                                  "venue_address": addressController.text.toString().trim(),
                                                  "venue_area": areaController.text.toString().trim(),
                                                  "venue_city": cityController.text.toString().trim(),
                                                  "venue_state": stateController.text.toString().trim(),
                                                  "venue_pin_code": pinCodeController.text.toString().trim(),
                                                  "venue_latitude": _selectedLat,
                                                  "venue_longitude": _selectedLon,
                                                };
                                                // Convert to String
                                                String jsonString = jsonEncode(venueDetails);
                                                // Save in SharedPreferences
                                                SharedPreference.addStringToSF("venue_details", checkString(jsonString));
                                                SharedPreference.addStringToSF("venue_commission", _commissionPct.toString());
                                                String venueDetailsSave = checkString(await SharedPreference.readStr("venue_details"));
                                                CommonUtilities.showLog("Saved operate_value => $venueDetailsSave");

                                                CommonUtilities.NavigateWithPush(context, CustomerPlacesOffer());
                                              }else{}

                                            },
                                            child: getButtonBlack(context, "Next", "venueScreen")
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


  Widget getVenueNameLabel() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(0, 15, 0, 0),
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
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          const Text(
            "Venue Address",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.black1,
                height: 1),
          ),
          const Text(
            "*",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontMedium',
                color: AppColors.red,
                height: 1),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() { _placeSuggestions = []; _showSuggestions = false; });
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _mapsApiKey,
        },
        body: jsonEncode({
          'input': input,
          'includedRegionCodes': ['in'],
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = (data['suggestions'] as List? ?? [])
            .map<Map<String, dynamic>>((s) {
              final p = s['placePrediction'];
              return {
                'placeId': p['placeId'] as String,
                'description': p['text']['text'] as String,
              };
            })
            .toList();
        setState(() { _placeSuggestions = suggestions; _showSuggestions = suggestions.isNotEmpty; });
      }
    } catch (e) {
      CommonUtilities.showLog("Places API error: $e");
    }
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    // fallback: geographic center of India
    double lat = 20.5937;
    double lon = 78.9629;

    try {
      final response = await http.get(
        Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
        headers: {
          'X-Goog-Api-Key': _mapsApiKey,
          'X-Goog-FieldMask': 'addressComponents,location',
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final components = data['addressComponents'] as List? ?? [];

        String pincode = '', city = '', state = '', sublocality = '', premise = '';

        for (final c in components) {
          final types = (c['types'] as List).map((t) => t.toString()).toList();
          final longName = c['longText'] as String? ?? '';

          if (types.contains('postal_code')) pincode = longName;
          if (types.contains('locality')) city = longName;
          if (types.contains('administrative_area_level_2') && city.isEmpty) city = longName;
          if (types.contains('administrative_area_level_1')) state = longName;
          if (types.contains('sublocality_level_1')) sublocality = longName;
          if (types.contains('sublocality') && sublocality.isEmpty) sublocality = longName;
          if (types.contains('premise')) premise = longName;
        }

        final location = data['location'];
        lat = (location?['latitude'] as num?)?.toDouble() ?? lat;
        lon = (location?['longitude'] as num?)?.toDouble() ?? lon;

        setState(() {
          if (pincode.isNotEmpty) pinCodeController.text = pincode;
          if (city.isNotEmpty) cityController.text = city;
          if (state.isNotEmpty) stateController.text = state;
          if (sublocality.isNotEmpty) areaController.text = sublocality;
          if (premise.isNotEmpty) addressController.text = premise;
          _selectedLat = lat;
          _selectedLon = lon;
          if (city.isNotEmpty || state.isNotEmpty) {
            _pincodeResolved = true;
            _pincodeError = false;
          }
        });
        if (city.isNotEmpty) _fetchCommission(city);
      }
    } catch (e) {
      CommonUtilities.showLog("Place details error: $e");
    }

    // always open map picker — even if API failed, user can manually adjust pin
    if (mounted) {
      await _showMapPicker(lat, lon);
    }
  }

  Future<void> _showMapPicker(double initialLat, double initialLon) async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MapPickerPage(
          initialLat: initialLat,
          initialLon: initialLon,
          initialAddress: venueAddressSearchController.text,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLon = result.longitude;
      });
      // only reverse geocode if user moved the pin more than ~100 metres
      if (_hasMovedSignificantly(initialLat, initialLon, result.latitude, result.longitude)) {
        await _reverseGeocode(result.latitude, result.longitude);
      }
    }
  }

  bool _hasMovedSignificantly(double lat1, double lon1, double lat2, double lon2) {
    // ~0.001 degree ≈ 111 metres — safe threshold to detect intentional moves
    return (lat2 - lat1).abs() > 0.001 || (lon2 - lon1).abs() > 0.001;
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty || !mounted) return;
      final place = placemarks.first;
      setState(() {
        if (place.subLocality?.isNotEmpty == true)
          areaController.text = place.subLocality!;
        if (place.locality?.isNotEmpty == true) {
          cityController.text = place.locality!;
          _pincodeResolved = true;
          _pincodeError = false;
        }
        if (place.administrativeArea?.isNotEmpty == true)
          stateController.text = place.administrativeArea!;
        if (place.postalCode?.isNotEmpty == true)
          pinCodeController.text = place.postalCode!;
      });
      if (place.locality?.isNotEmpty == true)
        _fetchCommission(place.locality!);
      CommonUtilities.showLog(
          "Reverse geocode: ${place.locality}, ${place.administrativeArea}, ${place.postalCode}");
    } catch (e) {
      CommonUtilities.showLog("Reverse geocode error: $e");
    }
  }

  Widget getAddressSearchField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          decoration: context.getTextFieldGradient,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: venueAddressSearchController,
                    textInputAction: TextInputAction.search,
                    keyboardType: TextInputType.streetAddress,
                    cursorColor: AppColors.cursorBlack,
                    onChanged: (value) {
                      setState(() {
                        _selectedPlaceUrl = '';
                        _selectedLat = null;
                        _selectedLon = null;
                        addressController.clear();
                        areaController.clear();
                        pinCodeController.clear();
                        cityController.clear();
                        stateController.clear();
                        _pincodeResolved = false;
                        _pincodeError = false;
                      });
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                        _fetchPlaceSuggestions(value.trim());
                      });
                    },
                    style: const TextStyle(
                      fontSize: AppSize.size_14,
                      fontFamily: 'FontRegular',
                      color: AppColors.darkBlack,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search your venue address',
                      hintStyle: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontRegular',
                        color: AppColors.hintColor,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_selectedPlaceUrl.isNotEmpty)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                if (_selectedPlaceUrl.isEmpty && venueAddressSearchController.text.isNotEmpty)
                  const Icon(Icons.search, color: AppColors.hintColor, size: 20),
              ],
            ),
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.gray),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _placeSuggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.gray),
              itemBuilder: (context, index) {
                final s = _placeSuggestions[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      venueAddressSearchController.text = s['description'] as String;
                      _selectedPlaceUrl = 'https://maps.google.com/?q=place_id:${s['placeId']}';
                      _showSuggestions = false;
                      _placeSuggestions = [];
                    });
                    _fetchPlaceDetails(s['placeId'] as String);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.hintColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s['description'] as String,
                            style: const TextStyle(
                              fontSize: AppSize.size_13,
                              fontFamily: 'FontRegular',
                              color: AppColors.darkBlack,
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
      ],
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
            "Area, Sector, Locality (optional)",
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
            readOnly: _pincodeResolved,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            cursorColor: AppColors.cursorBlack,
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), () {
                _fetchCommission(value.trim());
              });
            },
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
    return InkWell(
      onTap: _pincodeResolved ? null : () async {
        await fetchStates();
        showStateNamePopUp(context);
      },
      child: Container(
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
      ),
    );
  }

  // Fetch State Name
  Future<void> fetchStates() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("activ_state_name")
          .doc("state_document")
          .get();

      if (snapshot.exists) {
        var data = snapshot.data();
        var list = data?["state_name"] as List<dynamic>;

        stateNameResultList =
            list.map((e) => StateModel.fromJson(e)).toList();
      }
    } catch (e) {
      CommonUtilities.showLog("Error fetching states: $e");
    }
  }

  Future<StateModel?> showStateNamePopUp(BuildContext context) {
    TextEditingController searchController = TextEditingController();

    // Initially, sirf active states ko filter karo
    List<StateModel> filteredList = stateNameResultList.where((state) => state.active).toList();

    return showModalBottomSheet<StateModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (context, setState1) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: DraggableScrollableSheet(
                initialChildSize: 0.72,
                maxChildSize: 0.9,
                expand: true,
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    alignment: Alignment.bottomCenter,
                    child: CurvePopupDesign(
                      screenName: '',
                      child: Column(
                        children: [
                          // Search Field
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: "Search State",
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                              onChanged: (value) {
                                setState1(() {
                                  // Search ke saath bhi active filter maintain karo
                                  filteredList = stateNameResultList
                                      .where((state) =>
                                  state.active &&
                                      state.name.toLowerCase().contains(value.toLowerCase()))
                                      .toList();
                                });
                              },
                            ),
                          ),

                          // State List
                          Expanded(
                            child: Container(
                              color: AppColors.white,
                              child: ListView.separated(
                                controller: scrollController,
                                shrinkWrap: true,
                                itemCount: filteredList.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.gray),
                                itemBuilder: (BuildContext context, int index) {
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    title: Text(
                                      filteredList[index].name,
                                      style: TextStyle(
                                        fontSize: AppSize.size_14,
                                        fontFamily: 'FontSemiBold',
                                        color: AppColors.darkBlack,
                                      ),
                                    ),
                                    onTap: () {
                                      stateController.text = filteredList[index].name;
                                      Navigator.of(context).pop(filteredList[index]);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
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
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: context.getTextFieldGradient,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          child: TextFormField(
            controller: pinCodeController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              if (_pincodeResolved || _pincodeError) {
                setState(() {
                  _pincodeResolved = false;
                  _pincodeError = false;
                });
              }
              if (value.length == 6) _lookupPincode(value);
            },
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

  Future<void> _lookupPincode(String pincode) async {
    try {
      final response = await http.get(
        Uri.parse('$PINCODE_LOOKUP_URL/$pincode'),
        headers: {'accept': '*/*'},
      );
      CommonUtilities.showLog("Pincode lookup status: ${response.statusCode}");
      CommonUtilities.showLog("Pincode lookup response: ${response.body}");
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        final String city = (data['city'] ?? '').toString();
        final String state = (data['state'] ?? '').toString();
        setState(() {
          if (city.isNotEmpty) cityController.text = city;
          if (state.isNotEmpty) stateController.text = state;
          if (city.isNotEmpty || state.isNotEmpty) {
            _pincodeResolved = true;
            _pincodeError = false;
          }
        });
        if (city.isNotEmpty) _fetchCommission(city);
      } else {
        setState(() {
          _pincodeError = true;
          _pincodeResolved = false;
          cityController.clear();
          stateController.clear();
        });
        CommonUtilities.createSnackBarLong(context, "Incorrect pin code. Please enter a valid 6-digit pin code.");
      }
    } catch (e) {
      CommonUtilities.showLog("Pincode lookup error: $e");
      if (!mounted) return;
      setState(() => _pincodeError = true);
      CommonUtilities.createSnackBarLong(context, "Incorrect pin code. Please enter a valid 6-digit pin code.");
    }
  }

  // ─── Commission info popup ─────────────────────────────────────────────────

  static const String _commissionInfoText = '''
How Commission Works

ACTIV charges a small commission on each booking made at your venue through our platform. This helps us maintain and grow the services we offer to you and your customers.

What is Commission?
Commission is a percentage of the booking amount that ACTIV retains as a fee for providing the platform, payment processing, customer support, and marketing services.

How is it Calculated?
Example: If a customer books your venue for ₹500 and the commission rate is 12%, ACTIV retains ₹60 and you receive ₹440.

When Do I Get Paid?
Earnings are credited to your registered bank account within 3–5 business days after a booking is completed and confirmed.

City-Based Rates
Commission rates may vary by city based on operational costs, demand levels, and local market conditions. Your rate is determined at the time of venue registration and is shown clearly during onboarding.

Transparency
You will always see the exact commission rate and your estimated net earnings before confirming your listing. This rate is locked in for your venue and will only change with prior written notice from ACTIV.

GST & Taxes
All applicable taxes are calculated on top of the booking amount as per government regulations and are displayed separately to the customer.

For any queries regarding commission or payouts, please reach out to ACTIV support through the Help & Support section in the app.
''';

  void _showCommissionInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
                  const Expanded(
                    child: Text(
                      'How Commission Works',
                      style: TextStyle(
                        fontSize: AppSize.size_16,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
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
                  _commissionInfoText.trim(),
                  style: const TextStyle(
                    fontSize: AppSize.size_14,
                    fontFamily: 'FontRegular',
                    color: AppColors.darkBlack,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool validation(BuildContext context) {

    if (venueNameController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterVenueName);
      return false;
    }
    else if (venueAddressSearchController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, "Please search and select your venue address");
      return false;
    }
    else if (_selectedPlaceUrl.isEmpty) {
      CommonUtilities.createSnackBar(context, "Please select an address from the suggestions");
      return false;
    }
    /*else if (areaController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterAreaName);
      return false;
    }*/
    else if (cityController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterCityName);
      return false;
    }
    else if (stateController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterStateName);
      return false;
    }
    else if (pinCodeController.text.trim().isEmpty) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterPincode);
      return false;
    }
    else if (pinCodeController.text.trim().length != 6) {
      CommonUtilities.createSnackBar(context, ConstantsMessages.enterValidPincode);
      return false;
    }
    else if (_pincodeError) {
      CommonUtilities.createSnackBarLong(context, "Incorrect pin code. Please enter a valid 6-digit pin code.");
      return false;
    }
    return true;
  }
}

class _MapPickerPage extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final String initialAddress;

  const _MapPickerPage({
    required this.initialLat,
    required this.initialLon,
    required this.initialAddress,
  });

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  static const double _cardHeight = 180.0;

  late LatLng _pinPosition;
  bool _isMoving = false;
  bool _mapReady = false;
  String _currentAddress = '';
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _pinPosition = LatLng(widget.initialLat, widget.initialLon);
    _currentAddress = widget.initialAddress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Lat: ${widget.initialLat.toStringAsFixed(6)},  Lon: ${widget.initialLon.toStringAsFixed(6)}',
          style: const TextStyle(fontFamily: 'FontRegular'),
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.darkBlack,
      ));
    });
  }

  Future<void> _reverseGeocodePin() async {
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        _pinPosition.latitude,
        _pinPosition.longitude,
      );
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = <String>[
        if ((p.name ?? '').isNotEmpty) p.name!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      if (mounted) setState(() => _currentAddress = parts.join(', '));
    } catch (_) {}
    if (mounted) setState(() => _geocoding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen Google Map — padding shifts camera center above the bottom card
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.initialLat, widget.initialLon),
              zoom: 19,
            ),
            padding: EdgeInsets.only(bottom: _cardHeight),
            onMapCreated: (_) {},
            onCameraMove: (position) {
              if (!_mapReady) return;
              setState(() {
                _isMoving = true;
                _pinPosition = position.target;
              });
            },
            onCameraIdle: () {
              if (!mounted) return;
              if (!_mapReady) {
                setState(() => _mapReady = true);
                return;
              }
              setState(() => _isMoving = false);
              _reverseGeocodePin();
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.darkBlack, size: 20),
                ),
              ),
            ),
          ),

          // Pin centered in visible map area (above bottom card)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: _cardHeight,
            child: Center(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  // -22 shifts shadow dot to camera target; -34 adds lift during drag
                  transform: Matrix4.translationValues(0, _isMoving ? -34 : -22, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.darkBlack,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.circle, color: Colors.white, size: 10),
                      ),
                      Container(width: 2, height: 20, color: AppColors.darkBlack),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isMoving ? 8 : 14,
                        height: _isMoving ? 4 : 6,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -3))],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Move map to set location",
                    style: TextStyle(
                      fontSize: AppSize.size_12,
                      fontFamily: 'FontRegular',
                      color: AppColors.hintColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _geocoding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.darkBlack,
                              ),
                            )
                          : const Icon(Icons.location_on, color: AppColors.darkBlack, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _geocoding
                              ? "Getting address..."
                              : (_currentAddress.isNotEmpty
                                  ? _currentAddress
                                  : "Selected location"),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: 'FontSemiBold',
                            color: _geocoding ? AppColors.hintColor : AppColors.darkBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlack,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, _pinPosition),
                      child: const Text(
                        "Confirm Location",
                        style: TextStyle(
                          fontSize: AppSize.size_15,
                          fontFamily: 'FontSemiBold',
                          color: Colors.white,
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
    );
  }
}
