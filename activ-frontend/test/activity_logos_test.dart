import 'dart:ui' as ui;

import 'package:activ_app/Style/activity_logos.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('racket sports, cricket variants and renamed activities use their logos', () {
    final expected = {
      'Pickle Ball': 'pickleball',
      'pickle-ball': 'pickleball',
      'Padel': 'padel',
      'Badminton': 'badminton',
      'Tennis': 'tennis',
      'Table Tennis': 'table-tennis',
      'Squash': 'squash',
      'Cricket Turf': 'cricket',
      'Box Cricket': 'cricket',
      'Cricket Nets': 'cricket-nets',
      'Football Turf': 'football',
      'Martial Arts': 'martial-arts',
      'Other Activity': 'other',
    };
    for (final entry in expected.entries) {
      expect(activityLogoAsset(entry.key), 'assets/activities/${entry.value}.png');
    }
    expect(activityLogoAsset('Mayuri Court 1', category: 'Basketball'),
        'assets/activities/basketball.png');
    expect(activityLogoAsset('New activity'), 'assets/activities/other.png');
  });

  test('all supplied activity assets are bundled and contain visible pixels', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets()
        .where((asset) => asset.startsWith('assets/activities/')).toList();
    expect(assets.length, 37);
    for (final asset in assets) {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(
          bytes.offsetInBytes, bytes.lengthInBytes));
      final frame = await codec.getNextFrame();
      final pixels = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      var visiblePixels = 0;
      for (var index = 3; index < pixels!.lengthInBytes; index += 4) {
        if (pixels.getUint8(index) != 0) visiblePixels++;
      }
      expect(visiblePixels, greaterThan(100), reason: asset);
      frame.image.dispose();
      codec.dispose();
    }
  });
}
