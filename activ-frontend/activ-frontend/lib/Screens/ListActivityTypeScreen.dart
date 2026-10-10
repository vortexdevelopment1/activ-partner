import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/progress_bar/progress_bar_new.dart';
import '../Beans/venue_type_model.dart';
import '../api_calling/api_request.dart';
import 'CommonCode.dart';
import 'VenuePhotoUploadScreen.dart';
import 'onboarding_widgets.dart';

class ListActivityTypeScreen extends StatefulWidget {
  const ListActivityTypeScreen({super.key, this.client});
  final http.Client? client;
  @override
  _State createState() => _State();
}

class _State extends State<ListActivityTypeScreen> {
  List<VenueTypeModel> resultList = [];
  int page = 1;
  String noDataFound = NO_DATA_FOUND;
  ScrollController scrollController = ScrollController();
  TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  static const List<String> _filterLabels = ['All', 'Indoor Sports', 'Outdoor Sports', 'Water Sports'];

  static const Map<String, Set<String>> _filterTypeMap = {
    'Indoor Sports': {'gym', 'yoga', 'arts', 'dance', 'court', 'badminton', 'squash', 'table tennis', 'padel', 'pickle ball', 'tabletennis', 'pickleball'},
    'Outdoor Sports': {'football', 'cricket', 'basketball', 'tennis', 'athletics', 'cycling', 'running'},
    'Water Sports': {'pool', 'swimming', 'aquatics', 'diving', 'water polo'},
  };

  List<VenueTypeModel> get _filteredList {
    final query = _searchController.text.toLowerCase().trim();
    return resultList.where((model) {
      if (!model.active) return false;
      final matchesSearch = query.isEmpty || model.title.toLowerCase().contains(query);
      final matchesFilter = _selectedFilter == 'All' ||
          (_filterTypeMap[_selectedFilter]?.contains(model.type) ?? false);
      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) => a.title.trim().toLowerCase().compareTo(b.title.trim().toLowerCase()));
  }

  int currentStep = onboardingActivitiesStep;
  bool isActivitySelected = false;
  bool isShimmerLoading = false;
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

  _State() {
    noDataFound = LOADING;
    page=1;
    //setDummyData();
  }

  @override
  void initState() {
    super.initState();
    isShimmerLoading = true;
    fetchData();
  }

  // Fetch active categories from REST API
  Future<void> fetchData() async {
    try {
      final response = await (widget.client?.get(
        Uri.parse(CATEGORIES_URL),
        headers: {'accept': '*/*'},
      ) ?? http.get(
        Uri.parse(CATEGORIES_URL),
        headers: {'accept': '*/*'},
      ));

      if (!mounted) return;

      CommonUtilities.showLog("Categories status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final List<dynamic> list = body['data'] ?? [];

        setState(() {
          resultList = list.map((e) => VenueTypeModel(
            id: e['id'] ?? "",
            type: (e['name'] ?? "").toString().toLowerCase(),
            title: e['name'] ?? "",
            description: e['description'] ?? "",
            image: e['imageUrl'] ?? "",
            active: e['isActive'] ?? true,
          )).toList();
          isShimmerLoading = false;
        });
      } else {
        setState(() => isShimmerLoading = false);
      }
    } catch (e) {
      CommonUtilities.showLog("Error fetching categories: $e");
      if (!mounted) return;
      setState(() => isShimmerLoading = false);
    }
  }


  void createVenue() async {
    final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));

    // Read venue details saved from VenueScreen
    final venueDetailsStr = checkString(await SharedPreference.readStr("venue_details"));
    Map<String, dynamic> venueDetails = {};
    if (venueDetailsStr.isNotEmpty) {
      venueDetails = jsonDecode(venueDetailsStr);
    }

    // Read selected categories (now a JSON array)
    final operateValueStr = checkString(await SharedPreference.readStr("operate_value"));
    List<String> categoryIds = [];
    List<Map<String, dynamic>> selectedCategories = [];
    if (operateValueStr.isNotEmpty) {
      final decoded = jsonDecode(operateValueStr);
      if (decoded is List) {
        selectedCategories = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        categoryIds = selectedCategories
            .map((e) => e["id"]?.toString() ?? "")
            .where((id) => id.isNotEmpty)
            .toList();
      } else if (decoded is Map) {
        // backward-compat: single object saved previously
        final id = decoded["id"]?.toString() ?? "";
        if (id.isNotEmpty) {
          categoryIds = [id];
          selectedCategories = [Map<String, dynamic>.from(decoded)];
        }
      }
    }

    // Read contact phone info from TellUsAboutScreen
    final ownerPhone = checkString(await SharedPreference.readStr("owner_mobile_number")).replaceAll("-", "");
    final sameAsOwner = checkString(await SharedPreference.readStr("same_as_owner_number_checked"));
    final venueContactRaw = checkString(await SharedPreference.readStr("same_as_owner_number"));
    final venuePhone = (sameAsOwner == "true") ? ownerPhone : venueContactRaw.replaceAll("-", "");

    // Read commission percentage saved from VenueScreen
    final commissionStr = checkString(await SharedPreference.readStr("venue_commission"));
    final double commissionPct = double.tryParse(commissionStr) ?? 0.0;

    // Read selected amenities from CustomerPlacesOffer
    final placeOfferStr = checkString(await SharedPreference.readStr("place_offer"));
    List<String> amenities = [];
    if (placeOfferStr.isNotEmpty) {
      final placeOfferJson = jsonDecode(placeOfferStr);
      final List<dynamic> offerList = placeOfferJson["place_offer"] ?? [];
      amenities = offerList.map((e) => e["title"]?.toString() ?? "").where((t) => t.isNotEmpty).toList();
    }

    if (!mounted) return;
    ProgressBarNew().showLoader(context);

    try {
      final response = await http.post(
        Uri.parse(CREATE_VENUE_URL),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          "categoryIds": categoryIds,
          "name": venueDetails["venue_name"] ?? "",
          "description": venueDetails["venue_description"] ?? "",
          "address": venueDetails["venue_address"] ?? "",
          "flatBuilding": venueDetails["venue_area"] ?? "",
          "city": venueDetails["venue_city"] ?? "",
          "state": venueDetails["venue_state"] ?? "",
          "zipCode": venueDetails["venue_pin_code"] ?? "",
          "locationUrl": venueDetails["venue_location_url"] ?? "",
          "latitude": venueDetails["venue_latitude"],
          "longitude": venueDetails["venue_longitude"],
          "phone": ownerPhone,
          "venuePhone": venuePhone,
          "amenities": amenities,
          "commission": commissionPct,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      CommonUtilities.showLog("Create Venue status: ${response.statusCode}");
      CommonUtilities.showLog("Create Venue response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final venueId = body['data']?['id']?.toString() ?? body['data']?['_id']?.toString() ?? "";
        if (venueId.isNotEmpty) {
          await SharedPreference.addStringToSF("venue_id", venueId);
        }
        if (!mounted) return;
        final first = selectedCategories.first;
        final rest = selectedCategories.sublist(1);
        CommonUtilities.NavigateWithPush(context, VenuePhotoUploadScreen(
          currentCategory: first,
          remainingCategories: rest,
          categoryIndex: 1,
          totalCategories: selectedCategories.length,
          accumulatedTimings: const [],
        ));
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Failed to create venue. Please try again.';
        if (!mounted) return;
        CommonUtilities.createSnackBar(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      CommonUtilities.showLog("Create Venue error: $e");
      CommonUtilities.createSnackBar(context, 'Network error. Please check your connection.');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void goToBackScreen(BuildContext context)
  {
    Navigator.pop(context);
  }

  Widget getSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        cursorColor: AppColors.cursorBlack,
        style: const TextStyle(fontSize: AppSize.size_14, fontFamily: 'FontRegular', color: AppColors.darkBlack),
        decoration: InputDecoration(
          hintText: 'Search activities...',
          hintStyle: const TextStyle(fontSize: AppSize.size_14, fontFamily: 'FontRegular', color: AppColors.hintColor),
          prefixIcon: const Icon(Icons.search, color: AppColors.hintColor, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget getFilterChips() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 10, 0, 0),
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _filterLabels[index];
          final isSelected = label == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.purple : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? AppColors.purple : AppColors.gray1,
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'FontMedium',
                  color: isSelected ? AppColors.white : AppColors.darkBlack,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    double progress = currentStep / totalSteps;

    return PopScope(
      // Setting canPop to false means pop action can't happen directly
      canPop: false,
      // onPopInvokedWithResult handles the back button or pop gesture
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return; // If the pop is already handled, do nothing
        }
        goToBackScreen(context);
        // Return true to allow the pop action to proceed
        return Future.value(true);
      },
      child: OnboardingScaffold(
                  child: Column(
                    children: [

                      getActivIcon(),

                      getStepBar(progress),

                      getOperateText(),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Choose all the available activities at your venue',
                            style: OnboardingStyles.body.copyWith(color: AppColors.hintColor)),
                        ),
                      ),

                      getSearchBar(),

                      getFilterChips(),

                      isShimmerLoading == true ? buildShimmer(context) :
                      Expanded(
                        flex: 9,
                        child: getList(context),
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
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(15, 12, 8, 15),
                                          child: OnboardingButton(label: 'Back', outlined: true,
                                            borderRadius: 8, fontSize: 16,
                                            onPressed: () => Navigator.pop(context)),
                                        ))
                                ),


                                Expanded(
                                  flex: 7,
                                  child: InkWell(
                                      onTap: () {
                                        if (isActivitySelected) {
                                          createVenue();
                                        } else {
                                          CommonUtilities.createSnackBar(context, ConstantsMessages.selectVenueType);
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 12, 15, 15),
                                        child: OnboardingButton(label: 'Next', borderRadius: 8,
                                          disabledBackgroundColor: AppColors.gray2,
                                          disabledForegroundColor: AppColors.gray1,
                                          onPressed: isActivitySelected ? createVenue : null),
                                      )
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
  }

  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(0, 48, 0, 0),
        child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain)
    );
  }

  Widget getStepBar(double progress)
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
        child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getOperateText()
  {
    return Container(
      margin: EdgeInsets.only(top: 25, left: 15, right: 15, bottom: 10),
      alignment: Alignment.centerLeft,
      child: const Text(
        "What type of venue do you operate?",
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

  /// To get the List
  Widget getList(BuildContext context) {
    final list = _filteredList;

    if (list.isEmpty) {
      return Center(
          child: Text(
            'No activities found',
            style: const TextStyle(fontSize: AppSize.size_14, fontFamily: 'FontRegular', color: AppColors.hintColor),
          ),
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: LazyLoadScrollView(
        scrollDirection: Axis.vertical,
        scrollOffset: list.length,
        onEndOfPage: () {},
        child: RefreshIndicator(
          onRefresh: _pullRefresh,
          color: AppColors.lineGradientStart,
          backgroundColor: AppColors.yellowTop,
          strokeWidth: 3.0,
          displacement: 30,
          child: GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.only(top: 10, bottom: 0, left: 0, right: 0),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 168,
              mainAxisSpacing: 10.0,
              crossAxisSpacing: 10.0,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (BuildContext ctxt, int index) {
              return rowListItem(model: list[index], context: context);
            },
          ),
        ),
      ),
    );
  }

  /// Row item View
  Widget rowListItem({required VenueTypeModel model, required BuildContext context,})
  {
    return Container(
      key: ValueKey('activity-${model.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: model.isSelected ? AppColors.gray3 : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: model.isSelected ? AppColors.purple : AppColors.gray, width: 1),
      ),
      child: InkWell(
        onTap: () async {
          // Limit selection to 1 category during initial onboarding
          if (!model.isSelected) {
            final alreadySelected = resultList.any((item) => item.isSelected);
            if (alreadySelected) {
              CommonUtilities.createSnackBar(context,
                  "Only 1 activity type allowed now. You can add more after your account is approved.");
              return;
            }
          }

          // Toggle this item
          model.isSelected = !model.isSelected;
          isActivitySelected = resultList.any((item) => item.isSelected);

          // Build array of selected categories and save
          final selectedCategories = resultList
              .where((item) => item.isSelected)
              .map((item) => {"id": item.id, "title": item.title, "description": item.description})
              .toList();
          final jsonString = jsonEncode(selectedCategories);
          await SharedPreference.addStringToSF("operate_value", jsonString);
          CommonUtilities.showLog("Saved operate_value => $jsonString");
          if (!mounted) return;
          setState(() {});
        },
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              getImage(model, context),
              getTitle(model, context),
              getDescription(model, context),
            ],
          ),
        ),
      ),
    );
  }



  String setTypeImages(VenueTypeModel model) {
    if (model.type == "pool") {
      return "assets/ic_pool.png";
    } else if (model.type == "gym") {
      return "assets/ic_gym.png";
    } else if (model.type == "court") {
      return "assets/ic_cock.png";
    } else if (model.type == "football") {
      return "assets/ic_football.png";
    } else if (model.type == "yoga") {
      return "assets/ic_yoga.png";
    } else if (model.type == "arts") {
      return "assets/ic_arts.png";
    } else if (model.type == "dance") {
      return "assets/ic_dance.png";
    } else if (model.type == "others") {
      return "assets/ic_other.png";
    } else {
      return "assets/ic_pool.png";
    }
  }



  /// Image Layout.
  Widget getImage(VenueTypeModel model, BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      width: 46,
      height: 59,
      child: model.image.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: model.image,
              fit: BoxFit.contain,
              placeholder: (context, url) => const SizedBox(),
              errorWidget: (context, url, error) => _activityArtwork(model),
            )
          : _activityArtwork(model),
    );
  }

  Widget _activityArtwork(VenueTypeModel model) {
    final name = model.type;
    if (name == 'badminton' || name == 'court') {
      return Image.asset('assets/ic_cock.png', fit: BoxFit.contain);
    }
    if (name.contains('football') || name == 'teqball') {
      return Image.asset('assets/ic_football.png', fit: BoxFit.contain);
    }
    if (name == 'basketball') {
      return const Icon(Icons.sports_basketball, size: 46, color: Color(0xFFCC842B));
    }
    if ({'tennis', 'padel', 'pickle ball', 'pickleball', 'squash', 'table tennis'}.contains(name)) {
      return const Icon(Icons.sports_tennis, size: 46, color: Color(0xFF65A6A1));
    }
    if (name == 'hockey') {
      return const Icon(Icons.sports_hockey, size: 46, color: AppColors.black1);
    }
    if (name.contains('cricket')) {
      return const Icon(Icons.sports_cricket, size: 46, color: AppColors.green);
    }
    if (name == 'volleyball') {
      return const Icon(Icons.sports_volleyball, size: 46, color: Color(0xFFCC842B));
    }
    return Image.asset(setTypeImages(model), fit: BoxFit.contain);
  }

  Widget getTitle(VenueTypeModel model, BuildContext context)
  {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        model.title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'FontSemiBold',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Widget getDescription(VenueTypeModel model, BuildContext context)
  {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        model.description,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'FontRegular',
          color: AppColors.black1,
        ),
      ),
    );
  }

  Future<void> _pullRefresh() async {
    // Simulate network call or data refresh
    await Future.delayed(Duration(seconds: 2));

    fetchData();
  }

  Widget buildShimmer(BuildContext context) =>
      Expanded(
        flex: 9,
        child: Container(
          decoration: context.getYellowGradient,
          margin: EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: ListView(
            controller: scrollController, //set controller
            shrinkWrap: true,
            children: List.generate(
                10, // or any desired number of items
                    (index) => getShimmerLayoutWithoutImage(context)
            ),

          ),
        ),
      );
}
