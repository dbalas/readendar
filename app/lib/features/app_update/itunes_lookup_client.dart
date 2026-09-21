import 'package:dio/dio.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';

const itunesLookupBundleId = 'com.readendar.readendar';

/// Apple-hosted lookup. [country] is an ISO 3166-1 alpha-2 storefront.
Future<ItunesLookupResult?> lookupItunes({
  required String country,
  Dio? dio,
}) async {
  final client =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: appUpdateCheckTimeout,
          receiveTimeout: appUpdateCheckTimeout,
          sendTimeout: appUpdateCheckTimeout,
          headers: const {'User-Agent': 'Readendar/app-update'},
        ),
      );
  try {
    final response = await client.get<dynamic>(
      'https://itunes.apple.com/lookup',
      queryParameters: {
        'bundleId': itunesLookupBundleId,
        'country': country,
      },
    );
    return parseItunesLookup(_asStringKeyMap(response.data));
  } catch (_) {
    return null;
  }
}

ItunesLookupResult? parseItunesLookup(Map<String, dynamic>? data) {
  if (data == null) return null;
  final count = data['resultCount'];
  final n = count is int
      ? count
      : count is num
      ? count.toInt()
      : null;
  if (n == null || n < 1) return null;
  final results = data['results'];
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  if (first is! Map) return null;
  final version = first['version']?.toString().trim() ?? '';
  if (version.isEmpty) return null;
  final notes = first['releaseNotes']?.toString();
  final url = first['trackViewUrl']?.toString();
  return ItunesLookupResult(
    version: version,
    releaseNotes: notes,
    trackViewUrl: url,
  );
}

Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return {
      for (final e in raw.entries) e.key.toString(): e.value,
    };
  }
  return null;
}
