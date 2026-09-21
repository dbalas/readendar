/// Canonicalizes public cover URLs for display on the current device.
///
/// Loopback hosts from local catalog fixtures are rewritten to [apiBaseUrl]
/// when provided. Leftover Hetzner path-style upload URLs from cloud export
/// until 15 October 2026 are normalized to virtual-host form.
String resolveUploadAssetUrl(String rawUrl, {String? apiBaseUrl}) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return rawUrl;

  if (uri.scheme == 'http' && _isLoopbackHost(uri.host) && apiBaseUrl != null) {
    final api = Uri.tryParse(apiBaseUrl);
    if (api != null && api.host.isNotEmpty) {
      return uri.replace(host: api.host).toString();
    }
  }

  if (uri.scheme == 'https' &&
      uri.host.split('.').length == 3 &&
      uri.host.endsWith('.your-objectstorage.com') &&
      uri.pathSegments.length >= 2) {
    final bucket = uri.pathSegments.first;
    if (bucket.isNotEmpty) {
      return uri
          .replace(
            host: '$bucket.${uri.host}',
            pathSegments: uri.pathSegments.skip(1),
          )
          .toString();
    }
  }
  return rawUrl;
}

bool _isLoopbackHost(String host) =>
    host == 'localhost' || host == '127.0.0.1' || host == '::1';

/// True when [url] is an http(s) URL that CachedNetworkImage can fetch.
bool isUsableUploadUrl(String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
