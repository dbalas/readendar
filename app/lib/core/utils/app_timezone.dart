import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

/// Loads the shared IANA database once per Dart isolate.
///
/// `main()` eagerly calls this for the UI isolate. The defensive database check
/// keeps isolated widget tests and background entry points safe without paying
/// the initialization cost twice when another subsystem already loaded it.
void initializeAppTimeZones() {
  if (_initialized) return;
  if (tz.timeZoneDatabase.locations.isEmpty) {
    tzdata.initializeTimeZones();
  }
  _initialized = true;
}

DateTime inAppTimeZone(DateTime value, String timezone) {
  initializeAppTimeZones();
  final location = tz.timeZoneDatabase.locations[timezone];
  return location == null
      ? value.toLocal()
      : tz.TZDateTime.from(value, location);
}

/// Resolves a date-only source value at the start of that civil day in the
/// account's IANA timezone. Invalid legacy timezone values fall back to UTC so
/// the device timezone can never silently change imported history.
DateTime civilDateStartInAppTimeZone(DateTime civilDate, String timezone) {
  initializeAppTimeZones();
  final location = tz.timeZoneDatabase.locations[timezone];
  if (location == null) {
    return DateTime.utc(civilDate.year, civilDate.month, civilDate.day);
  }
  return tz.TZDateTime(
    location,
    civilDate.year,
    civilDate.month,
    civilDate.day,
  ).toUtc();
}

/// True when [a] and [b] fall on the same civil day in [timezone].
bool sameCivilDateInAppTimeZone(DateTime a, DateTime b, String timezone) {
  final localA = inAppTimeZone(a.toUtc(), timezone);
  final localB = inAppTimeZone(b.toUtc(), timezone);
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

/// Keeps [instant]'s clock time in [timezone] while replacing the civil date
/// with [civilDate]'s year/month/day. Used when the UI edits date-only values
/// backed by timestamptz rows.
DateTime replaceCivilDateInAppTimeZone(
  DateTime instant,
  DateTime civilDate,
  String timezone,
) {
  initializeAppTimeZones();
  final location = tz.timeZoneDatabase.locations[timezone];
  if (location == null) {
    final local = instant.toLocal();
    return DateTime(
      civilDate.year,
      civilDate.month,
      civilDate.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    ).toUtc();
  }
  final local = tz.TZDateTime.from(instant.toUtc(), location);
  return tz.TZDateTime(
    location,
    civilDate.year,
    civilDate.month,
    civilDate.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  ).toUtc();
}

List<String> appTimeZoneNames() {
  initializeAppTimeZones();
  return tz.timeZoneDatabase.locations.keys.toList()..sort();
}
