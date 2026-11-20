import 'package:intl/intl.dart';

/// India Standard Time offset from UTC (+05:30).
const Duration indiaUtcOffset = Duration(hours: 5, minutes: 30);

/// Converts any UTC or local instant into India Standard Time (UTC+05:30),
/// storing wall-clock components in a UTC DateTime object so device timezone
/// never alters year, month, day, hour, or minute.
DateTime toIndiaTime(DateTime instant) {
  final utc = instant.isUtc ? instant : instant.toUtc();
  final ist = utc.add(indiaUtcOffset);
  return DateTime.utc(
    ist.year,
    ist.month,
    ist.day,
    ist.hour,
    ist.minute,
    ist.second,
    ist.millisecond,
    ist.microsecond,
  );
}

/// Current date and time in India Standard Time.
DateTime nowInIndia() => toIndiaTime(DateTime.now());

/// Formats an instant in India Standard Time.
String formatIndiaDate(DateTime instant, [String pattern = 'dd MMM yyyy']) {
  return DateFormat(pattern).format(toIndiaTime(instant));
}

/// Formats time in India Standard Time.
String formatIndiaTime(DateTime instant, [String pattern = 'hh:mm a']) {
  return DateFormat(pattern).format(toIndiaTime(instant));
}

/// Formats date and time in India Standard Time.
String formatIndiaDateTime(DateTime instant, [String pattern = 'dd MMM yyyy, hh:mm a']) {
  return DateFormat(pattern).format(toIndiaTime(instant));
}

/// Returns the Indian business calendar date key in YYYY-MM-DD format.
String indiaDateKey(DateTime instant) {
  final ist = toIndiaTime(instant);
  final y = ist.year.toString().padLeft(4, '0');
  final m = ist.month.toString().padLeft(2, '0');
  final d = ist.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
