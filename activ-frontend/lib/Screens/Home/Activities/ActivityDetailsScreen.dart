import 'package:activ_app/Style/app_size.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../../Beans/activity_model.dart';
import '../../../Beans/venue_image_model.dart';
import '../../../Style/app_colors.dart';
import '../../../api_calling/api_request.dart';
import '../../CommonCode.dart';
import '../../StringExtensions.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final ActivityModel activity;
  final String activityName;

  const ActivityDetailsScreen({super.key, required this.activity, required this.activityName});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  int currentIndex = 0;
  late List<VenueImageModel> images;
  Map<String, bool> expandedDays = {};
  String userMobileNumber = "";
  List<dynamic> placeOfferList = [];

  @override
  void initState() {
    super.initState();

    //  Convert activity images to model
    images = widget.activity.images
        .map((e) => VenueImageModel.fromJson(e))
        .toList();

    //  Cover image first
    images.sort((a, b) => b.coverPhoto ? 1 : -1);

    final today = getToday();

    // today expanded by default
    expandedDays[today] = true;

    fetchPlaceOfferData();
  }

  Future<void> fetchPlaceOfferData() async {
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


      // ✅ Dynamic UID
      //String uid = FirebaseAuth.instance.currentUser!.uid;

      var snapshot = await FirebaseFirestore.instance
          .collection("activ_user")
          .doc(realUid)
          .get();

      if (snapshot.exists) {
        var data = snapshot.data();

        var venueAmenities = data?['venue_amenities'];
        var list = (venueAmenities?['place_offer'] ?? []) as List<dynamic>;

        setState(() {
          placeOfferList = list;
          //isShimmerLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching place_offer: $e");
    }
  }


  String getToday() {
    final days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    return days[DateTime.now().weekday - 1];
  }

  bool isVenueOpenNow(List slots) {
    final now = TimeOfDay.now();

    bool isAfter(TimeOfDay a, TimeOfDay b) =>
        a.hour > b.hour || (a.hour == b.hour && a.minute >= b.minute);

    bool isBefore(TimeOfDay a, TimeOfDay b) =>
        a.hour < b.hour || (a.hour == b.hour && a.minute <= b.minute);

    for (var slot in slots) {
      final open = slot['open'];
      final close = slot['close'];

      TimeOfDay openTime = TimeOfDay(
        hour: int.parse(open.split(":")[0]),
        minute: int.parse(open.split(":")[1].split(" ")[0]),
      );

      TimeOfDay closeTime = TimeOfDay(
        hour: int.parse(close.split(":")[0]),
        minute: int.parse(close.split(":")[1].split(" ")[0]),
      );

      if (isAfter(now, openTime) && isBefore(now, closeTime)) {
        return true;
      }
    }
    return false;
  }

  bool hasValidTiming(List slots) {
    if (slots.isEmpty) return false;

    return slots.any((slot) {
      final open = slot['open'];
      final close = slot['close'];

      return open != null &&
          close != null &&
          open.toString().trim().isNotEmpty &&
          close.toString().trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
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
              top: false,
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
                            isMobile ? width * 1 : (isTablet ? 500 : 600);

                            return Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [

                                  /// IMAGE CAROUSEL
                                    Stack(
                                      children: [
                                        getCarouselSliderImages(context),
                                        getDotIndicator(),
                                        getToolTab(context),
                                      ],
                                    ),


                                  Expanded(
                                    child: Container(
                                        margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                                        child: ListView(
                                          padding: EdgeInsets.zero,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [

                                                buildVenueTiming(widget.activity.venueTiming),

                                                Container(
                                                  margin: const EdgeInsets.only(top: 0, bottom: 0),
                                                  child: const Divider(
                                                    color: AppColors.gray_border2, // color of the line
                                                    thickness: 1,       // thickness of the line
                                                    indent: 0,         // start padding
                                                    endIndent: 0,      // end padding
                                                  ),
                                                ),


                                                Visibility(
                                                  visible: (widget.activity.numberOfCourt!=null && widget.activity.numberOfCourt!="") ? true : false,
                                                  child: Container(
                                                      margin: const EdgeInsets.only(top: 10, bottom: 0),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        getDotIcon(),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              getLabel('Number of Courts'),
                                                              getLabelAnswer(widget.activity.numberOfCourt),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  ),
                                                ),

                                                Visibility(
                                                  visible: (widget.activity.flooringType!=null && widget.activity.flooringType!="") ? true : false,
                                                  child: Container(
                                                    margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        getDotIcon(),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              getLabel('Flooring Type'),
                                                              getLabelAnswer(widget.activity.flooringType),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  ),
                                                ),

                                                Visibility(
                                                  visible: (widget.activity.maximumCapacity!=null && widget.activity.maximumCapacity!="") ? true : false,
                                                  child: Container(
                                                      margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          getDotIcon(),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                getLabel('Maximum Capacity'),
                                                                getLabelAnswer(widget.activity.maximumCapacity),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                  ),
                                                ),

                                                Visibility(
                                                  visible: (widget.activity.description!=null && widget.activity.description!="") ? true : false,
                                                  child: Container(
                                                      margin: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          getDotIcon(),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                getLabel('Description'),
                                                                getLabelAnswer(widget.activity.description),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                  ),
                                                ),

                                                Visibility(
                                                  visible: (widget.activity.numberOfCourt == "" && widget.activity.flooringType == "" &&
                                                      widget.activity.maximumCapacity == "" && widget.activity.description == "") ? false : true,
                                                  child: Container(
                                                    margin: const EdgeInsets.only(top: 5, bottom: 0),
                                                    child: const Divider(
                                                      color: AppColors.gray_border2, // color of the line
                                                      thickness: 1,       // thickness of the line
                                                      indent: 0,         // start padding
                                                      endIndent: 0,      // end padding
                                                    ),
                                                  ),
                                                ),

                                                ///  OFFERS TITLE
                                                getOfferLabel(),

                                                /// OFFERS LIST (ONLY TITLE)
                                                /*Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: widget.activity.placeOffer.map<Widget>((e) {
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                                      child: Container(
                                                        margin: const EdgeInsets.only(left: 15, right: 15, bottom: 5),
                                                        child: getOfferValue(e['title'] ?? ''),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),*/

                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: placeOfferList.map((e) {
                                                      return Container(
                                                          margin: const EdgeInsets.only(left: 15, right: 15, bottom: 5),
                                                          child: getOfferValue(e['title'] ?? '')
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                      )
                    ],
                  )
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget getToolTab(BuildContext context)
  {
    return Container(
      //height: AppSize.toolTabSize,
      color: AppColors.transparent,
      margin: EdgeInsets.fromLTRB(0, 25, 0, 0),
      padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
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
                    padding: const EdgeInsets.fromLTRB(15,10,15,10),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: images.isNotEmpty ? AppColors.darkBlack.withValues(alpha: 0.8) : AppColors.darkBlack.withValues(alpha: 0), // shadow color
                          blurRadius: 18,                        // how blurry the shadow is
                          offset: const Offset(0, 3),          // x, y offset of shadow
                        ),
                      ],
                    ),
                    child: SvgPicture.asset('assets/ic_back.svg',color: images.isNotEmpty ? AppColors.white : AppColors.black,),
                  )
              ),
            ),
          ),

          getTitleText(context, widget.activityName, 'Activities_Details')

        ],
      ),
    );
  }

  /// 🔁 CAROUSEL
  Widget getCarouselSliderImages(BuildContext context) {
    return Visibility(
      visible: images.isNotEmpty ? true: false,
      child: CarouselSlider(
        options: CarouselOptions(
          height: MediaQuery.of(context).size.height * 0.30,
          viewportFraction: 1,
          autoPlay: true,
          enableInfiniteScroll: true,
          autoPlayInterval: const Duration(seconds: 3),
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
          onPageChanged: (index, reason) {
            setState(() => currentIndex = index);
          },
        ),
        items: images.map((img) {
          return InkWell(
            onTap: () {
              /*CommonUtilities.NavigateWithPush(context,
                VenueImageCarouselScreen(images: images),
              );*/
            },
            child: Stack(
              fit: StackFit.expand,
              children: [

                /// IMAGE
                Image.network(img.url, fit: BoxFit.cover),

                /// TOP GRADIENT
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                /// 🌟 COVER PHOTO TAG
                if (img.coverPhoto)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Cover Photo",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ⚪ DOT INDICATOR
  Widget getDotIndicator() {
    return Visibility(
      visible: images.isNotEmpty ? true: false,
      child: Positioned(
        bottom: 10,
        left: 0,
        right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentIndex == index ? 10 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: currentIndex == index
                    ? Colors.white
                    : Colors.white54,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget getOfferLabel()
  {
    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15, bottom: 5, top: 5),
      child: Text(
        "Offers:",
        style: const TextStyle(
          fontSize: AppSize.size_16,
          fontFamily: 'FontSemiBold',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Widget getOfferValue(String title) {
    return Container(
      child: Text(
        "• $title",
        style: const TextStyle(
          fontSize: AppSize.size_14,
          fontFamily: 'FontMedium',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }

  Widget buildVenueTiming1(Map<String, dynamic> venueTiming) {
    final days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(15, 10, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 5),
            child: const Text(
              "Venue Timing",
              style: const TextStyle(
                fontSize: AppSize.size_16,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
              ),
            ),
          ),

          ...days.map((day) {
            final slots = venueTiming[day];
      
            // No timing → CLOSED
            if (slots == null || !hasValidTiming(slots)) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(day),
                    const Text(
                      "Closed",
                      style: const TextStyle(
                        fontSize: AppSize.size_16,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkRed,
                      ),
                    ),
                  ],
                ),
              );
            }
      
            // ✅ Timing available
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: AppSize.size_14,
                      fontFamily: 'FontSemiBold',
                      color: AppColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
      
                  ...slots.map<Widget>((slot) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 0, bottom: 4, top: 4),
                      child: Text(
                        "${slot['open']} - ${slot['close']}",
                        style: const TextStyle(
                          fontSize: AppSize.size_14,
                          fontFamily: 'FontMedium',
                          color: AppColors.darkBlack,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget buildVenueTiming2(Map<String, dynamic> venueTiming) {
    final days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 10, 15, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TITLE
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "Venue Timing",
              style: TextStyle(
                fontSize: AppSize.size_16,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
              ),
            ),
          ),

          /// DAYS
          ...days.map((day) {
            final slots = venueTiming[day];

            /// 🔴 CLOSED DAY (NO EXPAND, NO ARROW)
            if (slots == null || slots.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white40,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const Text(
                      "Closed",
                      style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkRed,
                      ),
                    ),
                  ],
                ),
              );
            }

            /// 🟢 OPEN DAY (EXPANDABLE)
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: AppColors.white40,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gray_border2,
                  width: 1,
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  visualDensity: VisualDensity.compact,
                ),
                child: ExpansionTile(
                  tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  childrenPadding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  title: Text(
                    day,
                    style: const TextStyle(
                      fontSize: AppSize.size_14,
                      fontFamily: 'FontSemiBold',
                      color: AppColors.darkBlack,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20, // smaller icon
                    color: AppColors.darkBlack,
                  ),
                  children: slots.map<Widget>((slot) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          textAlign: TextAlign.start,
                          "${slot['open']} - ${slot['close']}",
                          style: const TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: 'FontMedium',
                            color: AppColors.darkBlack,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> getValidSlots(List slots) {
    return slots.where((slot) {
      final open = slot['open'];
      final close = slot['close'];

      return open != null &&
          close != null &&
          open.toString().trim().isNotEmpty &&
          close.toString().trim().isNotEmpty;
    }).cast<Map<String, dynamic>>().toList();
  }

  Widget buildVenueTiming(Map<String, dynamic> venueTiming) {

    final today = getToday();

    final days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TITLE
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "Venue Timing",
              style: TextStyle(
                fontSize: AppSize.size_16,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
              ),
            ),
          ),

          /// DAYS
          ...days.map((day) {
            //final slots = venueTiming[day];
            final slots = venueTiming[day];
            final validSlots = slots == null ? [] : getValidSlots(slots);
            final isToday = day == today;

            /// 🔴 CLOSED DAY
            if (validSlots.isEmpty) {

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white40,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontSemiBold',
                        color: isToday
                            ? AppColors.green
                            : AppColors.darkBlack,
                      ),
                    ),
                    const Text(
                      "Closed",
                      style: TextStyle(
                        fontSize: AppSize.size_14,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkRed,
                      ),
                    ),
                  ],
                ),
              );
            }

           // final openNow = isToday && isVenueOpenNow(slots);

            /// 🟢 OPEN DAY (EXPANDABLE)
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: AppColors.white40,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday
                      ? AppColors.green
                      : AppColors.gray_border2,
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  visualDensity: VisualDensity.compact,
                ),
                child: ExpansionTile(
                  initiallyExpanded: isToday, // auto expand today
                  onExpansionChanged: (expanded) {
                    setState(() {
                      expandedDays[day] = expanded;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: 'FontSemiBold',
                            color: isToday
                                ? AppColors.darkBlack
                                : AppColors.darkBlack,
                          ),
                        ),
                      ),

                      /// OPEN / CLOSED NOW
                     /* if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: openNow
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(0, 0, 0, 2),
                            child: Text(
                              openNow ? "OPEN NOW" : "CLOSED NOW",
                              style: TextStyle(
                                fontSize: AppSize.size_11,
                                fontFamily: 'FontSemiBold',
                                color:
                                openNow ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),*/
                    ],
                  ),

                  /// 🔄 Arrow rotate animation
                  trailing: AnimatedRotation(
                    turns: expandedDays[day] == true ? 0.5 : 0.0, //  up / down
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ),


                  children: slots.map<Widget>((slot) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          (slot['open']=="-" && slot['close']=="-") ? "Closed" : "${slot['open']} - ${slot['close']}",
                          style: TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: (slot['open'] =="-"&& slot['close']=="-") ? 'FontSemiBold' : 'FontMedium',
                            color: (slot['open'] =="-"&& slot['close']=="-") ? AppColors.red : AppColors.darkBlack,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget getDotIcon() {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(15, 0, 0, 0),
          child: Text(
          "• ",
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget getLabel(String label) {
    return Row(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(5, 0, 15, 0),
          child: Text(
            label,
            style: TextStyle(
                fontSize: AppSize.size_14,
                fontFamily: 'FontSemiBold',
                color: AppColors.darkBlack,
                height: 1
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget getLabelAnswer(String answer) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: EdgeInsets.fromLTRB(5, 10, 15, 0),
      child: Text(
        answer,
        style: TextStyle(
            fontSize: AppSize.size_14,
            fontFamily: 'FontMedium',
            color: AppColors.darkBlack,
            height: 1.4
        ),
        maxLines: null,          // Allow unlimited lines
        softWrap: true,          // Wrap text if too long
        textAlign: TextAlign.left,
      ),
    );
  }
}
