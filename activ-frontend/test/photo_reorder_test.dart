import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:activ_app/Screens/Home/Activities/AddActivities/AddVenuePhotoListViewScreen.dart';
import 'package:activ_app/Screens/VenuePhotoListViewScreen.dart';

// Minimal 1x1 PNG bytes
final Uint8List _kTransparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddVenuePhotoListViewScreen image reorder & cover swap', () {
    testWidgets('moving an image to top makes it the cover photo',
        (WidgetTester tester) async {
      final images = [
        XFile('assets/photo_0.jpg'),
        XFile('assets/photo_1.jpg'),
        XFile('assets/photo_2.jpg'),
        XFile('assets/photo_3.jpg'),
      ];

      List<XFile>? updatedPhotos;

      await tester.pumpWidget(
        MaterialApp(
          home: AddVenuePhotoListViewScreen(
            images: images,
            onPhotosChanged: (photos) {
              updatedPhotos = photos;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, photo_0 is at top and is Cover Photo
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.text('Cover Photo'), findsOneWidget);

      final state = tester.state(find.byType(AddVenuePhotoListViewScreen))
          as dynamic;

      // Reorder: move photo at index 2 (photo_2) to top (index 0)
      state.onReorder(2, 0);
      await tester.pumpAndSettle();

      // photo_2 is now at index 0 and is the Cover Photo
      expect(updatedPhotos, isNotNull);
      expect(updatedPhotos![0].path, 'assets/photo_2.jpg');
      expect(updatedPhotos![1].path, 'assets/photo_0.jpg');
      expect(updatedPhotos![2].path, 'assets/photo_1.jpg');
      expect(updatedPhotos![3].path, 'assets/photo_3.jpg');
      expect(find.text('Cover Photo'), findsOneWidget);

      // Reorder: move current cover photo at index 0 to index 3
      state.onReorder(0, 3);
      await tester.pumpAndSettle();

      // Now photo_0 moved to top and is the new Cover Photo
      expect(updatedPhotos![0].path, 'assets/photo_0.jpg');
      expect(updatedPhotos![1].path, 'assets/photo_1.jpg');
      expect(updatedPhotos![2].path, 'assets/photo_2.jpg');
      expect(find.text('Cover Photo'), findsOneWidget);
    });
  });

  group('VenuePhotoListViewScreen image reorder & cover swap', () {
    testWidgets('moving venue photo to top updates order and cover index',
        (WidgetTester tester) async {
      final images = [
        XFile('assets/v0.jpg'),
        XFile('assets/v1.jpg'),
        XFile('assets/v2.jpg'),
        XFile('assets/v3.jpg'),
      ];
      final bytes = [
        Uint8List.fromList(_kTransparentPng),
        Uint8List.fromList(_kTransparentPng),
        Uint8List.fromList(_kTransparentPng),
        Uint8List.fromList(_kTransparentPng),
      ];

      List<XFile>? updatedPhotos;
      List<Uint8List>? updatedBytes;
      int? updatedCover;

      await tester.pumpWidget(
        MaterialApp(
          home: VenuePhotoListViewScreen(
            images: images,
            imageBytes: bytes,
            currentCategory: const {'id': 'gym', 'name': 'Gym'},
            onPhotosChanged: (imgs, bts, cov) {
              updatedPhotos = imgs;
              updatedBytes = bts;
              updatedCover = cov;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.text('Cover Photo'), findsOneWidget);

      final state =
          tester.state(find.byType(VenuePhotoListViewScreen)) as dynamic;

      // Move photo at index 2 to index 0
      state.onReorder(2, 0);
      await tester.pumpAndSettle();

      expect(updatedPhotos, isNotNull);
      expect(updatedPhotos![0].path, 'assets/v2.jpg');
      expect(updatedCover, 0);
      expect(find.text('Cover Photo'), findsOneWidget);
    });
  });
}
