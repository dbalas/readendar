import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale-aware date formatting helpers. We never render technical/ISO dates
/// (e.g. `2026-06-15`) in the UI — every user-visible date goes through one of
/// these so it follows the device/app locale (order, separators, month names).
///
/// The active locale's date symbols are loaded by `GlobalMaterialLocalizations`,
/// so `DateFormat` for `Localizations.localeOf(context)` is always safe here.
///
/// We format with the FULL locale (language + region) so regional variants
/// differ correctly — e.g. `en-US` renders "Jun 15" / month-first while `en-GB`
/// renders "15 Jun" / day-first. `Locale.toString()` yields intl's canonical id
/// (`en_US`); intl falls back to the base language when a region has no distinct
/// symbols, so this is always safe.
String _intlLocale(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// Compact day + abbreviated month, e.g. "15 jun" (es) / "Jun 15" (en). Use in
/// tight list subtitles where the year is implied by context.
String formatDayMonth(BuildContext context, DateTime d) =>
    DateFormat.MMMd(_intlLocale(context)).format(d);

/// Day + abbreviated month + year, e.g. "15 jun 2026" (es) / "Jun 15, 2026"
/// (en). Use when the full date matters (event date, date pickers, ranges).
String formatMediumDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(_intlLocale(context)).format(d);

/// Abbreviated month + year, e.g. "jun 2026" / "Jun 2026". For compact headers
/// (calendar month switcher) where the day is irrelevant.
String formatMonthYearShort(BuildContext context, DateTime d) =>
    DateFormat.yMMM(_intlLocale(context)).format(d);
