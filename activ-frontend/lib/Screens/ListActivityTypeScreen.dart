import 'dart:convert';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:activ_app/Style/activity_logos.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../../api_calling/api_constant.dart';
import '../Beans/venue_type_model.dart';
import '../api_calling/api_request.dart';
import 'CategoryQuestionsScreen.dart';
import 'CommonCode.dart';
import 'VenuePhotoUploadScreen.dart';
import 'onboarding_widgets.dart';

class ListActivityTypeScreen extends StatefulWidget {
  const ListActivityTypeScreen({
    super.key,
    this.client,
    this.reviewMode = false,
    this.initialCategoryId,
  });
  final http.Client? client;
  final bool reviewMode;
  final String? initialCategoryId;
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

  static const List<String> _filterLabels = [
    'All',
    'Indoor Sports',
    'Outdoor Sports',
    'Water Sports'
  ];

  static const Map<String, Set<String>> _filterTypeMap = {
    'Indoor Sports': {
      'gym',
      'yoga',
      'arts',
      'dance',
      'court',
      'badminton',
      'squash',
      'table tennis',
      'padel',
      'pickle ball',
      'tabletennis',
      'pickleball'
    },
    'Outdoor Sports': {
      'football',
      'cricket',
      'basketball',
      'tennis',
      'athletics',
      'cycling',
      'running'
    },
    'Water Sports': {'pool', 'swimming', 'aquatics', 'diving', 'water polo'},
  };

  List<VenueTypeModel> get _filteredList {
    final query = _searchController.text.toLowerCase().trim();
    return resultList.where((model) {
      if (!model.active) return false;
      final matchesSearch =
          query.isEmpty || model.title.toLowerCase().contains(query);
      final matchesFilter = _selectedFilter == 'All' ||
          (_filterTypeMap[_selectedFilter]?.contains(model.type) ?? false);
      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) =>
          a.title.trim().toLowerCase().compareTo(b.title.trim().toLowerCase()));
  }

  int currentStep = onboardingActivitiesStep;
  bool isActivitySelected = false;
  bool isShimmerLoading = false;
  bool _savingVenue = false;
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
    page = 1;
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
          ) ??
          http.get(
            Uri.parse(CATEGORIES_URL),
            headers: {'accept': '*/*'},
          ));

      if (!mounted) return;

      CommonUtilities.showLog("Categories status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final List<dynamic> list = body['data'] ?? [];
        final raw = await SharedPreference.readStr('operate_value');
        final saved =
            raw == null || raw.isEmpty ? <dynamic>[] : jsonDecode(raw);
        final selections = saved is List ? saved : [saved];
        final selectedIds = selections
            .whereType<Map>()
            .map((entry) => entry['id']?.toString())
            .toSet();
        if (!mounted) return;

        setState(() {
          resultList = list
              .map((e) => VenueTypeModel(
                    id: e['id'] ?? "",
                    type: (e['name'] ?? "").toString().toLowerCase(),
                    title: e['name'] ?? "",
                    description: e['description'] ?? "",
                    image: e['imageUrl'] ?? "",
                    active: e['isActive'] ?? true,
                  ))
              .toList();
          for (final model in resultList) {
            model.isSelected = selectedIds.contains(model.id.toString());
          }
          isActivitySelected = resultList.any((model) => model.isSelected);
          isShimmerLoading = false;
        });
      } else {
        setState(() => isShimmerLoading = false);
      }
    } catch (e) {
      CommonUtilities.showLog("Error fetching categories: $e");
      if (!mounted) return null;
      setState(() => isShimmerLoading = false);
    }
  }

  void createVenue() {
    if (_savingVenue) return;
    final venueReady = _saveVenue();
    final selectedCategories = resultList
        .where((model) => model.isSelected)
        .map((model) => <String, dynamic>{
              'id': model.id,
              'title': model.title,
              'name': model.title,
              'description': model.description,
            })
        .toList();
    if (selectedCategories.isEmpty || !mounted) return;

    final first = selectedCategories.first;
    final rest = selectedCategories.sublist(1);
    CommonUtilities.NavigateWithPush(
      context,
      VenuePhotoUploadScreen(
        currentCategory: first,
        remainingCategories: rest,
        categoryIndex: 1,
        totalCategories: selectedCategories.length,
        accumulatedTimings: const [],
        venueReady: venueReady,
      ),
    );
  }

  Future<String?> _saveVenue() async {
    if (_savingVenue) return null;
    if (!mounted) return null;
    setState(() => _savingVenue = true);

    final storedValues = await Future.wait<String?>([
      SharedPreference.readStr("jwt_token"),
      SharedPreference.readStr("venue_id"),
      SharedPreference.readStr("venue_details"),
      SharedPreference.readStr("operate_value"),
      SharedPreference.readStr("owner_mobile_number"),
      SharedPreference.readStr("same_as_owner_number_checked"),
      SharedPreference.readStr("same_as_owner_number"),
      SharedPreference.readStr("venue_commission"),
      SharedPreference.readStr("place_offer"),
    ]);

    final jwtToken = checkString(storedValues[0]);
    final existingVenueId = checkString(storedValues[1]);

    // Read venue details saved from VenueScreen
    final venueDetailsStr = checkString(storedValues[2]);
    Map<String, dynamic> venueDetails = {};
    if (venueDetailsStr.isNotEmpty) {
      venueDetails = jsonDecode(venueDetailsStr);
    }

    // Read selected categories (now a JSON array)
    final operateValueStr = checkString(storedValues[3]);
    List<String> categoryIds = [];
    List<Map<String, dynamic>> selectedCategories = [];
    if (operateValueStr.isNotEmpty) {
      final decoded = jsonDecode(operateValueStr);
      if (decoded is List) {
        selectedCategories =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    final ownerPhone = checkString(storedValues[4]).replaceAll("-", "");
    final sameAsOwner = checkString(storedValues[5]);
    final venueContactRaw = checkString(storedValues[6]);
    final venuePhone = (sameAsOwner == "true")
        ? ownerPhone
        : venueContactRaw.replaceAll("-", "");

    // Read commission percentage saved from VenueScreen
    final commissionStr = checkString(storedValues[7]);
    final double commissionPct = double.tryParse(commissionStr) ?? 0.0;

    // Read selected amenities from CustomerPlacesOffer
    final placeOfferStr = checkString(storedValues[8]);
    List<String> amenities = [];
    if (placeOfferStr.isNotEmpty) {
      final placeOfferJson = jsonDecode(placeOfferStr);
      final List<dynamic> offerList = placeOfferJson["place_offer"] ?? [];
      amenities = offerList
          .map((e) => e["title"]?.toString() ?? "")
          .where((t) => t.isNotEmpty)
          .toList();
    }

    try {
      final payload = {
        "categoryIds": categoryIds,
        "name": venueDetails["venue_name"] ?? "",
        "description": venueDetails["venue_description"] ?? "",
        "address": (venueDetails["venue_search_address"] ?? '')
                .toString()
                .trim()
                .isNotEmpty
            ? venueDetails["venue_search_address"]
            : venueDetails["venue_address"] ?? "",
        "flatBuilding": [
          if ((venueDetails["venue_search_address"] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
            venueDetails["venue_address"],
          venueDetails["venue_area"],
        ]
            .where(
                (value) => value != null && value.toString().trim().isNotEmpty)
            .map((value) => value.toString().trim())
            .join(', '),
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
      };
      final response = existingVenueId.isEmpty
          ? await (widget.client?.post(
                Uri.parse(CREATE_VENUE_URL),
                headers: {
                  'accept': '*/*',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwtToken',
                },
                body: jsonEncode(payload),
              ) ??
              http.post(
                Uri.parse(CREATE_VENUE_URL),
                headers: {
                  'accept': '*/*',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwtToken',
                },
                body: jsonEncode(payload),
              ))
          : await (widget.client?.patch(
                Uri.parse("$CREATE_VENUE_URL/$existingVenueId"),
                headers: {
                  'accept': '*/*',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwtToken',
                },
                body: jsonEncode(payload),
              ) ??
              http.patch(
                Uri.parse("$CREATE_VENUE_URL/$existingVenueId"),
                headers: {
                  'accept': '*/*',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $jwtToken',
                },
                body: jsonEncode(payload),
              ));

      CommonUtilities.showLog("Save Venue status: ${response.statusCode}");
      CommonUtilities.showLog("Save Venue response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final venueId = body['data']?['id']?.toString() ??
            body['data']?['_id']?.toString() ??
            existingVenueId;
        final venueName = body['data']?['name']?.toString() ??
            venueDetails["venue_name"]?.toString() ??
            "";
        if (venueId.isNotEmpty) {
          await SharedPreference.addStringToSF("venue_id", venueId);
        }
        if (venueName.isNotEmpty) {
          await SharedPreference.addStringToSF("venue_name", venueName);
        }
        return venueId;
      } else {
        final body = jsonDecode(response.body);
        final msg =
            body['message'] ?? 'Failed to create venue. Please try again.';
        throw Exception(msg.toString());
      }
    } catch (e) {
      CommonUtilities.showLog("Save Venue error: $e");
      rethrow;
    } finally {
      if (mounted) setState(() => _savingVenue = false);
    }
  }

  Future<void> _continueReviewActivityFlow() async {
    if (_savingVenue) return;
    setState(() => _savingVenue = true);
    try {
      await _runReviewActivityFlow();
    } finally {
      if (mounted) setState(() => _savingVenue = false);
    }
  }

  Future<void> _runReviewActivityFlow() async {
    final venueId = checkString(await SharedPreference.readStr("venue_id"));
    final jwtToken = checkString(await SharedPreference.readStr("jwt_token"));
    final operateValueStr =
        checkString(await SharedPreference.readStr("operate_value"));
    List<Map<String, dynamic>> selectedCategories = [];
    List<String> categoryIds = [];

    if (operateValueStr.isNotEmpty) {
      final decoded = jsonDecode(operateValueStr);
      if (decoded is List) {
        selectedCategories =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (decoded is Map) {
        selectedCategories = [Map<String, dynamic>.from(decoded)];
      }
    }
    categoryIds = selectedCategories
        .map((e) => e["id"]?.toString() ?? "")
        .where((id) => id.isNotEmpty)
        .toList();

    if (venueId.isEmpty) {
      if (!mounted) return;
      CommonUtilities.createSnackBar(
          context, 'Venue not found. Please try again.');
      return;
    }

    if (selectedCategories.isEmpty || categoryIds.isEmpty) {
      if (!mounted) return;
      CommonUtilities.createSnackBar(
          context, ConstantsMessages.selectVenueType);
      return;
    }

    try {
      final response = await (widget.client?.patch ?? http.patch)(
        Uri.parse('$CREATE_VENUE_URL/$venueId'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'categoryIds': categoryIds}),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        dynamic body;
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          body = null;
        }
        final message = body is Map
            ? body['message'] ?? 'Could not update selected activity.'
            : 'Could not update selected activity.';
        CommonUtilities.createSnackBar(
            context, message is List ? message.join(', ') : message.toString());
        return;
      }
    } catch (e) {
      if (!mounted) return;
      CommonUtilities.showLog('Review activity sync error: $e');
      CommonUtilities.createSnackBar(
          context, 'Network error. Please check your connection.');
      return;
    }

    if (!mounted) return;
    final preferredIndex = selectedCategories.indexWhere(
        (category) => category['id']?.toString() == widget.initialCategoryId);
    if (preferredIndex > 0) {
      selectedCategories.insert(0, selectedCategories.removeAt(preferredIndex));
    }
    final first = selectedCategories.first;
    final rest = selectedCategories.sublist(1);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => CategoryQuestionsScreen(
                venueId: venueId,
                currentCategory: first,
                remainingCategories: rest,
                categoryIndex: 1,
                totalCategories: selectedCategories.length,
                accumulatedTimings: const [],
                reviewMode: true,
                client: widget.client,
              )),
    );
    if (mounted && saved == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void goToBackScreen(BuildContext context) {
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
        style: const TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'Satoshi',
            color: AppColors.darkBlack),
        decoration: InputDecoration(
          hintText: 'Search activities...',
          hintStyle: const TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'Satoshi',
              color: AppColors.hintColor),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.hintColor, size: 20),
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
      margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 15),
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _filterLabels[index];
          final isSelected = label == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = label),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.purple : AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppColors.purple : AppColors.gray,
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
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
            getStepBar(progress),
            getOperateText(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose all the available activities at your venue',
                    style: OnboardingStyles.body
                        .copyWith(color: AppColors.hintColor)),
              ),
            ),
            getSearchBar(),
            getFilterChips(),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Divider(
                key: Key('activity-filter-divider'),
                height: 1,
                thickness: 1,
                color: AppColors.gray,
              ),
            ),
            isShimmerLoading == true
                ? buildShimmer(context)
                : Expanded(
                    flex: 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        getList(context),
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: SizedBox(
                              key: Key('activity-filter-shadow'),
                              height: 6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x22000000),
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            Container(
              key: const Key('activity-footer'),
              margin: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  bottomBarShadow(),
                  Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(15, 12, 8, 15),
                                child: OnboardingButton(
                                    label: 'Back',
                                    outlined: true,
                                    borderRadius: 8,
                                    fontSize: 16,
                                    onPressed: () => Navigator.pop(context)),
                              ))),
                      Expanded(
                        flex: 7,
                        child: InkWell(
                            onTap: () {
                              if (_savingVenue) return;
                              if (isActivitySelected) {
                                if (widget.reviewMode) {
                                  _continueReviewActivityFlow();
                                } else {
                                  createVenue();
                                }
                              } else {
                                CommonUtilities.createSnackBar(
                                    context, ConstantsMessages.selectVenueType);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 15, 15),
                              child: OnboardingButton(
                                  label: 'Next',
                                  loading: _savingVenue,
                                  borderRadius: 8,
                                  disabledBackgroundColor: AppColors.gray2,
                                  disabledForegroundColor: AppColors.gray1,
                                  onPressed: isActivitySelected && !_savingVenue
                                      ? () {
                                          if (widget.reviewMode) {
                                            _continueReviewActivityFlow();
                                          } else {
                                            createVenue();
                                          }
                                        }
                                      : null),
                            )),
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

  Widget getStepBar(double progress) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      child: getStepBarCount(progress, currentStep, totalSteps),
    );
  }

  Widget getOperateText() {
    return Container(
      margin: EdgeInsets.only(top: 25, left: 15, right: 15, bottom: 10),
      alignment: Alignment.centerLeft,
      child: const Text(
        "What type of venue do you operate?",
        style: TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
            height: 1.2),
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
          style: const TextStyle(
              fontSize: AppSize.size_14,
              fontFamily: 'Satoshi',
              color: AppColors.hintColor),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
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
            clipBehavior: Clip.hardEdge,
            shrinkWrap: true,
            primary: false,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 208,
              mainAxisSpacing: 12.0,
              crossAxisSpacing: 12.0,
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
  Widget rowListItem({
    required VenueTypeModel model,
    required BuildContext context,
  }) {
    final cardRadius = BorderRadius.circular(16);
    final innerRadius = BorderRadius.circular(model.isSelected ? 14 : 15);

    return Container(
      decoration: BoxDecoration(
        color: model.isSelected ? null : AppColors.gray,
        gradient: model.isSelected
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.borderGradient1, AppColors.borderGradient2],
              )
            : null,
        borderRadius: cardRadius,
      ),
      padding: EdgeInsets.all(model.isSelected ? 2 : 1),
      child: Material(
        key: ValueKey('activity-${model.id}'),
        color: model.isSelected ? AppColors.gray3 : AppColors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: innerRadius,
          side: BorderSide.none,
        ),
        child: InkWell(
          borderRadius: innerRadius,
          onTap: () async {
            // Limit selection to 1 category. In review mode, choosing a new
            // activity replaces the previous one instead of blocking the tap.
            if (!model.isSelected) {
              final alreadySelected = resultList.any((item) => item.isSelected);
              if (alreadySelected && widget.reviewMode) {
                for (final item in resultList) {
                  item.isSelected = false;
                }
              } else if (alreadySelected) {
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
                .map((item) => {
                      "id": item.id,
                      "title": item.title,
                      "description": item.description
                    })
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
            padding: const EdgeInsets.all(10),
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
      ),
    );
  }

  String setTypeImages(VenueTypeModel model) {
    return activityLogoAsset(model.title);
  }

  /// Image Layout.
  Widget getImage(VenueTypeModel model, BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      child: _activityArtwork(model),
    );
  }

  Widget _activityArtwork(VenueTypeModel model) {
    return Image.asset(setTypeImages(model), fit: BoxFit.contain);
  }

  Widget getTitle(VenueTypeModel model, BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        model.title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'Satoshi',
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Widget getDescription(VenueTypeModel model, BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 0),
      child: Text(
        model.description,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'Satoshi',
          color: AppColors.black1,
          height: 1.3,
        ),
      ),
    );
  }

  Future<void> _pullRefresh() async {
    // Simulate network call or data refresh
    await Future.delayed(Duration(seconds: 2));

    fetchData();
  }

  Widget buildShimmer(BuildContext context) => Expanded(
        flex: 9,
        child: Container(
          decoration: context.getYellowGradient,
          margin: EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: ListView(
            controller: scrollController, //set controller
            shrinkWrap: true,
            children: List.generate(
                10, // or any desired number of items
                (index) => getShimmerLayoutWithoutImage(context)),
          ),
        ),
      );
}
