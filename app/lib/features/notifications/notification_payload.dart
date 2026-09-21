// Notification payloads shared verbatim by schedulers, tap handlers, and the
// background isolate. Every private target carries an `owner:` segment because
// logout and account-switch routing both fail closed on that identity. This is
// the single source of truth for building and parsing those payloads.

const _ownerPrefix = 'owner:';
const _eventPrefix = 'event:';
const _quotePrefix = 'quote:';
const _chapterPrefix = 'chapter:';
const _stableIdSeparator = '\u001f';

/// A process- and runtime-stable positive 31-bit notification id.
///
/// Platform notification ids outlive the Dart process, so `Object.hashCode`
/// cannot be used here: its contract does not guarantee the same result after
/// an app restart or runtime upgrade. FNV-1a over UTF-16 code units is small,
/// deterministic, and sufficient for the Android/iOS integer id slot.
///
/// [namespace] is part of the input so an event and a daily quote with otherwise
/// identical components cannot collide merely because they share the same key.
int stableNotificationId(
  String namespace,
  Iterable<String> components,
) {
  final input = <String>[namespace, ...components].join(_stableIdSeparator);
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

int eventNotificationId(String ownerUserId, String eventId) =>
    stableNotificationId('event', [ownerUserId, eventId]);

int dailyQuoteNotificationId(String ownerUserId, String localDate) =>
    stableNotificationId('daily-quote', [ownerUserId, localDate]);

/// Stamps the owning user (so logout cancels only their reminders) and the event
/// (so a tap can deep-link to it).
String buildNotifPayload(String ownerUserId, String eventId) =>
    '$_ownerPrefix$ownerUserId|$_eventPrefix$eventId';

/// Quote-of-the-day payload: same `owner:` segment (so logout's
/// [payloadBelongsToOwner] sweep covers it) with a `quote:` target instead of
/// an event.
String buildQuoteNotifPayload(String ownerUserId, String quoteId) =>
    '$_ownerPrefix$ownerUserId|$_quotePrefix$quoteId';

/// Owner-scoped Reading Chapter payload. Returning null keeps malformed remote
/// data from creating an ownerless notification that could cross accounts.
String? buildReadingChapterNotifPayload(String ownerUserId, String route) {
  final owner = ownerUserId.trim();
  final chapterRoute = _validReadingChapterRoute(route);
  if (owner.isEmpty || owner.contains('|') || chapterRoute == null) return null;
  return '$_ownerPrefix$owner|$_chapterPrefix$chapterRoute';
}

String? readingChapterRouteFromNotifPayload(String? payload) {
  if (ownerIdFromNotifPayload(payload) == null) return null;
  return _validReadingChapterRoute(_segment(payload, _chapterPrefix));
}

String? readingChapterOwnerIdFromNotifPayload(String? payload) =>
    readingChapterRouteFromNotifPayload(payload) == null
    ? null
    : ownerIdFromNotifPayload(payload);

String? _validReadingChapterRoute(String? route) {
  if (route == '/reading-chapters') return route;
  if (route == null) return null;
  final match = RegExp(
    r'^/reading-chapters/(month|year)/([0-9]{4}(?:-(?:0[1-9]|1[0-2]))?)$',
  ).firstMatch(route);
  if (match == null) return null;
  final kind = match.group(1)!;
  final period = match.group(2)!;
  if (kind == 'month' && period.length != 7) return null;
  if (kind == 'year' && period.length != 4) return null;
  final year = int.tryParse(period.substring(0, 4));
  if (year == null || year < 1970 || year > 2199) return null;
  return route;
}

/// The event id, or null for a legacy bare `owner:<id>` payload / empty segment.
String? eventIdFromNotifPayload(String? payload) =>
    _segment(payload, _eventPrefix);

/// The quote id of a quote-of-the-day payload, or null.
String? quoteIdFromNotifPayload(String? payload) =>
    _segment(payload, _quotePrefix);

/// The owner user id, or null if absent.
String? ownerIdFromNotifPayload(String? payload) =>
    _segment(payload, _ownerPrefix);

/// Whether [payload] was scheduled by [ownerUserId] — matches both the current
/// `owner:<id>|event:<id>` format and the legacy bare `owner:<id>`.
bool payloadBelongsToOwner(String? payload, String ownerUserId) {
  if (payload == null) return false;
  final owner = '$_ownerPrefix$ownerUserId';
  return payload == owner || payload.startsWith('$owner|');
}

String? _segment(String? payload, String prefix) {
  if (payload == null) return null;
  for (final part in payload.split('|')) {
    if (part.startsWith(prefix)) {
      final v = part.substring(prefix.length).trim();
      return v.isEmpty ? null : v;
    }
  }
  return null;
}
