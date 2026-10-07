import 'dart:convert';

import 'package:activ_app/Database/auth_service.dart';
import 'package:activ_app/Screens/CommonCode.dart';
import 'package:activ_app/Screens/Home/Activities/VenueActivityListScreen.dart';
import 'package:activ_app/Screens/StringExtensions.dart';
import 'package:activ_app/Style/constants_messages.dart';
import 'package:activ_app/Utills/common_utilities.dart';
import 'package:activ_app/api_calling/progress_bar/progress_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../Style/app_colors.dart';
import '../../../../Style/app_size.dart';
import '../../../../api_calling/api_request.dart';


class DayTiming {
  List<Map<String, String>> timeSlots;
  DayTiming({required this.timeSlots});
}

class AddVenueTimingScreen extends StatefulWidget {

  final String activityId;
  const AddVenueTimingScreen({super.key, required this.activityId});

  @override
  State<AddVenueTimingScreen> createState() => _State();

 /* @override
  _VenueTimingScreenState createState() => _VenueTimingScreenState();*/
}

class _State extends State<AddVenueTimingScreen> {
  String? userMobileNumber = "";
  List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  // Map short day to full day
  final Map<String, String> dayMap = {
    "Mon": "Monday",
    "Tue": "Tuesday",
    "Wed": "Wednesday",
    "Thu": "Thursday",
    "Fri": "Friday",
    "Sat": "Saturday",
    "Sun": "Sunday",
  };

  // Use For Create Json for Send Database
  final Map<String, String> apiDayKey = {
    "Mon": "Monday",
    "Tue": "Tuesday",
    "Wed": "Wednesday",
    "Thu": "Thursday",
    "Fri": "Friday",
    "Sat": "Saturday",
    "Sun": "Sunday",
  };


  List<String> selectedDays = [];
  Map<String, DayTiming> timings = {};

  /// Time Picker
  Future<String?> _pickTime(BuildContext context, String? initial) async {
    TimeOfDay? picked = await showTimePicker(
      //context: context,
      //initialTime: TimeOfDay.now(),
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.green,
              onPrimary: AppColors.white,
              onSurface: AppColors.black1,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.green,
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: false,
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      return DateFormat("hh:mm a").format(dt);
    }
    return initial;
  }

  void toggleDay(String day, bool isSelected) {
    if (isSelected) {
      if (!selectedDays.contains(day)) {
        selectedDays.add(day);
       /* timings.putIfAbsent(
          day,
              () => DayTiming(timeSlots: [
            {"open": "09:00 AM", "close": "07:00 PM"}
          ]),
        );*/

        timings.putIfAbsent(
          day,
              () => DayTiming(timeSlots: []),
        );
      }
    } else {
      selectedDays.remove(day);
      timings.remove(day);
    }

    // Always correct order sort
    selectedDays.sort((a, b) => days.indexOf(a).compareTo(days.indexOf(b)));

    setState(() {});
  }

  /// Validation Function
  bool _validateTimings() {
    for (var day in selectedDays) {
      var slots = timings[day]!.timeSlots;
      for (var slot in slots) {
        String? open = slot["open"];
        String? close = slot["close"];

        if (open == null || close == null || open.isEmpty || close.isEmpty) {
          _showError("Please select Open and Close time for $day");
          return false;
        }

        DateTime openTime = DateFormat("hh:mm a").parse(open);
        DateTime closeTime = DateFormat("hh:mm a").parse(close);

        if (openTime.isAfter(closeTime) || openTime.isAtSameMomentAs(closeTime)) {
          _showError("In $day, Opening time must be earlier than closing time.");
          return false;
        }
      }
    }
    return true;
  }

  void _showError(String msg) {
    /*ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );*/

    CommonUtilities.createSnackBar(context, msg);
  }

  void goToBackScreen(BuildContext context)
  {
    Navigator.pop(context);
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
          top: true,
          bottom: true,
          left: false,
          right: false,
          child: Scaffold(
            body: Container(
              decoration: context.getYellowGradient,
              child: Column(
                children: [

                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: ListView(
                        shrinkWrap: true,
                        children: [

                          getActivIcon(),

                          getText(),

                          getSubText(),

                          Container(
                            margin: const EdgeInsets.only(top: 10, left: 15, right: 15, bottom: 10),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              "Mark Operating Days",
                              style: TextStyle(
                                  fontSize: AppSize.size_16,
                                  fontFamily: 'FontSemiBold',
                                  color: AppColors.black1,
                                  height: 1.2
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),

                          // Days selection
                          Wrap(
                            spacing: 4,
                            runSpacing: 15,
                            children: days.map((day) {
                              bool isSelected = selectedDays.contains(day);
                              return GestureDetector(
                                onTap: () {
                                  toggleDay(day, !isSelected);
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
                                  width: 70,
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                      colors: [AppColors.borderGradient1, AppColors.borderGradient2],
                                    )
                                        : null,
                                    color: isSelected ? null : AppColors.gray,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                      color: AppColors.gray,
                                      width: 1,
                                    ),
                                  ),
                                  child: Container(
                                    margin: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
                                    padding: const EdgeInsets.symmetric(vertical: 8), //
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.gray3 : AppColors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontSize: AppSize.size_14,
                                        fontFamily: 'FontMedium',
                                        color: AppColors.darkBlack,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),

                          // Copy To All Text and Click Event
                          /*if (selectedDays.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: Icon(Icons.copy, color: Colors.green),
                        label: Text("Copy to all",
                          style: TextStyle(
                            fontSize: AppSize.size_14,
                            fontFamily: 'FontMedium',
                            color: AppColors.purple,
                          ),),
                        onPressed: () {
                          if (selectedDays.isNotEmpty) {
                            String firstDay = selectedDays.first;
                            DayTiming firstDayTiming = timings[firstDay]!;

                            // ✅ Deep copy of slots
                            for (var day in selectedDays) {
                              timings[day] = DayTiming(
                                timeSlots: firstDayTiming.timeSlots
                                    .map((slot) => {
                                  "open": slot["open"]!,
                                  "close": slot["close"]!,
                                })
                                    .toList(),
                              );
                            }

                            setState(() {});
                          }
                        },
                      ),
                    ),*/

                          Container(
                            margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Day Wise Timings",
                              style: TextStyle(
                                fontSize: AppSize.size_16,
                                fontFamily: 'FontBold',
                                color: AppColors.black1,
                              ),
                            ),
                          ),

                           Visibility(
                             visible: selectedDays.length > 0 ? false : true,
                             child: Container(
                              margin: const EdgeInsets.fromLTRB(15, 5, 15, 0),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Select the operating days above to start adding time slots",
                                style: TextStyle(
                                  fontSize: AppSize.size_14,
                                  fontFamily: 'FontRegular',
                                  color: AppColors.black1,
                                ),
                              ),
                             ),
                           ),

                          Column(
                            children: selectedDays.asMap().entries.map((entry) {
                              int index = entry.key;
                              String day = entry.value;

                              CommonUtilities.showLog("Select_Day : " + day.toString());

                              return Card(
                                color: AppColors.transparent,
                                margin: const EdgeInsets.symmetric(vertical: 0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0)
                                ),
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(0),
                                  child: Container(
                                    margin: selectedDays.length > 1 ? EdgeInsets.fromLTRB(15, 10, 15, 0) : EdgeInsets.fromLTRB(15, 10, 15, 10),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Day Name
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Show Day Name Text
                                              Container(
                                                child: Text("${dayMap[day]}",
                                                  style: TextStyle(
                                                    fontSize: AppSize.size_14,
                                                    fontFamily: 'FontBold',
                                                    color: AppColors.darkBlack,
                                                  ),
                                                ),
                                              ),

                                              // Copy To All Text
                                              InkWell(
                                                onTap: hasAnyTimingSelected()
                                                    ? () {
                                                  if (selectedDays.isNotEmpty) {
                                                    String firstDay = selectedDays.first;
                                                    DayTiming firstDayTiming = timings[firstDay]!;

                                                    // ✅ Deep copy of slots
                                                    for (var day in selectedDays) {
                                                      timings[day] = DayTiming(
                                                        timeSlots: firstDayTiming.timeSlots
                                                            .map((slot) => {
                                                          "open": slot["open"]!,
                                                          "close": slot["close"]!,
                                                        })
                                                            .toList(),
                                                      );
                                                    }

                                                    setState(() {});
                                                  }
                                                }
                                                    : null,
                                                child: Visibility(
                                                  visible: (day == selectedDays.first), // 👈 pehle wale day par hi dikhana
                                                  child: Container(
                                                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 20,
                                                          height: 20,
                                                          child: Image.asset(
                                                            'assets/ic_copy.png',
                                                            color: hasAnyTimingSelected()
                                                                ? AppColors.purple
                                                                : AppColors.lightGray,
                                                          ),
                                                        ),
                                                        Container(
                                                          margin: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                                                          child: Text(
                                                            "Copy to all",
                                                            style: TextStyle(
                                                              fontSize: AppSize.size_14,
                                                              fontFamily: 'FontMedium',
                                                              color: hasAnyTimingSelected()
                                                                  ? AppColors.purple
                                                                  : AppColors.lightGray,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          Column(
                                            children: List.generate(
                                              timings[day]!.timeSlots.length,
                                                  (index) {
                                                var slot = timings[day]!.timeSlots[index];
                                                return Row(
                                                  //crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // -------- Open Time ----------
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          RichText(
                                                            text: TextSpan(
                                                              children: [
                                                                TextSpan(
                                                                  text: "Open Time",
                                                                  style: const TextStyle(
                                                                    fontSize: AppSize.size_14,
                                                                    fontFamily: 'FontMedium',
                                                                    color: AppColors.darkBlack,
                                                                  ),
                                                                ),
                                                                TextSpan(
                                                                  text: "*",
                                                                  style: const TextStyle(
                                                                    fontSize: AppSize.size_14,
                                                                    fontFamily: 'FontMedium',
                                                                    color: AppColors.red,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          GestureDetector(
                                                            onTap: () async {
                                                              String? picked =
                                                              await _pickTime(context, slot["open"]);
                                                              if (picked != null) {
                                                                setState(() {
                                                                  timings[day]!.timeSlots[index]["open"] =
                                                                      picked;
                                                                });
                                                              }
                                                            },
                                                            child: Container(
                                                              margin: const EdgeInsets.only(bottom: 8),
                                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.white,
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(
                                                                  color: AppColors.gray,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    slot["open"]!,
                                                                    style: const TextStyle(
                                                                      fontSize: AppSize.size_14,
                                                                      fontFamily: 'FontRegular',
                                                                      color: AppColors.darkBlack,
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: Image.asset(
                                                                      'assets/ic_drop_down.png',
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    const SizedBox(width: 8),

                                                    // -------- Close Time ----------
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          RichText(
                                                            text: TextSpan(
                                                              children: [
                                                                TextSpan(
                                                                  text: "Close Time",
                                                                  style: const TextStyle(
                                                                    fontSize: AppSize.size_14,
                                                                    fontFamily: 'FontMedium',
                                                                    color: AppColors.darkBlack,
                                                                  ),
                                                                ),
                                                                TextSpan(
                                                                  text: "*",
                                                                  style: const TextStyle(
                                                                    fontSize: AppSize.size_14,
                                                                    fontFamily: 'FontMedium',
                                                                    color: AppColors.red,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          const SizedBox(height: 6),
                                                          GestureDetector(
                                                            onTap: () async {
                                                              String? picked =
                                                              await _pickTime(context, slot["close"]);
                                                              if (picked != null) {
                                                                setState(() {
                                                                  timings[day]!.timeSlots[index]["close"] =
                                                                      picked;
                                                                });
                                                              }
                                                            },
                                                            child: Container(
                                                              margin: const EdgeInsets.only(bottom: 8),
                                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.white,
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(
                                                                  color: AppColors.gray,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    slot["close"]!,
                                                                    style: const TextStyle(
                                                                      fontSize: AppSize.size_14,
                                                                      fontFamily: 'FontRegular',
                                                                      color: AppColors.darkBlack,
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: Image.asset(
                                                                      'assets/ic_drop_down.png',
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    const SizedBox(width: 8),

                                                    // -------- Delete Icon ----------
                                                    InkWell(
                                                        onTap: () {

                                                          customAlertDialog(context, day, index, "Are you sure you want to delete this time slot?");

                                                        },
                                                        child: Align(
                                                          alignment: Alignment.centerRight,
                                                          child: Container(
                                                            margin: const EdgeInsets.only(top: 10),
                                                            alignment: Alignment.centerRight,
                                                            width: 24,
                                                            height: 24,
                                                            child: Image.asset('assets/ic_delete.png'),
                                                          ),
                                                        )
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),

                                          // Add Slot Time Click Event.
                                          InkWell(
                                            onTap: ()
                                            {
                                              setState(() {
                                                timings[day]!.timeSlots.add({
                                                  "open": "09:00 AM",
                                                  "close": "07:00 PM"
                                                });
                                              });
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  child: Image.asset('assets/ic_plus.png'),
                                                ),
                                                Container(
                                                  margin: const EdgeInsets.fromLTRB(10, 2, 0, 0),
                                                  child: Text(
                                                    "Add time slot",
                                                    style: TextStyle(
                                                      fontSize: AppSize.size_14,
                                                      fontFamily: 'FontMedium',
                                                      color: AppColors.purple,
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),

                                          // Divider line only if NOT last item
                                          if (index != selectedDays.length - 1)
                                            getDividerLine(selectedDays.length.toString()),
                                        ]),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                        ],
                      ),
                    ),
                  ),

                  // Bottom Button
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
                                    child: getBackButton(context, "Back", "venueAvailability"))
                            ),


                            Expanded(
                              flex: 7,
                              child: InkWell(
                                  onTap: ()
                                  async {
                                    if(hasAnyTimingSelected())
                                    {
                                      if (_validateTimings()) {
                                       /* Map<String, dynamic> finalData = {
                                          "venue_timing": buildVenueTiming(),
                                        };
                                        print("FINAL VENUE TIMING => ${jsonEncode(finalData)}");*/

                                        Map<String, dynamic> venueTimingMap = buildVenueTiming();

                                        CommonUtilities.showLog("FINAL VENUE TIMING => ${jsonEncode({
                                          "venue_timing": venueTimingMap
                                        })}");

                                        ProgressBar().showLoader(context);

                                        try {
                                          userMobileNumber = await SharedPreference.readStr("userMobileNumber");
                                          await saveVenueTimingToFirestore(
                                            widget.activityId,
                                            venueTimingMap,
                                            'IND (+91)' + userMobileNumber!,
                                          );
                                          CommonUtilities.createSnackBar(context, "Activity added successfully.");
                                          CommonUtilities.addActivitySuccessfully = "yes";
                                          CommonUtilities.NavigateWithPushAndKillAllPriviousScreens(context, VenueActivityListScreen());

                                        } catch (e) {
                                          Navigator.pop(context);
                                          CommonUtilities.showLog("❌ Venue timing error: $e");
                                        }
                                      }
                                    }
                                    else
                                    {
                                      CommonUtilities.createSnackBar(context, ConstantsMessages.selectDayTimeslot);
                                    }

                                  },
                                  child: hasAnyTimingSelected() ? getButtonBlack(context, "Submit", "venueAvailability") :
                                  getButtonGray(context, "Submit", "venueAvailability")
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
          ),
        ),
      ),
    );
  }

  //--------------------------------------------Start Venue Timing Upload----------------------------------------------------------------

  /*Future<void> ensureAnonymousLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    print("✅ Firebase UID: ${FirebaseAuth.instance.currentUser!.uid}");
  }*/

  /*Future<void> saveVenueTimingToFirestore(
      Map<String, dynamic> venueTiming,
      ) async {

   // await AuthService().ensureAnonymousLogin();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection("activ_user")
        .doc(uid)
        .set({
      "venue_timing": venueTiming, // ALAG FIELD
    }, SetOptions(merge: true));

    CommonUtilities.showLog("✅ venue_timing saved");
  }*/

  Future<void> saveVenueTimingToFirestore(
      String activityId,
      Map<String, dynamic> venueTiming,
      String phoneKey, // 📞 phone number key
      ) async {
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

      // 2️⃣ Reference the actual user document by UID
      final docRef =
      FirebaseFirestore.instance.collection("activ_user").doc(realUid);

      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        throw Exception("❌ User document not found for UID: $realUid");
      }

      // 3️⃣ Get activities list
      List activities = List.from(snapshot.data()?["activity_list"] ?? []);

      // 🔎 Find activity by ID
      final index = activities.indexWhere((a) => a["activity_id"] == activityId);

      if (index == -1) {
        CommonUtilities.showLog("❌ Activity not found for ID: $activityId");
        return;
      }

      // ✅ Merge venue timing inside that activity
      activities[index]["venue_timing"] = venueTiming;
      activities[index]["updated_at"] = Timestamp.now();

      // 🔄 Save back full array
      await docRef.set(
        {
          "activity_list": activities,
        },
        SetOptions(merge: true),
      );

      CommonUtilities.showLog(
          "✅ venue_timing added inside activity for phone: $phoneKey");
    } catch (e) {
      CommonUtilities.showLog("❌ Error saving venue timing: $e");
    }
  }


  //--------------------------------------------End Venue Timing Upload----------------------------------------------------------------

  Map<String, List<Map<String, String>>> buildVenueTiming() {
    Map<String, List<Map<String, String>>> venueTiming = {};

    for (String day in days) {
      String apiKey = apiDayKey[day]!;

      if (selectedDays.contains(day) &&
          timings.containsKey(day) &&
          timings[day]!.timeSlots.isNotEmpty) {

        venueTiming[apiKey] = timings[day]!.timeSlots.map((slot) {
          return {
            "open": slot["open"] ?? "-",
            "close": slot["close"] ?? "-"
          };
        }).toList();

      } else {
        // ❌ day not select
        venueTiming[apiKey] = [
          {"open": "-", "close": "-"}
        ];
      }
    }

    return venueTiming;
  }


  Widget getActivIcon()
  {
    return Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 0, 0),
        child: Image.asset('assets/logo.png', width: 105, height: 60, fit: BoxFit.contain)
    );
  }

  Widget getText()
  {
    return Container(
      margin: const EdgeInsets.only(top: 5, left: 15, right: 15, bottom: 0),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Set the venue’s availability",
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
      margin: EdgeInsets.fromLTRB(15, 10, 15, 10),
      child: const Text(
        "Tell us when the members can reserve your venue",
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

  bool hasAnyTimingSelected() {
    for (var entry in timings.entries) {
      if (entry.value.timeSlots.isNotEmpty) {
        return true; // at least one slot found
      }
    }
    return false;
  }

  Widget getDividerLine(String length)
  {
    return Container(
      margin: int.parse(length) > 1 ? const EdgeInsets.fromLTRB(0, 15, 0, 0) : const EdgeInsets.fromLTRB(0, 0, 0, 0),
      color: AppColors.gray,
      height: 1,
    );
  }

  customAlertDialog(BuildContext context,String day, int index, String description)
  {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 20),
              margin: const EdgeInsets.only(
                  top: 45,left: 40,right: 40
              ),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),

              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[

                  Text(
                      '⚠ Alert!',
                    style: TextStyle(
                        fontSize: AppSize.size_16,
                        fontFamily: 'FontSemiBold',
                        color: AppColors.darkBlack,
                        textBaseline: null),),

                  const SizedBox(height: 15,),

                  Container(
                    margin: EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: Text(description,
                      style: TextStyle(
                          fontSize: AppSize.size_14,
                          fontFamily: 'FontSemiBold',
                          color: AppColors.darkBlack,
                          height: 1.5), textAlign: TextAlign.center,),
                  ),

                  const SizedBox(height: 15,),

                  // Divider Line
                  Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: Divider(
                        color: AppColors.gray1,
                        height: 1,
                      )
                  ),

                  const SizedBox(height: 0,),

                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: ()
                            {
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(30, 13, 30, 13),
                              alignment: Alignment.center,
                              child: Text(
                                'No',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppSize.size_14,
                                  fontFamily: 'FontSemiBold',
                                  color: AppColors.darkBlack,),
                              ),
                            ),
                          ),
                        ),

                        VerticalDivider(
                          color: AppColors.gray1,
                          thickness: .5,
                        ),

                        Expanded(
                          child: InkWell(
                            onTap: ()
                            {
                              Navigator.pop(context);

                              setState(() {
                                if (timings.containsKey(day) &&
                                    timings[day]!.timeSlots.length > index) {
                                  timings[day]!.timeSlots.removeAt(index);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(30, 13, 30, 13),
                              alignment: Alignment.center,
                              child: Text(
                                'Yes',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppSize.size_14,
                                  fontFamily: 'FontSemiBold',
                                  color: AppColors.darkBlack,),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 0,),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
