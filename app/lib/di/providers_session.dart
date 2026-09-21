part of 'providers.dart';

// ─── Session ─────────────────────────────────────────

class SessionState {
  const SessionState({
    this.user,
    this.loading = false,
    this.recoverableAuthFailure = false,
  });
  final AppUser? user;
  final bool loading;
  final bool recoverableAuthFailure;
  SessionState copyWith({
    AppUser? user,
    bool? loading,
    bool? recoverableAuthFailure,
  }) => SessionState(
    user: user ?? this.user,
    loading: loading ?? this.loading,
    recoverableAuthFailure:
        recoverableAuthFailure ?? this.recoverableAuthFailure,
  );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(Ref ref) : _ref = ref, super(const SessionState());
  final Ref _ref;

  Future<void> bootstrap() async {
    await _retryPendingPrivateSurfaceCleanup();
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getAccess();
    final keepCloudImport = apiWindowOpen && !_cloudImportFinished();
    if (!keepCloudImport && token != null) {
      await storage.clear();
    }
    try {
      _ref.read(cloudImportAvailableProvider.notifier).state = keepCloudImport;
    } on Object {
      // Widget tests may skip this provider's container.
    }
    await _bootstrapLocalGuest();
  }

  bool _cloudImportFinished() {
    try {
      return _ref.read(prefsStorageProvider).isMigrationBannerHidden();
    } on Object {
      return false;
    }
  }

  Future<void> _bootstrapLocalGuest() async {
    final prefs = _ref.read(prefsStorageProvider);
    await prefs.setDataPlane('local');
    _ref.read(dataPlaneTickProvider.notifier).state++;
    final cached = prefs.getLocalProfileJson();
    final hadExistingProfile = cached != null && cached.isNotEmpty;
    AppUser user;
    if (hadExistingProfile) {
      user = AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      if (user.id != localGuestUserId) {
        user = AppUser(
          id: localGuestUserId,
          email: '',
          displayName: user.displayName,
          preferredLocale: user.preferredLocale,
          timezone: user.timezone,
          onboardingCompletedAt: user.onboardingCompletedAt,
          termsAcceptedAt: user.termsAcceptedAt,
          termsVersion: user.termsVersion,
          autoCreateStatusEvents: user.autoCreateStatusEvents,
          alwaysShowSpoilerQuotes: user.alwaysShowSpoilerQuotes,
          homeBanner: user.homeBanner,
        );
        await prefs.setLocalProfileJson(jsonEncode(user.toJson()));
      }
    } else {
      final now = DateTime.now().toUtc();
      user = AppUser(
        id: localGuestUserId,
        email: '',
        displayName: '',
        preferredLocale: 'es',
        timezone: 'Europe/Madrid',
        onboardingCompletedAt: now,
        termsAcceptedAt: now,
        termsVersion: currentTermsVersion,
      );
      await prefs.setLocalProfileJson(jsonEncode(user.toJson()));
    }
    // Returning local profiles already finished profile onboarding before the
    // device-scoped welcome tour shipped; stamp intro so they are not forced
    // through the carousel on upgrade. Fresh installs keep intro unseen until
    // the tour completes.
    if (hadExistingProfile &&
        user.onboardingCompletedAt != null &&
        !prefs.isIntroSeen()) {
      await prefs.setIntroSeen();
    }
    state = SessionState(user: user);
    _syncWidgetTheme(reason: 'local guest bootstrap');
    unawaited(() async {
      try {
        await syncWidgetFromRef(
          _ref,
          user,
          resolvedAppTheme: _widgetTheme(),
        );
        await syncQuotesWidgetFromRef(_ref);
      } on Object catch (e) {
        debugPrint('widget sync on local guest bootstrap failed: $e');
      }
    }());
  }

  void setUser(AppUser u) {
    final previousUser = state.user;
    final wasLoggedOut = previousUser == null;
    state = SessionState(user: u);
    unawaited(_cacheUser(u));
    _configureAnalyticsFor(u);
    // Best-effort: on a fresh session (not a profile-data refresh of an
    // already-loaded user), push the widget token/summary so a home-screen
    // widget added from a previous session, or a first-time add right after
    // bootstrap, reflects this library without waiting on the native poll.
    if (wasLoggedOut) {
      _syncWidgetTheme(reason: 'session start');
      // Provision + push the events widget, THEN refresh the quotes widget —
      // ordered so the quotes widget's native re-fetch sees the freshly-written
      // token (reloadWidget via syncWidget is events-only now). syncQuotesWidget
      // reloads the quotes widget even when the in-app quotes list is still cold.
      unawaited(() async {
        try {
          await syncWidgetFromRef(
            _ref,
            u,
            resolvedAppTheme: _widgetTheme(),
          );
          await syncQuotesWidgetFromRef(_ref);
        } catch (e) {
          debugPrint('widget sync on session start failed: $e');
        }
      }());
    }
  }

  void _syncWidgetTheme({required String reason}) {
    final theme = _widgetTheme();
    unawaited(() async {
      final updated = await pushWidgetAppTheme(theme);
      if (!updated) debugPrint('widget theme sync on $reason failed');
    }());
  }

  ReadendarThemeId _widgetTheme() {
    try {
      return _ref.read(readendarThemeProvider);
    } on Object {
      // Storage may not be installed during early bootstrap or tests.
      return ReadendarThemeId.original;
    }
  }

  void _configureAnalyticsFor(AppUser user) {
    final enabled = user.termsVersion == currentTermsVersion;
    final analytics = _ref.read(analyticsProvider);
    unawaited(() async {
      try {
        await analytics.setCollectionEnabled(enabled: enabled);
        if (!enabled) return;
        await analytics.setUserId(user.id);
      } on Object catch (e) {
        debugPrint('analytics configuration failed: $e');
      }
    }());
  }

  Future<void> _cacheUser(AppUser user) async {
    try {
      await _ref
          .read(secureStorageProvider)
          .saveCachedUser(jsonEncode(user.toJson()));
    } on Object catch (e) {
      debugPrint('session user cache write failed: $e');
    }
  }

  Future<void> clear() async {
    final uid = state.user?.id;
    // Forced 401: drop the signed-in UI before token
    // or Spotlight work. Tokens still need a durable local wipe below.
    state = const SessionState();
    await _ref.read(secureStorageProvider).clear();
    if (uid != null) {
      try {
        await LocalNotifications.I.cancelAllForUser(uid);
      } on Object catch (e) {
        // Loss of the local scheduler must not prevent forced sign-out after
        // an authoritative 401. Private widget/Spotlight cleanup below keeps
        // its own durable retry marker.
        debugPrint('notification cleanup on clear failed: $e');
      }
    }
    // Forced logout (401 / refresh failure) routes through
    // here, not logout(): wipe the widgets' shared data too so a home-screen
    // widget can't keep rendering the previous session's cached
    // quotes + events on a shared device. Best-effort (no server revoke — the
    // token is already invalid on this path).
    await _clearPrivateSurfaces();
    unawaited(
      _ref
          .read(analyticsProvider)
          .setCollectionEnabled(enabled: false)
          .catchError(
            (Object e) => debugPrint('analytics disable on clear failed: $e'),
          ),
    );
    if (uid != null) {
      try {
        final prefs = _ref.read(prefsStorageProvider);
        await prefs.clearReadingChapterCache(uid);
      } on Object {
        // Tests and early bootstrap may not have installed preferences yet.
      }
    }
    try {
      await _bootstrapLocalGuest();
    } on Object {
      // Tests and early bootstrap may not have installed preferences yet.
    }
  }

  Future<void> persistLocalUser(AppUser user) async {
    state = SessionState(user: user);
    await _ref
        .read(prefsStorageProvider)
        .setLocalProfileJson(jsonEncode(user.toJson()));
  }

  Future<Result<void>> logout() async {
    final uid = state.user?.id;
    // Drop UI first. Local guest is restored below so a wipe or forced 401
    // never leaves the session empty.
    state = const SessionState();
    try {
      await _ref.read(prefsStorageProvider).setDataPlane('local');
      _ref.read(dataPlaneTickProvider.notifier).state++;
      _ref.read(cloudImportAvailableProvider.notifier).state = false;
    } on Object {
      // Tests may not install preferences.
    }

    final r = await _ref.read(authRepoProvider).logout();
    final privateSurfacesCleared = await _clearPrivateSurfaces();
    if (uid != null) await LocalNotifications.I.cancelAllForUser(uid);
    unawaited(
      _ref
          .read(analyticsProvider)
          .setCollectionEnabled(enabled: false)
          .catchError(
            (Object e) => debugPrint('analytics disable on logout failed: $e'),
          ),
    );
    if (uid != null) {
      try {
        final prefs = _ref.read(prefsStorageProvider);
        await prefs.clearReadingChapterCache(uid);
      } on Object {
        // Logout must not fail because local draft cleanup is unavailable.
      }
    }
    if (!privateSurfacesCleared) {
      return const Err(
        UnknownFailure('signed_out_with_private_surface_cleanup_pending'),
      );
    }
    return r;
  }

  Future<bool> _clearPrivateSurfaces() async {
    PrefsStorage? prefs;
    var markersPersisted = false;
    try {
      final resolvedPrefs = _ref.read(prefsStorageProvider);
      prefs = resolvedPrefs;
      final widgetMarked = await resolvedPrefs.setWidgetCleanupPending(true);
      final spotlightMarked = await resolvedPrefs.setSpotlightCleanupPending(
        true,
      );
      markersPersisted = widgetMarked && spotlightMarked;
    } on Object catch (e) {
      debugPrint('privacy cleanup marker write failed: $e');
    }

    final widgetCleared = await clearWidgetData(
      appTheme: _widgetTheme(),
    );
    final spotlightCleared = await _ref
        .read(spotlightIndexProvider)
        .deleteAll();
    var markersCleared = markersPersisted;
    if (prefs != null) {
      try {
        if (widgetCleared) {
          markersCleared =
              await prefs.setWidgetCleanupPending(false) && markersCleared;
        }
        if (spotlightCleared) {
          markersCleared =
              await prefs.setSpotlightCleanupPending(false) && markersCleared;
        }
      } on Object catch (e) {
        markersCleared = false;
        debugPrint('privacy cleanup marker clear failed: $e');
      }
    }
    return widgetCleared && spotlightCleared && markersCleared;
  }

  Future<void> _retryPendingPrivateSurfaceCleanup() async {
    PrefsStorage prefs;
    try {
      prefs = _ref.read(prefsStorageProvider);
    } on Object {
      return;
    }
    if (prefs.isWidgetCleanupPending) {
      final cleared = await clearWidgetData(
        appTheme: _widgetTheme(),
      );
      if (cleared) await prefs.setWidgetCleanupPending(false);
    }
    if (prefs.isSpotlightCleanupPending) {
      final cleared = await _ref.read(spotlightIndexProvider).deleteAll();
      if (cleared) await prefs.setSpotlightCleanupPending(false);
    }
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
