import 'package:activ_app/Screens/VenueTimingScreen.dart' as venue;
import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenueTimingScreen.dart'
    as activity;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final addingActivity in [false, true]) {
    for (final action in ['Cancel', 'OK', 'dismiss']) {
      testWidgets(
          '${addingActivity ? "activity" : "venue"} Copy to all requires confirmation: $action',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 1100);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final Widget screen = addingActivity
            ? const activity.AddVenueTimingScreen(activityId: 'venue')
            : const venue.VenueTimingScreen(activityId: 'venue');
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byWidget(screen));
        state.toggleDay('Mon', true);
        state.toggleDay('Tue', true);
        state.toggleDay('Wed', true);
        state.selectedDays.remove('Wed');
        final source = [
          {'open': '09:00 AM', 'close': '12:00 PM'},
          {'open': '02:00 PM', 'close': '06:00 PM'},
        ];
        final originalTuesday = [
          {'open': '10:00 AM', 'close': '04:00 PM'}
        ];
        final originalWednesday = [
          {'open': '07:00 AM', 'close': '09:00 AM'}
        ];
        state.timings['Mon'].timeSlots
          ..clear()
          ..addAll(source);
        state.timings['Tue'].timeSlots
          ..clear()
          ..addAll(originalTuesday);
        state.timings['Wed'].timeSlots
          ..clear()
          ..addAll(originalWednesday);
        await tester.pumpAndSettle();
        final copy = find.text('Copy to all').first;
        await tester.ensureVisible(copy);
        await tester.tap(copy);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
            find.text(
                'This change will replace the timings for all selected days with these timings.'),
            findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(state.timings['Tue'].timeSlots, originalTuesday);
        if (action == 'dismiss') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(state.timings['Tue'].timeSlots,
            action == 'OK' ? source : originalTuesday);
        expect(state.timings['Mon'].timeSlots, source);
        expect(state.timings['Wed'].timeSlots, originalWednesday);
        expect(state.selectedDays, ['Mon', 'Tue']);
        if (action == 'OK') {
          state.timings['Tue'].timeSlots.first['open'] = '08:00 AM';
          expect(state.timings['Mon'].timeSlots.first['open'], '09:00 AM');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
