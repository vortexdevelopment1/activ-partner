import 'package:activ_app/Screens/Home/Activities/VenueActivityListScreen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list delete is available only for draft and rejected activities', () {
    expect(canDeleteActivityFromList('draft'), isTrue);
    expect(canDeleteActivityFromList('REJECTED'), isTrue);
    expect(canDeleteActivityFromList('pending'), isFalse);
    expect(canDeleteActivityFromList('submitted'), isFalse);
    expect(canDeleteActivityFromList('in_review'), isFalse);
    expect(canDeleteActivityFromList('approved'), isFalse);
  });
}
