// Shared reminder-offset presets + label rendering (spec §16.4).

import 'package:readendar/core/l10n/gen/app_localizations.dart';

/// Preset offsets shown in the event form + notification settings.
const reminderOffsetPresets = <int>[0, 15, 60, 1440, 2880, 10080];

/// Returns a short localized label for a reminder-offset in minutes.
String reminderOffsetLabel(AppL10n l, int minutes) {
  if (minutes == 0) return l.reminderAtTime;
  if (minutes < 60) return l.reminderMinutesPlural(minutes);
  if (minutes < 1440) return l.reminderHoursPlural(minutes ~/ 60);
  if (minutes < 10080) return l.reminderDaysPlural(minutes ~/ 1440);
  return l.reminderWeeksPlural(minutes ~/ 10080);
}
