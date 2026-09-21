/// Parsed iTunes Lookup row for this app.
class ItunesLookupResult {
  const ItunesLookupResult({
    required this.version,
    this.releaseNotes,
    this.trackViewUrl,
  });

  final String version;
  final String? releaseNotes;
  final String? trackViewUrl;
}

/// Shared cap for Play IAU and iTunes Lookup. Fail closed on expiry.
const appUpdateCheckTimeout = Duration(milliseconds: 2500);

typedef ItunesLookup =
    Future<ItunesLookupResult?> Function({required String country});
