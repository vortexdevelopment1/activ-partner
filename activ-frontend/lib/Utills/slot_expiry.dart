const _venueOffset = Duration(hours: 5, minutes: 30);

DateTime venueCalendarDate(DateTime instant) {
  final wallTime = instant.toUtc().add(_venueOffset);
  return DateTime(wallTime.year, wallTime.month, wallTime.day);
}

int? _minutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
          caseSensitive: false).firstMatch(value.trim());
  if (match == null) return null;
  var hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final suffix = match[3]?.toUpperCase();
  if (minute > 59) return null;
  if (suffix != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (suffix == 'PM' ? 12 : 0);
  } else if (hour > 24 || (hour == 24 && minute != 0)) {
    return null;
  }
  return hour * 60 + minute;
}

/// Availability times are venue wall-clock values in Asia/Kolkata, matching
/// the backend. Device timezone must not change which slot has expired.
DateTime? slotEndInstant(DateTime date, String startTime, String endTime) {
  final start = _minutes(startTime);
  final end = _minutes(endTime);
  if (start == null || end == null) return null;
  final endMinutes = end <= start ? end + 24 * 60 : end;
  return DateTime.utc(date.year, date.month, date.day)
      .add(Duration(minutes: endMinutes)).subtract(_venueOffset);
}

bool slotHasEnded(DateTime date, String startTime, String endTime, DateTime now) {
  final end = slotEndInstant(date, startTime, endTime);
  return end == null || !end.isAfter(now);
}
