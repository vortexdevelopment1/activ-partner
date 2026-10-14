import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../Database/auth_service.dart';
import '../../Style/app_size.dart';
import '../../Utills/common_utilities.dart';
import '../../api_calling/api_request.dart';
import '../CommonCode.dart';

class VenueTimingListScreen extends StatefulWidget {
  const VenueTimingListScreen({super.key});

  @override
  State<VenueTimingListScreen> createState() => _State();
}

class _State extends State<VenueTimingListScreen> with SingleTickerProviderStateMixin {
  AuthService authService = AuthService();
  String phoneCode = "IND (+91)";
  String userMobileNumber = "";

  Map<String, dynamic> venueTimingMap = {};
  bool isLoading = true;

  late final String todayName;

  final Map<String, ExpansionTileController> _controllers = {};
  final Map<String, bool> _expandedState = {};

  final List<String> weekOrder = const [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  getData() async
  {
    phoneCode = checkString(await SharedPreference.readStr("phoneCode"));
    userMobileNumber = checkString(await SharedPreference.readStr("userMobileNumber"));
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    todayName = weekOrder[DateTime.now().weekday - 1]; //  MON-SUN
    loadVenueTiming();
  }

  Future<void> loadVenueTiming() async {
    venueTimingMap = await getVenueTiming();
    setState(() {
      isLoading = false;
    });
  }

  Future<Map<String, dynamic>> getVenueTiming() async {
    await AuthService().ensureAnonymousLogin();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .get();

    if (doc.exists && doc.data()!.containsKey("venue_timing")) {
      return Map<String, dynamic>.from(doc["venue_timing"]);
    }

    return {};
  }


  @override
  void dispose() {
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
                        isMobile ? width * 1 : (isTablet ? 500 : 600);

                        return Container(
                          child: Container(
                            margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [

                                getToolTab(context),

                                Expanded(
                                  child: Container(
                                    margin: EdgeInsets.fromLTRB(15, 0, 15, 10),
                                    child: buildTimingList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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

          getTitleText(context, 'Venue Timings', 'Venue_Timing_List')

        ],
      ),
    );
  }

  Widget buildTimingList1() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (venueTimingMap.isEmpty) {
      return const Center(child: Text("No timing available"));
    }

    return ListView.builder(
      itemCount: venueTimingMap.keys.length,
      itemBuilder: (context, index) {
        final day = venueTimingMap.keys.elementAt(index);
        final List slots = venueTimingMap[day];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // DAY NAME
                Text(
                  day,
                  style: TextStyle(
                    fontSize:  CommonUtilities.increaseSizeBy2(AppSize.size_16),
                    fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
                    color: AppColors.darkBlack,
                  ),
                ),

                const SizedBox(height: 8),

                // 🟡 TIME SLOTS
                ...slots.map((slot) {
                  final open = slot["open"];
                  final close = slot["close"];

                  if (open == "-" || close == "-") {
                    return Text(
                      "Closed",
                      style: TextStyle(
                        fontSize:  CommonUtilities.increaseSizeBy2(AppSize.size_14),
                        fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                        color: AppColors.darkRed,
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "$open - $close",
                      style: TextStyle(
                        fontSize:  CommonUtilities.increaseSizeBy2(AppSize.size_14),
                        fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                        color: AppColors.darkBlack,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTimingList2() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (venueTimingMap.isEmpty) {
      return const Center(child: Text("No timing available"));
    }

    return ListView.builder(
      itemCount: venueTimingMap.keys.length,
      itemBuilder: (context, index) {
        final day = venueTimingMap.keys.elementAt(index);
        final List slots = venueTimingMap[day];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔴 DAY NAME + CLOCK ICON
                Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 3),
                      child: const Icon(
                        Icons.access_time,
                        size: 18,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
                        fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔴 OPEN / CLOSE HEADER
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "OPEN TIME",
                        style: TextStyle(
                          fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                          fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                          color: AppColors.darkGray,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "CLOSE TIME",
                        style: TextStyle(
                          fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                          fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                          color: AppColors.darkGray,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 🔴 TIME SLOTS
                ...List.generate(slots.length, (slotIndex) {
                  final slot = slots[slotIndex];
                  final open = slot["open"];
                  final close = slot["close"];

                  // ❌ CLOSED CASE
                  if (open == "-" || close == "-") {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Closed",
                        style: TextStyle(
                          fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                          fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                          color: AppColors.darkRed,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                open,
                                style: TextStyle(
                                  fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                                  fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                                  color: AppColors.darkBlack,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                close,
                                style: TextStyle(
                                  fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                                  fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                                  color: AppColors.darkBlack,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🔹 SLOT DIVIDER (except last)
                      if (slotIndex != slots.length - 1)
                        Divider(
                          color: AppColors.lightGray.withOpacity(0.4),
                          thickness: 1,
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTimingList3() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (venueTimingMap.isEmpty) {
      return const Center(child: Text("No timing available"));
    }

    return ListView.builder(
      itemCount: venueTimingMap.keys.length,
      itemBuilder: (context, index) {
        final day = venueTimingMap.keys.elementAt(index);
        final List slots = venueTimingMap[day];

        //  CHECK: is whole day closed?
        bool isDayClosed = slots.every(
              (slot) => slot["open"] == "-" || slot["close"] == "-",
        );

        return Container(
          decoration: context.showDecoration,
          margin: EdgeInsets.only(bottom: 10, top: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ⏰ DAY NAME + ICON
                Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 3),
                        child: const Icon(Icons.access_time, size: 18, color: AppColors.darkGray)
                    ),
                    const SizedBox(width: 6),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
                        fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ❌ CLOSED DAY → SIMPLE TEXT ONLY
                if (isDayClosed)
                  Text(
                    "Closed",
                    style: TextStyle(
                      fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                      fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                      color: AppColors.darkRed,
                    ),
                  )

                // ✅ OPEN DAY → SHOW OPEN / CLOSE + SLOTS
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "OPEN",
                          style: TextStyle(
                            fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                            color: AppColors.darkGray,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "CLOSE",
                          style: TextStyle(
                            fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                            color: AppColors.darkGray,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  ...List.generate(slots.length, (slotIndex) {
                    final slot = slots[slotIndex];

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(slot["open"])),
                              Expanded(child: Text(slot["close"])),
                            ],
                          ),
                        ),

                        // 🔹 DIVIDER
                        if (slotIndex != slots.length - 1)
                          Divider(
                            color: AppColors.lightGray.withOpacity(0.4),
                            thickness: 1,
                          ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTimingList11() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (venueTimingMap.isEmpty) {
      return const Center(child: Text("No timing available"));
    }

    //  SORT DAYS ACCORDING TO WEEK ORDER
    final List<String> sortedDays = venueTimingMap.keys
        .where((day) => weekOrder.contains(day))
        .toList()
      ..sort(
            (a, b) => weekOrder.indexOf(a).compareTo(
          weekOrder.indexOf(b),
        ),
      );

    return ListView.builder(
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index]; // ✅ USE SORTED DAY
        final List slots = venueTimingMap[day];

        //  CHECK: is whole day closed?
        bool isDayClosed = slots.every(
              (slot) => slot["open"] == "-" || slot["close"] == "-",
        );

        return Container(
          decoration: context.showDecoration,
          margin: const EdgeInsets.only(bottom: 10, top: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ⏰ DAY NAME + ICON
                Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 3),
                      child: const Icon(
                        Icons.access_time,
                        size: 18,
                        color: AppColors.darkBlack,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
                        fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
                        color: AppColors.darkBlack,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ❌ CLOSED DAY
                if (isDayClosed)
                  Text(
                    "Closed",
                    style: TextStyle(
                      fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                      fontFamily: CommonUtilities.fontTypeAccordingToLang('FontMedium'),
                      color: AppColors.darkRed,
                    ),
                  )
                else ...[
                  // OPEN / CLOSE HEADER
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "OPEN",
                          style: TextStyle(
                            fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                            color: AppColors.darkGray,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "CLOSE",
                          style: TextStyle(
                            fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                            color: AppColors.darkGray,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // TIME SLOTS
                  ...List.generate(slots.length, (slotIndex) {
                    final slot = slots[slotIndex];

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(slot["open"])),
                              Expanded(child: Text(slot["close"])),
                            ],
                          ),
                        ),

                        // 🔹 DIVIDER BETWEEN SLOTS
                        if (slotIndex != slots.length - 1)
                          Divider(
                            color: AppColors.lightGray.withOpacity(0.4),
                            thickness: 1,
                          ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTimingList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (venueTimingMap.isEmpty) {
      return const Center(child: Text("No timing available"));
    }

    final List<String> sortedDays = venueTimingMap.keys
        .where((day) => weekOrder.contains(day))
        .toList()
      ..sort(
            (a, b) => weekOrder.indexOf(a).compareTo(
          weekOrder.indexOf(b),
        ),
      );

    return ListView.builder(
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final List slots = venueTimingMap[day];

        bool isDayClosed = slots.every(
              (slot) => slot["open"] == "-" || slot["close"] == "-",
        );

        // ❌ CLOSED DAY (NO DROPDOWN)
        if (isDayClosed) {
          return Container(
            decoration: context.showDecoration,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: AppColors.darkBlack),
                    const SizedBox(width: 8),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
                        fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
                      ),
                    ),
                  ],
                ),
                Text(
                  "Closed",
                  style: TextStyle(
                    fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_14),
                    color: AppColors.darkRed,
                  ),
                ),
              ],
            ),
          );
        }

        // ✅ OPEN DAY (DROPDOWN)
        return Container(
          decoration: context.showDecoration,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              trailing: const Icon(Icons.keyboard_arrow_down),
              title: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: AppColors.darkBlack),
                  const SizedBox(width: 8),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
                      fontFamily: CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
                    ),
                  ),
                ],
              ),
              children: [
                // OPEN / CLOSE HEADER
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        "OPEN",
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "CLOSE",
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                ...List.generate(slots.length, (slotIndex) {
                  final slot = slots[slotIndex];

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(slot["open"])),
                            Expanded(child: Text(slot["close"])),
                          ],
                        ),
                      ),
                      if (slotIndex != slots.length - 1)
                        Divider(
                          color: AppColors.lightGray.withOpacity(0.4),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _materialCard({required Widget child}) {
    return Card(
      elevation: 1,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: child,
      ),
    );
  }

  Widget _dayTitle(String day) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 18, color: AppColors.darkBlack),
        const SizedBox(width: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: CommonUtilities.increaseSizeBy2(AppSize.size_16),
            fontFamily:
            CommonUtilities.fontTypeAccordingToLang('FontSemiBold'),
            color: AppColors.darkBlack,
          ),
        ),
      ],
    );
  }

  Widget buildTimingListExp() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (venueTimingMap.isEmpty) {
      return const Center(child: Text("No timing available"));
    }

    final List<String> sortedDays = venueTimingMap.keys
        .where((day) => weekOrder.contains(day))
        .toList()
      ..sort(
            (a, b) => weekOrder.indexOf(a).compareTo(
          weekOrder.indexOf(b),
        ),
      );

    return ListView.builder(
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final List slots = venueTimingMap[day];

        final bool isDayClosed = slots.every(
              (slot) => slot["open"] == "-" || slot["close"] == "-",
        );

        _controllers.putIfAbsent(day, () => ExpansionTileController());
        _expandedState.putIfAbsent(
          day,
              () => day == todayName && !isDayClosed,
        );

        // Auto expand today
        if (_expandedState[day]! &&
            !_controllers[day]!.isExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _controllers[day]!.expand();
          });
        }

        // ❌ CLOSED DAY (NO DROPDOWN)
        if (isDayClosed) {
          return _materialCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dayTitle(day),
                Text(
                  "Closed",
                  style: TextStyle(
                    fontSize:
                    CommonUtilities.increaseSizeBy2(AppSize.size_14),
                    color: AppColors.darkRed,
                  ),
                ),
              ],
            ),
          );
        }

        // ✅ OPEN DAY (DROPDOWN)
        return _materialCard(
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.white,
              splashColor: Colors.white,
            ),
            child: ExpansionTile(
              controller: _controllers[day],
              visualDensity: VisualDensity.compact, // MOST IMPORTANT
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(
                top: 6, // 🔽 kam
                bottom: 4,
              ),

              onExpansionChanged: (val) {
                setState(() => _expandedState[day] = val);
              },
              dense: true, //  extra compact
              title: _dayTitle(day),

              trailing: AnimatedRotation(
                turns: _expandedState[day]! ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: const Icon(Icons.keyboard_arrow_down),
              ),

              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        "OPEN",
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "CLOSE",
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                ...List.generate(slots.length, (i) {
                  final slot = slots[i];
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(slot["open"])),
                          Expanded(child: Text(slot["close"])),
                        ],
                      ),
                      if (i != slots.length - 1)
                        Divider(
                          height: 16,
                          color:
                          AppColors.lightGray.withOpacity(0.4),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }


}
