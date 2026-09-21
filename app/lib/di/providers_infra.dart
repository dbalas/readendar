part of 'providers.dart';

// ─── Infra providers ─────────────────────────────────

/// Telemetry is a local no-op. The provider stays so call sites compile.
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService.disabled,
);

final apiBaseUrlProvider = Provider<String>((ref) {
  return resolveApiBaseUrl(
    fromEnv: const String.fromEnvironment('API_BASE_URL'),
    releaseMode: kReleaseMode,
  );
});

/// Site host for leftover magic-link Universal Links until the export window
/// closes. Overridable via --dart-define=WEB_BASE_URL=.
final webBaseUrlProvider = Provider<String>((ref) {
  const fromEnv = String.fromEnvironment('WEB_BASE_URL');
  return fromEnv.isNotEmpty ? fromEnv : 'https://readendar.com';
});

final secureStorageProvider = Provider<SecureTokenStorage>(
  (_) => SecureTokenStorage(),
);

final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});

final prefsStorageProvider = Provider<PrefsStorage>(
  (ref) => PrefsStorage(ref.watch(sharedPreferencesProvider)),
);

final spotlightIndexProvider = Provider<SpotlightIndex>((_) => spotlightIndex);

class RevealedSpoilerQuotesNotifier extends StateNotifier<Set<String>> {
  RevealedSpoilerQuotesNotifier(this._storage, this._userId)
    : super(
        _userId.isEmpty || _storage == null
            ? const <String>{}
            : _storage.getRevealedSpoilerQuoteIds(_userId),
      );

  final PrefsStorage? _storage;
  final String _userId;

  Future<bool> reveal(String quoteId) async {
    if (_userId.isEmpty || quoteId.trim().isEmpty) return false;
    final stored =
        await _storage?.revealSpoilerQuote(_userId, quoteId) ?? false;
    if (stored) state = {...state, quoteId};
    return stored;
  }
}

final revealedSpoilerQuoteIdsProvider =
    StateNotifierProvider<RevealedSpoilerQuotesNotifier, Set<String>>((ref) {
      final userId = ref.watch(
        sessionProvider.select((session) => session.user?.id ?? ''),
      );
      PrefsStorage? storage;
      try {
        storage = ref.watch(prefsStorageProvider);
      } on Object {
        // Widget tests and storage-degraded launches still protect content;
        // reveal works for the current session and reports persistence failure.
      }
      return RevealedSpoilerQuotesNotifier(storage, userId);
    });

// ─── Theme + Locale ──────────────────────────────────

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_load(_prefs));
  final PrefsStorage _prefs;
  // First run follows the OS: no stored preference → `system`, so the app opens
  // in whatever brightness the device is set to. An explicit light/dark/system
  // choice from the appearance picker is honoured thereafter.
  static ThemeMode _load(PrefsStorage p) => switch (p.getTheme()) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };
  Future<void> setMode(ThemeMode m) async {
    state = m;
    await _prefs.setTheme(switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(prefsStorageProvider)),
);

class ReadendarThemeNotifier extends StateNotifier<ReadendarThemeId> {
  ReadendarThemeNotifier(this._prefs)
    : super(ReadendarThemeId.fromWire(_prefs.getThemePreset()));

  final PrefsStorage _prefs;

  Future<bool> setTheme(ReadendarThemeId theme) async {
    if (theme == state) return true;
    try {
      final saved = await _prefs.setThemePreset(theme.wire);
      if (!saved) return false;
      state = theme;
      return true;
    } catch (_) {
      return false;
    }
  }
}

final readendarThemeProvider =
    StateNotifierProvider<ReadendarThemeNotifier, ReadendarThemeId>(
      (ref) => ReadendarThemeNotifier(ref.watch(prefsStorageProvider)),
    );

class PremiumCoverAtmosphereNotifier extends StateNotifier<bool> {
  PremiumCoverAtmosphereNotifier(
    PrefsStorage prefs,
    this._write,
  ) : super(prefs.getPremiumCoverAtmosphereEnabled());

  final Future<bool> Function(bool enabled) _write;

  Future<bool> setEnabled(bool enabled) async {
    if (enabled == state) return true;
    try {
      if (!await _write(enabled)) return false;
      state = enabled;
      return true;
    } on Object {
      return false;
    }
  }
}

final premiumCoverAtmosphereWriterProvider =
    Provider<Future<bool> Function(bool enabled)>(
      (ref) => ref.watch(prefsStorageProvider).setPremiumCoverAtmosphereEnabled,
    );

final premiumCoverAtmosphereProvider =
    StateNotifierProvider<PremiumCoverAtmosphereNotifier, bool>(
      (ref) => PremiumCoverAtmosphereNotifier(
        ref.watch(prefsStorageProvider),
        ref.watch(premiumCoverAtmosphereWriterProvider),
      ),
    );

final effectiveReadendarThemeProvider = Provider<ReadendarThemeId>(
  (ref) => ref.watch(readendarThemeProvider),
);

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._prefs) : super(_load(_prefs));
  final PrefsStorage _prefs;

  static Locale _load(PrefsStorage p) {
    // Product UI is Spanish only. Ignore leftover device or prefs tags.
    return const Locale('es');
  }

  Future<void> setLocale(Locale? _) async {
    state = const Locale('es');
    await _prefs.setLocale('es');
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(ref.watch(prefsStorageProvider)),
);
