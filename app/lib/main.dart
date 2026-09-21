import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/analytics/analytics_service.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/l10n/localization_delegates.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/performance/app_performance_monitor.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/icon_fonts.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/platform_chrome_theme.dart';
import 'package:readendar/core/theme/system_ui_style.dart';
import 'package:readendar/core/theme/theme_background.dart';
import 'package:readendar/core/utils/app_deep_link_hub.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_root_nav_bar.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/widgets/revalidate_on_enter.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/app_update/app_update_prompt.dart';
import 'package:readendar/features/auth/magic_link_deep_link.dart';
import 'package:readendar/features/calendar/calendar_screen.dart';
import 'package:readendar/features/product_feedback/product_feedback_prompt.dart';
import 'package:readendar/features/home/home_screen.dart';
import 'package:readendar/features/import/import_deep_link.dart';
import 'package:readendar/features/library/library_screen.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/notifications/notification_tap_handler.dart';
import 'package:readendar/features/notifications/pending_action_drainer.dart';
import 'package:readendar/features/onboarding/onboarding_tour_screen.dart';
import 'package:readendar/features/profile/legal_acceptance_screen.dart';
import 'package:readendar/features/profile/profile_screen.dart';
import 'package:readendar/features/quotes/quote_daily_notification.dart';
import 'package:readendar/features/shortcuts/app_shortcuts.dart';
import 'package:readendar/features/spotlight/spotlight_index.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screenshot runs exercise navigation, not native reminder provisioning.
/// Skipping it avoids platform retries delaying or destabilizing each capture.
const _kShotCapture = bool.fromEnvironment('SHOT_CAPTURE');

/// Route Android image picking through the system Photo Picker instead of the
/// legacy `ACTION_GET_CONTENT` gallery intent.
///
/// This is what keeps `READ_MEDIA_IMAGES` out of the manifest: the picker runs
/// out-of-process and hands back a single user-chosen URI, so the app never
/// needs broad media access — and we never have to file Play's Photo & Video
/// Permissions declaration. On devices without the picker the plugin falls back
/// to `ACTION_OPEN_DOCUMENT`, which is also permission-free.
///
/// No-op on iOS: `ImagePickerPlatform.instance` is the iOS implementation there.
void _enableAndroidPhotoPicker() {
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) {
    picker.useAndroidPhotoPicker = true;
  }
}

/// Draw behind the status + navigation bars on every Android version.
///
/// Android 15 (API 35) and up enforce edge-to-edge for `targetSdk >= 35` and
/// ignore any attempt to opt out, so the app already runs this way on new
/// devices. Enabling it explicitly makes API 24–34 behave the same instead of
/// leaving two different layouts to reason about. Insets still come through
/// `MediaQuery`/`SafeArea`, which the screens already honour.
///
/// No-op on iOS.
void _enableEdgeToEdge() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureIconFontsLoaded();
  final images = PaintingBinding.instance.imageCache;
  images.maximumSize = 400;
  images.maximumSizeBytes = 150 << 20;
  AppPerformanceMonitor.instance.startLaunch();
  final prefsFuture = SharedPreferences.getInstance();
  final storeFuture = LocalStore.open();
  _enableAndroidPhotoPicker();
  _enableEdgeToEdge();
  final prefs = await prefsFuture;
  final store = await storeFuture;

  Widget app() => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      analyticsProvider.overrideWithValue(AnalyticsService.disabled),
      localStoreProvider.overrideWithValue(store),
    ],
    // Riverpod 3 retries failed providers by default (up to 10 times with
    // backoff). Our error handling predates that: failures surface immediately
    // through Failure/ErrorRetry and the Dio layer owns transport retries, so
    // keep the v2 fail-fast semantics instead of hammering the API on a 4xx.
    retry: (retryCount, error) => null,
    child: const ReadendarApp(),
  );

  _runAppWithDeferredPlatformServices(app(), prefs);
}

/// Shows Flutter before non-visual native work. Notification scheduling still
/// initializes before its first platform operation (the service coalesces
/// concurrent init calls), while first paint no longer waits for it.
void _runAppWithDeferredPlatformServices(Widget app, SharedPreferences prefs) {
  runApp(app);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppPerformanceMonitor.instance.markFirstFrame();
    unawaited(_initializeDeferredPlatformServices(prefs));
  });
}

Future<void> _initializeDeferredPlatformServices(
  SharedPreferences prefs,
) async {
  try {
    await LocalNotifications.I.init(
      categoriesL10n: _resolveNotificationL10n(prefs),
    );
  } catch (e, s) {
    // Notification availability must never take down the visible app.
    debugPrint('LocalNotifications init failed: $e\n$s');
  }
}

/// Resolve an [AppL10n] for the device/saved locale so the iOS notification
/// action categories carry localized button titles from first launch (they
/// don't follow a live in-app language switch until relaunch). Falls back to
/// Spanish for an unsupported locale.
AppL10n _resolveNotificationL10n(SharedPreferences prefs) {
  final saved = PrefsStorage(prefs).getLocale();
  final locale = (saved != null && saved.isNotEmpty)
      ? localeFromTag(saved)
      : WidgetsBinding.instance.platformDispatcher.locale;
  try {
    return lookupAppL10n(locale);
  } catch (_) {
    return lookupAppL10n(const Locale('es'));
  }
}

class ReadendarApp extends ConsumerWidget {
  const ReadendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final selectedTheme = ref.watch(effectiveReadendarThemeProvider);
    // Publish the OS status/navigation-bar style declaratively over the whole
    // window. AppBars publish their own top overlay style; the root region keeps
    // the bottom navigation style present in the same rendered frame.
    final brightness = _effectiveBrightness(themeMode);
    final lightTheme = withCupertinoSplashSuppressed(
      buildLightTheme(themeId: selectedTheme),
    );
    final darkTheme = withCupertinoSplashSuppressed(
      buildDarkTheme(themeId: selectedTheme),
    );
    final effectiveTheme = brightness == Brightness.dark
        ? darkTheme
        : lightTheme;
    final systemBackground = effectiveTheme
        .extension<ReadendarColorsTheme>()
        ?.colors
        .bg;
    return ReadendarSystemUiStyle(
      brightness: brightness,
      backgroundColor: systemBackground,
      child: MaterialApp(
        navigatorKey: ref.watch(rootNavigatorKeyProvider),
        // Automatic `screen_view` events. `observer` is null when analytics is
        // disabled (un-configured build / tests), so the list is then empty.
        navigatorObservers: [
          ?ref.watch(analyticsProvider).observer,
        ],
        onGenerateTitle: (context) => AppL10n.of(context).appName,
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        builder: (context, child) => ReadendarThemeBackground(
          child: child ?? const SizedBox.shrink(),
        ),
        locale: locale ?? const Locale('es'),
        localizationsDelegates: readendarLocalizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const _Gate(),
      ),
    );
  }
}

/// Resolves the brightness actually shown on screen. `system` defers to the OS;
/// explicit light/dark modes win regardless of the OS.
Brightness _effectiveBrightness(ThemeMode mode) => switch (mode) {
  ThemeMode.light => Brightness.light,
  ThemeMode.dark => Brightness.dark,
  ThemeMode.system =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
};

Future<void> _syncSpotlight(WidgetRef ref) async {
  if (_kShotCapture) return;
  if (ref.read(sessionProvider).user == null) return;
  final books = ref.read(booksProvider).value;
  if (books == null) return;
  final quotes = ref.read(quotesControllerProvider).value ?? const <Quote>[];
  await spotlightIndex.syncLibrary(books: books, quotes: quotes);
}

class _Gate extends ConsumerStatefulWidget {
  const _Gate();
  @override
  ConsumerState<_Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<_Gate> with WidgetsBindingObserver {
  bool _bootstrapping = true;
  String? _syncedNotificationsFor;
  String? _quickActionFor;
  bool _notificationsNeedSync = false;
  bool _retryNotificationPermissionRequest = false;
  Future<void>? _notificationSyncFuture;
  Timer? _notificationRetryTimer;
  int _notificationSyncFailures = 0;
  AppUser? _queuedNotificationSyncUser;
  bool _queuedNotificationPermissionRequest = false;

  /// Once-guard: stamp device intro for already-onboarded sessions without
  /// re-queueing a post-frame write on every Gate rebuild.
  bool _introStampScheduled = false;
  String? _resumedImportForUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      // Boot must NEVER hang on the splash: any failure here (a swallowed
      // plugin-channel error in a release build, a deep-link listener that
      // throws on cold start) must still let the gate advance to the
      // home tree. So each step is isolated and the flag flip lives in a
      // `finally`. Without this a single rejected future below would leave
      // `_bootstrapping` true forever → the "stuck on splash" symptom.
      try {
        try {
          await ref.read(sessionProvider.notifier).bootstrap();
        } catch (e, s) {
          debugPrint('session bootstrap failed: $e\n$s');
        }
      } finally {
        if (mounted) {
          setState(() => _bootstrapping = false);
          // Initial-link plugin calls and any link-triggered network work must
          // not hold the gate closed. getInitialLink preserves cold-start URLs.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _startDeepLinks(),
          );
        }
      }
    });
  }

  Future<void> _startDeepLinks() async {
    if (!mounted) return;
    try {
      ref.read(importDeepLinkProvider).attach();
      ref.read(widgetDeepLinkProvider).attach();
      ref.read(magicLinkDeepLinkProvider).attach();
      await ref.read(appDeepLinkHubProvider).start();
      await ref.read(importDeepLinkProvider).resume();
      await ref.read(widgetDeepLinkProvider).startPlatformExtras();
    } catch (e, s) {
      debugPrint('deep-link start failed: $e\n$s');
    }
  }

  @override
  void dispose() {
    _notificationRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Share Extension often fails to open the host URL. Drain App Group text
    // even when the composer waits for a session.
    // before opening the composer.
    unawaited(
      ref.read(widgetDeepLinkProvider).drainPendingShareIfAny().catchError((
        Object e,
      ) {
        debugPrint('share drain on resume failed: $e');
      }),
    );
    unawaited(
      maybeShowAppUpdatePrompt(
        context,
        ref,
        fromResume: true,
        settle: Duration.zero,
        stillVisible: () => mounted,
      ),
    );
    final user = ref.read(sessionProvider).user;
    if (user == null || user.onboardingCompletedAt == null) return;
    // Refresh only the visible root tab. Session keepAlive means invalidating
    // every list here would reload screens the user has not returned to.
    final tabIndex = ref.read(tabIndexProvider);
    for (final provider in mainTabDataProviders(tabIndex)) {
      ref.invalidate(provider);
    }
    // Progress may have changed while the app was backgrounded through the
    // interactive home-screen widget (or another device). Invalidate every
    // active per-book instance so detail/editor surfaces reload server truth.
    ref.invalidate(progressProvider);
    // Page activity can change outside the foreground app (native widget event
    // completion, another device). Invalidate without eagerly fetching so the
    // next statistics view cannot reuse a stale ledger window.
    ref.invalidatePersonalStats();
    // Reminder scheduling needs the wide events/books feeds. Defer it
    // until Home/Calendar is active, where those feeds are screen-owned.
    _notificationsNeedSync = true;
    _notificationSyncFailures = 0;
    _maybeSyncNotifications(user, tabIndex);
    // Best-effort: keep the home-screen widgets' token/summary/quotes fresh
    // whenever the app comes back to the foreground, same trigger as the
    // resyncs above.
    unawaited(
      syncWidget(ref).catchError((Object e) {
        debugPrint('syncWidget on resume failed: $e');
        return false;
      }),
    );
    unawaited(
      syncQuotesWidget(ref).catchError((Object e) {
        debugPrint('syncQuotesWidget on resume failed: $e');
      }),
    );
  }

  Future<void> _finishIntro() async {
    await ref.read(prefsStorageProvider).setIntroSeen();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Quote mutations bump a tick so Gate (not QuotesController) can push the
    // native widget snapshot. Using this WidgetRef avoids "cannot depend on
    // itself" when syncQuotesWidget reads quotesControllerProvider.
    ref.listen<int>(quotesMutationTickProvider, (previous, next) {
      if (previous == next) return;
      unawaited(syncQuotesWidget(ref));
      unawaited(_syncSpotlight(ref));
    });
    if (_bootstrapping) {
      return Scaffold(body: RdProgress.centered());
    }
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final prefs = ref.read(prefsStorageProvider);
    // Device-scoped welcome tour on first open. Local-guest bootstrap may already
    // mark profile onboarding complete (home, not registration); that must not
    // skip the carousel. Legacy cloud accounts and upgraded local profiles are
    // stamped without showing the tour (bootstrap or below).
    final introSeen = prefs.isIntroSeen();
    if (!introSeen) {
      final skipTourForLegacyAccount =
          user?.onboardingCompletedAt != null && user!.id != localGuestUserId;
      if (skipTourForLegacyAccount) {
        if (!_introStampScheduled) {
          _introStampScheduled = true;
          unawaited(_finishIntro());
        }
      } else {
        return OnboardingTourScreen(onFinish: () => unawaited(_finishIntro()));
      }
    }
    if (user == null) {
      return Scaffold(body: RdProgress.centered());
    }
    if (_resumedImportForUser != user.id) {
      _resumedImportForUser = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(importDeepLinkProvider).resume());
      });
    }
    if (user.termsVersion != currentTermsVersion) {
      return const LegalAcceptanceScreen();
    }
    if (!_kShotCapture && _syncedNotificationsFor != user.id) {
      _syncedNotificationsFor = user.id;
      _notificationsNeedSync = true;
      // Let Home finish its first books/events paint before reconciliation
      // reads the same providers (avoids a transient ErrorRetry on onboarding).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_queueNotificationSyncAfterHomeFeeds(user));
      });
    }
    ref.listen<int>(tabIndexProvider, (_, next) {
      _maybeSyncNotifications(user, next);
    });
    // OS app shortcuts (quote / progress / calendar): (re)registered per
    // user+locale so titles stay translated; taps feed the widget deep-link
    // pipeline.
    final quickActionKey = '${user.id}|${AppL10n.of(context).localeName}';
    if (_quickActionFor != quickActionKey) {
      _quickActionFor = quickActionKey;
      final l = AppL10n.of(context);
      Future.microtask(() async {
        try {
          await setupAppShortcuts(ref, l);
        } catch (e, s) {
          debugPrint('setupAppShortcuts failed: $e\n$s');
        }
      });
    }
    ref.listen<AsyncValue<List<Book>>>(booksProvider, (_, next) {
      if (next.hasValue) unawaited(_syncSpotlight(ref));
    });
    // NotificationTapHandler opens the event behind a tapped reminder.
    // WidgetDeepLinkHandler opens the book/event behind a tapped home-screen
    // widget row.
    return NotificationTapHandler(
      child: WidgetDeepLinkHandler(child: MainShell()),
    );
  }

  void _maybeSyncNotifications(AppUser user, int tabIndex) {
    if (_kShotCapture) return;
    if (!_notificationsNeedSync || (tabIndex != 0 && tabIndex != 2)) return;
    _queueNotificationSync(user);
  }

  /// Waits for the Home-owned feeds to settle, then arms the first reminder
  /// reconciliation for this session.
  Future<void> _queueNotificationSyncAfterHomeFeeds(AppUser user) async {
    if (_kShotCapture) return;
    if (!mounted || ref.read(sessionProvider).user?.id != user.id) return;
    final books = ref.read(booksProvider);
    if (!books.hasValue && books.isLoading) {
      try {
        await ref.read(booksProvider.future);
      } on Object {
        // Home owns book-list errors; sync proceeds with whatever settled.
      }
    }
    if (!mounted || ref.read(sessionProvider).user?.id != user.id) return;
    final events = ref.read(upcomingEventsProvider);
    if (!events.hasValue && events.isLoading) {
      try {
        await ref.read(upcomingEventsProvider.future);
      } on Object {
        // Same for the events feed.
      }
    }
    if (!mounted || ref.read(sessionProvider).user?.id != user.id) return;
    _queueNotificationSync(user, requestPermission: true);
  }

  void _queueNotificationSync(
    AppUser user, {
    bool requestPermission = false,
  }) {
    if (_kShotCapture) return;
    _retryNotificationPermissionRequest |= requestPermission;
    if (_notificationSyncFuture != null) {
      _notificationsNeedSync = true;
      _queuedNotificationSyncUser = user;
      _queuedNotificationPermissionRequest |= requestPermission;
      return;
    }
    _notificationRetryTimer?.cancel();
    _notificationRetryTimer = null;
    final shouldRequestPermission = _retryNotificationPermissionRequest;
    _retryNotificationPermissionRequest = false;
    _notificationsNeedSync = false;
    final future = _runNotificationSync(
      user,
      requestPermission: shouldRequestPermission,
    );
    _notificationSyncFuture = future;
    unawaited(future);
  }

  Future<void> _runNotificationSync(
    AppUser user, {
    required bool requestPermission,
  }) async {
    var failed = false;
    var retryable = false;
    try {
      await _syncNotifications(
        user,
        requestPermission: requestPermission,
      );
      _notificationSyncFailures = 0;
    } on Object catch (error, stackTrace) {
      failed = true;
      retryable = shouldRetryNotificationSync(error);
      _notificationsNeedSync = true;
      _retryNotificationPermissionRequest |= requestPermission;
      if (!retryable) {
        debugPrint(
          'Notification sync failed: '
          '${notificationSyncFailureSummary(error)}\n$stackTrace',
        );
      }
    } finally {
      final current = _notificationSyncFuture;
      if (current != null) _notificationSyncFuture = null;
      final queuedUser = _queuedNotificationSyncUser;
      final queuedPermission = _queuedNotificationPermissionRequest;
      _queuedNotificationSyncUser = null;
      _queuedNotificationPermissionRequest = false;
      final currentUser = mounted ? ref.read(sessionProvider).user : null;
      if (queuedUser != null && currentUser?.id == queuedUser.id) {
        // An account switch or explicit follow-up queued while this run was in
        // flight must not be subject to root-tab deferral.
        _notificationsNeedSync = false;
        _queueNotificationSync(
          currentUser!,
          requestPermission: queuedPermission,
        );
      } else if (mounted && _notificationsNeedSync && (!failed || retryable)) {
        // Authz/validation keep `_notificationsNeedSync` for a later resume
        // instead of polling. Transient failures back off and retry.
        final delay = failed
            ? notificationSyncRetryDelay(++_notificationSyncFailures)
            : Duration.zero;
        _notificationRetryTimer?.cancel();
        _notificationRetryTimer = Timer(delay, () {
          if (!mounted) return;
          final currentUser = ref.read(sessionProvider).user;
          if (currentUser == null ||
              currentUser.onboardingCompletedAt == null) {
            return;
          }
          if (failed) {
            // A failed initial sync must retry even when a deep link or
            // settings flow currently has another tab selected.
            _queueNotificationSync(currentUser);
          } else {
            _maybeSyncNotifications(currentUser, ref.read(tabIndexProvider));
          }
        });
      }
    }
  }

  Future<void> _syncNotifications(
    AppUser user, {
    bool requestPermission = false,
  }) async {
    // Replay any "Complete" queued by the notification background isolate BEFORE
    // rescheduling, so a just-completed event isn't re-armed. `drainAndNotify`
    // is coalesced, so overlapping with the tap handler's drain is harmless.
    if (!mounted) return;
    await drainAndNotify(ref, context, user);
    if (!mounted || ref.read(sessionProvider).user?.id != user.id) return;
    final l = AppL10n.of(context);
    await resyncLocalNotifications(
      ref,
      l,
      user,
      requestPermission: requestPermission,
    );
    // Independent of the reminder resync (which no longer touches quote
    // notifications): (re)arm the daily quote-of-the-day window on each
    // bootstrap/resume so its content + hour stay current.
    if (!mounted || ref.read(sessionProvider).user?.id != user.id) return;
    await resyncDailyQuoteNotifications(
      ref,
      l,
      user,
      requestPermission: requestPermission,
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final List<int> _tabHistory = [0];
  final Set<int> _visitedTabs = {0};
  bool _restoringPreviousTab = false;

  /// One root-tab stay per activation. Soft in-app feedback may follow.
  int? _appVisitCountedForTab;

  @override
  void initState() {
    super.initState();
    // Keep the Profile activation result warm, but only after Home
    // has painted. It must not contend with the first visible tab's data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRecordAppVisit();
    });
  }

  void _recordTab(int tab) {
    if (tab == 0) {
      _tabHistory
        ..clear()
        ..add(0);
      return;
    }
    if (_tabHistory.last == tab) return;
    // Home stays the fixed root; keep one entry per other destination while
    // preserving recency so tab cycles cannot grow the stack forever.
    _tabHistory
      ..remove(tab)
      ..add(tab);
  }

  void _handleRootBack(bool didPop, int currentTab) {
    if (didPop) return;
    if (_tabHistory.length > 1) {
      _tabHistory.removeLast();
      final previousTab = _tabHistory.last;
      if (previousTab != currentTab) {
        _restoringPreviousTab = true;
        ref.read(tabIndexProvider.notifier).state = previousTab;
      }
      return;
    }
    // Defensive fallback for a shell first built on a non-home tab.
    if (currentTab != 0) {
      _tabHistory
        ..clear()
        ..add(0);
      _restoringPreviousTab = true;
      ref.read(tabIndexProvider.notifier).state = 0;
    }
  }

  /// Count a root-tab stay once that tab is visible. Soft feedback may follow
  /// after a settle delay if the user has used the app a little.
  void _maybeRecordAppVisit() {
    if (!mounted) return;
    final tab = ref.read(tabIndexProvider);
    if (_appVisitCountedForTab == tab) return;
    _appVisitCountedForTab = tab;
    unawaited(
      recordAppVisitAndMaybePrompt(
        context,
        ref,
        stillVisible: () => mounted && ref.read(tabIndexProvider) == tab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // Feedback activation is prefetched after the first Home frame in initState.
    // Each data tab is wrapped so re-entering it triggers a silent background
    // refetch of the lists it shows; the cached data (kept warm for the session)
    // stays on screen meanwhile — no loading spinner on return. See
    // `RevalidateOnEnter` and `_cacheWhileLoggedIn` in `di/providers.dart`.
    // Tab index lives in `tabIndexProvider` (not local state) so flows pushed
    // above the shell — e.g. the finish-book celebration's "Go to my library" —
    // can select a tab. Clamp defends against a stale out-of-range value.
    const tabCount = 4;
    final idx = ref.watch(tabIndexProvider).clamp(0, tabCount - 1);
    _visitedTabs.add(idx);
    final screens = <Widget>[
      if (_visitedTabs.contains(0))
        RevalidateOnEnter(
          providers: mainTabDataProviders(0),
          active: idx == 0,
          child: const HomeScreen(),
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(1))
        RevalidateOnEnter(
          providers: mainTabDataProviders(1),
          active: idx == 1,
          child: const LibraryScreen(),
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(2))
        RevalidateOnEnter(
          providers: mainTabDataProviders(2),
          active: idx == 2,
          child: const CalendarScreen(),
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(3))
        const ProfileScreen()
      else
        const SizedBox.shrink(),
    ];
    _recordTab(idx);
    final showCalendarDot = ref.watch(shellCalendarNovedadesDotProvider);
    // Opening the Calendar tab (however it's reached: nav bar, deep link, plan
    // flow, notification tap) acknowledges the current "novedades" and
    // clears the dot. Local-only; per-event "Nuevo/Modificado" badges still
    // clear via backend markSeen when their detail is opened.
    ref.listen<int>(tabIndexProvider, (_, next) {
      final tab = next.clamp(0, screens.length - 1);
      if (_restoringPreviousTab) {
        _restoringPreviousTab = false;
      } else {
        _recordTab(tab);
      }
      if (next == 2) {
        ref.read(calendarSeenAtProvider.notifier).markSeenNow();
      }
      _maybeRecordAppVisit();
      AppPerformanceMonitor.instance.startRootTabTransition(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppPerformanceMonitor.instance.markRootTabFirstFrame(next);
      });
    });
    final shell = Scaffold(
      // Let body paint under the floating nav pill (glass on Apple, Material
      // on Android) so content scrolls behind and blur/elevation read correctly.
      extendBody: true,
      body: ReadendarTabSwitcher.indexed(
        index: idx,
        visited: _visitedTabs,
        // Root destinations are retained pages rather than routes, so
        // use the shared short fade in the switcher itself.
        children: screens,
      ),
      bottomNavigationBar: RdRootNavBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          unawaited(RdHaptics.selection());
          ref.read(tabIndexProvider.notifier).state = i;
        },
        destinations: [
          RdNavDestination(
            icon: const Icon(LucideIcons.home),
            label: l.navHome,
          ),
          RdNavDestination(
            icon: const Icon(LucideIcons.book),
            label: l.navLibrary,
          ),
          RdNavDestination(
            icon: _calendarNavIcon(
              showDot: showCalendarDot,
              accent: context.colors.accent,
            ),
            label: l.navCalendar,
          ),
          RdNavDestination(
            icon: const Icon(LucideIcons.user),
            label: l.navYou,
          ),
        ],
      ),
    );
    return PopScope(
      // Pushed routes remain above this root route and pop normally. At the
      // root, Back walks the root-tab history; only Home with no earlier root
      // destination left is allowed to bubble to Android and close the app.
      canPop: idx == 0 && _tabHistory.length == 1,
      onPopInvokedWithResult: (didPop, _) => _handleRootBack(didPop, idx),
      child: shell,
    );
  }
}

/// Unread / novedades dot inset on the glyph (not Material [Badge] — that
/// drifts onto the destination label under the compact root-nav layout).
Widget _rootNavIconDot({required Key key, required Color accent}) {
  return Positioned(
    key: key,
    // Positive inset keeps the circle on the icon, clear of the label below.
    right: 2,
    bottom: 2,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 8),
    ),
  );
}

Widget _calendarNavIcon({required bool showDot, required Color accent}) {
  return Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      const Icon(LucideIcons.calendar),
      if (showDot)
        _rootNavIconDot(
          key: const Key('calendarNavNovedadesDot'),
          accent: accent,
        ),
    ],
  );
}
