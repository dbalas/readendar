import 'package:readendar/core/l10n/gen/app_localizations.dart';

/// A short localized "hace X" relative-time label, e.g. "hace 3 h".
/// Generic + reusable. [now] is injectable for deterministic tests.
String relativeTimeShort(AppL10n l, DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  var diff = n.difference(when);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  return l.timeDaysAgo(diff.inDays);
}
