import 'package:activ_app/Utills/slot_expiry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 30);
  final now = DateTime.utc(2026, 10, 30, 12, 2); // 17:32 IST
  test('hides ended slots while retaining ongoing and future slots', () {
    expect(slotHasEnded(date, '09:00', '10:00', now), isTrue);
    expect(slotHasEnded(date, '16:00', '17:00', now), isTrue);
    expect(slotHasEnded(date, '17:00', '18:00', now), isFalse);
    expect(slotHasEnded(date, '18:00', '19:00', now), isFalse);
  });
  test('compares complete dates and expires at the exact end boundary', () {
    expect(slotHasEnded(DateTime(2026, 10, 29), '23:00', '23:30', now), isTrue);
    expect(slotHasEnded(DateTime(2026, 10, 31), '09:00', '10:00', now), isFalse);
    expect(slotHasEnded(date, '17:00', '18:00', DateTime.utc(2026, 10, 30, 12, 30)), isTrue);
  });
  test('supports AM/PM, midnight and overnight end times', () {
    expect(slotHasEnded(date, '09:00 AM', '10:00 AM', now), isTrue);
    expect(slotEndInstant(date, '23:00', '00:00'), DateTime.utc(2026, 10, 30, 18, 30));
    expect(slotEndInstant(date, '23:00', '24:00'), DateTime.utc(2026, 10, 30, 18, 30));
    expect(slotEndInstant(date, '11:00 PM', '01:00 AM'), DateTime.utc(2026, 10, 30, 19, 30));
  });
  test('India calendar date is independent of the device timezone', () {
    expect(venueCalendarDate(DateTime.utc(2026, 10, 30, 19)), DateTime(2026, 10, 31));
    expect(slotHasEnded(date, 'bad value', '10:00', now), isTrue);
  });
}
