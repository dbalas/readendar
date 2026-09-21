/// Offline cutover constants. Date D is compiled; extending it needs a store
/// release. Set from the later of Play / App Store live dates plus 15 days.
library;

enum DataPlane {
  api,
  local;

  static DataPlane fromPrefs(String? raw) =>
      raw == 'local' ? DataPlane.local : DataPlane.api;
}

/// UTC instant when the Readendar API is retired.
final apiShutdownAt = DateTime.utc(2026, 10, 15, 12);

bool get apiWindowOpen => DateTime.now().toUtc().isBefore(apiShutdownAt);

/// Hosted export/auth base used until [apiShutdownAt]. New installs do not
/// need a dart-define; override with `--dart-define=API_BASE_URL=` to point
/// somewhere else during the window.
const defaultApiBaseUrl = 'https://api.readendar.com';

/// Resolves the sunset API host. Empty [fromEnv] uses [defaultApiBaseUrl].
/// Release builds still reject a plaintext override because leftover JWTs
/// travel on this client until the window closes.
String resolveApiBaseUrl({
  required String fromEnv,
  required bool releaseMode,
}) {
  if (fromEnv.isNotEmpty) {
    if (releaseMode && !fromEnv.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL must be an https:// URL in release builds',
      );
    }
    return fromEnv;
  }
  return defaultApiBaseUrl;
}

/// Product data is always local. Sticky `data_plane=api` and leftover JWT
/// identities must not send library/calendar/quotes back to the API.
DataPlane resolveDataPlane({
  required String? raw,
  required String? userId,
  bool windowOpen = true,
}) {
  return DataPlane.local;
}

const localGuestUserId = 'local-guest';
const dataPlanePrefsKey = 'data_plane:v1';
const migrationBannerHideKey = 'migration_banner_hidden:v1';

/// Public source repo linked from the API shutdown migration prompt.
final migrationOpenSourceRepoUri = Uri.parse(
  'https://github.com/dbalas/readendar',
);
const localProfilePrefsKey = 'local_profile:v1';
const importCheckpointPrefsKey = 'import_checkpoint:v1';
const openLibraryUserAgent =
    'Readendar/1.0 (https://readendar.com; hello@readendar.com)';
const bneSruBase = 'https://catalogo.bne.es/view/sru/34BNE_INST';
const openLibrarySearchUrl = 'https://openlibrary.org/search.json';
const openLibraryIsbnUrl = 'https://openlibrary.org/isbn';
const bneSparqlUrl = 'https://datos.bne.es/sparql';
const wikidataSparqlUrl = 'https://query.wikidata.org/sparql';
const empathySearchUrl = 'https://api.empathy.co/search/v1/query/cdl/search';
const empathyOrigin = 'https://www.casadellibro.com';
