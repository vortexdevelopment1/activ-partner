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
    late final Widget page;

    switch (checkpoint.step) {
      case 'activityType':
        page = AddListActivityTypeScreen(client: client);
        break;
      case 'photoUpload':
        page = AddVenuePhotoUploadScreen(client: client);
        break;
      case 'photoReview':
        page = AddVenuePhotoListViewScreen(
          activityId: id,
          images: await ActivityImageDraftStore.read(id),
          client: client,
        );
        break;
      case 'details':
        page = AddSelectedVenueFormScreen(activityId: id, client: client);
        break;
      case 'amenities':
        page = AddActivityAmenitiesScreen(activityId: id, client: client);
        break;
      case 'timing':
        page = AddVenueTimingScreen(activityId: id, client: client);
        break;
      case 'configure':
        page = AddActivityConfigureScreen(
          activityId: id,
          activityName: checkpoint.data['activityName']?.toString() ?? 'Activity',
          timing: Map<String, dynamic>.from(
            checkpoint.data['timing'] as Map? ?? const {},
          ),
          client: client,
        );
        break;
      case 'submitReview':
        page = AddActivitySubmitReviewScreen(
          activityId: id,
          activityName: checkpoint.data['activityName']?.toString() ?? 'Activity',
          timing: _timing(checkpoint.data['timing']),
          client: client,
        );
        break;
      default:
        return;
    }

    if (context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
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
