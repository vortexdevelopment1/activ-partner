import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Screens/Home/Activities/AddActivities/AddActivityAmenitiesScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddActivityConfigureScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddActivitySubmitReviewScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddListActivityTypeScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddSelectedVenueFormScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddVenuePhotoListViewScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddVenuePhotoUploadScreen.dart';
import '../Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart';
import 'activity_flow_checkpoint.dart';
import 'activity_image_draft_store.dart';

/// Reopens an interrupted add-activity flow without using transient Futures.
class ActivityResumeNavigator {
  static Future<void> open(
    BuildContext context,
    ActivityFlowCheckpoint checkpoint,
    http.Client? client,
  ) async {
    final id = checkpoint.activityId;
    final pages = <Widget>[
      AddListActivityTypeScreen(client: client),
      AddVenuePhotoUploadScreen(client: client),
      AddVenuePhotoListViewScreen(
        activityId: id,
        images: await ActivityImageDraftStore.read(id),
        client: client,
      ),
      AddSelectedVenueFormScreen(activityId: id, client: client),
      AddActivityAmenitiesScreen(activityId: id, client: client),
      AddVenueTimingScreen(activityId: id, client: client),
      AddActivityConfigureScreen(
          activityId: id,
          activityName: checkpoint.data['activityName']?.toString() ?? 'Activity',
          timing: Map<String, dynamic>.from(
            checkpoint.data['timing'] as Map? ?? const {},
          ),
          client: client,
        ),
      AddActivitySubmitReviewScreen(
          activityId: id,
          activityName: checkpoint.data['activityName']?.toString() ?? 'Activity',
          timing: _timing(checkpoint.data['timing']),
          client: client,
        ),
    ];
    const stepOrder = [
      'activityType', 'photoUpload', 'photoReview', 'details',
      'amenities', 'timing', 'configure', 'submitReview',
    ];
    final target = stepOrder.indexOf(checkpoint.step);
    if (target < 0) return;

    if (context.mounted) {
      // Push every preceding route in order. Do not await intermediate pushes:
      // that would wait for the user to pop the route before adding the next
      // one. The final route is therefore backed by the real flow history.
      ActivityFlowCheckpoint.restoring = true;
      for (var i = 0; i <= target; i++) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => pages[i]),
        );
      }
      ActivityFlowCheckpoint.restoring = false;
      await ActivityFlowCheckpoint.save(
        activityId: id,
        step: checkpoint.step,
        data: checkpoint.data,
      );
    }
  }

  static Map<String, List<Map<String, String>>> _timing(dynamic value) {
    if (value is! Map) return <String, List<Map<String, String>>>{};
    return {
      for (final entry in value.entries)
        entry.key.toString(): (entry.value is List ? entry.value as List : const [])
            .whereType<Map>()
            .map((slot) => Map<String, String>.from(slot))
            .toList(),
    };
  }
}
