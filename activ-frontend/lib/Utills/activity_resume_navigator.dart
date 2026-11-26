import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
import '../api_calling/activity_setup_api.dart';
import '../api_calling/api_request.dart';

/// Reopens an interrupted add-activity flow without using transient Futures.
class ActivityResumeNavigator {
  static Future<void> open(
    BuildContext context,
    ActivityFlowCheckpoint checkpoint,
    http.Client? client,
  ) async {
    final id = checkpoint.activityId;
    final categoryId = checkpoint.data['categoryId']?.toString() ?? '';
    final activityName = checkpoint.data['activityName']?.toString() ?? '';
    await SharedPreference.addStringToSF('activity_current_draft_id', id);
    if (categoryId.isNotEmpty) {
      await SharedPreference.addStringToSF(
        'operate_value',
        jsonEncode({'id': categoryId, 'title': activityName}),
      );
    }
    var images = await ActivityImageDraftStore.read(id);
    if (images.isEmpty) {
      final api = ActivitySetupApi(client: client);
      try {
        final activity = await api.activity(id);
        images = (activity['imageUrls'] as List? ?? const [])
            .map((url) => url.toString())
            .where((url) => url.isNotEmpty)
            .map((url) => XFile(url, name: Uri.parse(url).pathSegments.last))
            .toList();
        if (images.isNotEmpty) {
          await ActivityImageDraftStore.save(id, images);
        }
      } catch (_) {
        // The activity screens still provide their normal retry states.
      } finally {
        api.dispose();
      }
    }
    final pages = <Widget>[
      AddListActivityTypeScreen(client: client),
      AddVenuePhotoUploadScreen(activityId: id, client: client),
      AddVenuePhotoListViewScreen(
        activityId: id,
        images: images,
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
          hasPreviousTimingRoute: true,
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
