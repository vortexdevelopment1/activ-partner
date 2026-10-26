import 'dart:convert';
import 'package:activ_app/Style/activity_logos.dart';

import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:http/http.dart' as http;
import '../../../../api_calling/activity_setup_api.dart';
import 'package:flutter/material.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';

import '../../../../Beans/venue_type_model.dart';
import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../api_calling/api_constant.dart';
import '../../../../api_calling/api_request.dart';
import '../../../CommonCode.dart';
import 'AddVenuePhotoUploadScreen.dart';
import '../../../onboarding_widgets.dart';
import '../VenueActivityListScreen.dart';

class AddListActivityTypeScreen extends StatefulWidget {
  const AddListActivityTypeScreen({super.key, this.client});
  final http.Client? client;

  @override
  _State createState() => _State();
}

class _State extends State<AddListActivityTypeScreen> {
  List<VenueTypeModel> resultList = [];
  late final ActivitySetupApi _api;
  List<Map<String, dynamic>> _venues = [];
  String? _venueId, _loadError;
  @override
  void dispose() {
    _api.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Set<String> get _existingCategories =>
      (_venues.where((v) => v['id'] == _venueId).firstOrNull?['services']
                  as List? ??
              [])
          .whereType<Map>()
          .where((s) => ['approved', 'pending']
              .contains(s['status']?.toString().toLowerCase()))
          .map((s) => s['categoryId'].toString())
          .toSet();
  int page = 1;
  String noDataFound = NO_DATA_FOUND;
  ScrollController scrollController = ScrollController();

  bool isActivitySelected = false;
  bool isShimmerLoading = false;

  _State() {
    noDataFound = LOADING;
    page = 1;
  }

  @override
  void initState() {
    super.initState();
    _api = ActivitySetupApi(client: widget.client);
    isShimmerLoading = true;
    fetchData();
  }

  // Fetch Data Name
  Future<void> fetchData() async {
    if (mounted)
      setState(() {
        isShimmerLoading = true;
        _loadError = null;
      });
    try {
      final categories = await _api.categories();
      final venues = await _api.approvedVenues();
      final selected = await SharedPreference.readStr('venue_id');
      if (!mounted) return;
      _venues = venues;
      _venueId = venues.any((v) => v['id'] == selected)
          ? selected
          : venues.length == 1
              ? venues.first['id'].toString()
              : null;
      resultList = categories
          .map((c) => VenueTypeModel(
              id: c['id'].toString(),
              title: c['name'].toString(),
              type: c['type']?.toString() ?? ''))
          .toList();
      if (venues.isEmpty)
        _loadError = 'Your venue must be approved before adding an activity.';
    } catch (e) {
      if (mounted) _loadError = e.toString();
    } finally {
      if (mounted) setState(() => isShimmerLoading = false);
    }
  }

  void goToBackScreen(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute<void>(
        builder: (_) => VenueActivityListScreen(client: widget.client),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Container(
        decoration: context.getYellowGradient,
        child: SafeArea(
          left: false,
          top: true,
          bottom: true,
          right: false,
          child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Container(
                decoration: context.getYellowGradient,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: Column(
                    children: [
                      const OnboardingHeader(),
                      Container(
                        margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                        child: getStepBarCount(1 / 6, 1, 6),
                      ),
                      if (_venues.length > 1)
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: DropdownButtonFormField<String>(
                                value: _venueId,
                                hint: const Text('Select an approved venue'),
                                isExpanded: true,
                                items: _venues
                                    .map((v) => DropdownMenuItem(
                                        value: v['id'].toString(),
                                        child: Text(v['name'].toString())))
                                    .toList(),
                                onChanged: (value) => setState(() {
                                      _venueId = value;
                                      isActivitySelected = false;
                                      for (final item in resultList) {
                                        item.isSelected = false;
                                      }
                                    }))),
                      getOperateText(),
                      getOperateSubText(),
                      isShimmerLoading == true
                          ? buildShimmer(context)
                          : Expanded(
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
                                        onTap: () {
                                          goToBackScreen(context);
                                        },
                                        child: getBackButton(context, "Back",
                                            "selectActivity"))),
                                Expanded(
                                  flex: 7,
                                  child: InkWell(
                                      onTap: () async {
                                        if (isActivitySelected &&
                                            _venueId != null) {
                                          await SharedPreference.addStringToSF(
                                              'venue_id', _venueId!);
                                          final chosen = resultList
                                              .firstWhere((v) => v.isSelected);
                                          await SharedPreference.addStringToSF(
                                              'operate_value',
                                              jsonEncode({
                                                'id': chosen.id,
                                                'title': chosen.title
                                              }));
                                          if (!context.mounted) return;
                                          CommonUtilities.NavigateWithPush(
                                              context,
                                              AddVenuePhotoUploadScreen(
                                                  client: widget.client));
                                        } else {
                                          CommonUtilities.createSnackBar(
                                              context,
                                              ConstantsMessages
                                                  .selectVenueType);
                                        }
                                      },
                                      child: isActivitySelected &&
                                              _venueId != null
                                          ? getButtonBlack(
                                              context, "Next", "selectActivity")
                                          : getButtonGray(context, "Next",
                                              "selectActivity")),
                                )
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              )),
        ),
      ),
    );
  }

  Widget getOperateText() {
    return Container(
      margin: const EdgeInsets.only(top: 5, left: 15, right: 15, bottom: 10),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Select activity",
        style: TextStyle(
            fontSize: AppSize.size_25,
            fontFamily: 'Satoshi',
            color: AppColors.darkBlack,
            height: 1.2),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget getOperateSubText() {
    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15, bottom: 8),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Choose the activity available at your venue",
        style: TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'Satoshi',
          color: AppColors.black1,
        ),
      ),
    );
  }

  /// To get the List
  Widget getList(BuildContext context) {
    if (_loadError != null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_loadError!),
        TextButton(onPressed: fetchData, child: const Text('Retry'))
      ]));
    final activeList = resultList
        .where(
            (model) => model.active && !_existingCategories.contains(model.id))
        .toList();
    if (activeList.isEmpty)
      return const Center(
          child: Text(
              'All available sports are already active or under review at this venue.'));

    return Container(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: LazyLoadScrollView(
        scrollDirection: Axis.vertical,
        scrollOffset: activeList.length,
        onEndOfPage: () {},
        child: RefreshIndicator(
          onRefresh: _pullRefresh,
          color: AppColors.lineGradientStart, // loader color
          backgroundColor: AppColors.yellowTop, // background circle color
          strokeWidth: 3.0, // thickness
          displacement: 30,
          child: GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            padding:
                const EdgeInsets.only(top: 10, bottom: 0, left: 0, right: 0),
            itemCount: activeList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 180,
              mainAxisSpacing: 1.0,
              crossAxisSpacing: 1.0,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (BuildContext ctxt, int index) {
              return rowListItem(model: activeList[index], context: context);
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
    return Container(
      margin: EdgeInsets.fromLTRB(5, 5, 5, 10),
      decoration: model.isSelected
          ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.borderGradient1, AppColors.borderGradient2],
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : BoxDecoration(
              color: AppColors.gray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray, width: 1),
            ),
      child: InkWell(
        onTap: () async {
          // Single selection
          for (var item in resultList) {
            item.isSelected = false;
          }
          model.isSelected = true;

          isActivitySelected = resultList.any((item) => item.isSelected);

          // JSON object
          Map<String, dynamic> operateValue = {
            "id": model.id,
            "title": model.title,
          };
          // Convert to String
          String jsonString = jsonEncode(operateValue);
          // Save in SharedPreferences
          SharedPreference.addStringToSF(
              "operate_value", checkString(jsonString));
          String operateCValue =
              checkString(await SharedPreference.readStr("operate_value"));
          CommonUtilities.showLog("Saved operate_value => $operateCValue");
          setState(() {});
        },
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: model.isSelected
              ? EdgeInsets.fromLTRB(2, 2, 2, 2)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: model.isSelected ? AppColors.gray3 : AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
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
    return activityLogoAsset(model.title);
  }

  /// Image Layout.
  Widget getImage(VenueTypeModel model, BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: SizedBox(
        width: 46,
        height: 59,
        child: Image.asset(
          setTypeImages(model),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget getTitle(VenueTypeModel model, BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        (model.title != "") ? model.title : "",
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'Satoshi',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Widget getDescription(VenueTypeModel model, BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Text(
        (model.description != "") ? model.description : "",
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'Satoshi',
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
