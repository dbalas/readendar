import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appDirectory = Directory.current.path.endsWith('/app')
      ? Directory.current
      : Directory('${Directory.current.path}/app');

  String source(String path) =>
      File('${appDirectory.path}/$path').readAsStringSync();

  test(
    'Android omits hosted book-share App Links; magic links stay custom-scheme',
    () {
      final manifest = source('android/app/src/main/AndroidManifest.xml');
      final filters = RegExp(
        r'<intent-filter android:autoVerify="true">([\s\S]*?)</intent-filter>',
      ).allMatches(manifest).map((m) => m.group(1)!).toList();

      expect(filters, isEmpty);
      expect(manifest, contains('android:scheme="readendar"'));
      expect(manifest, isNot(contains('android:pathPrefix="/b/"')));
      expect(manifest, isNot(contains('android:pathPrefix="/auth/m/"')));
      expect(manifest, isNot(contains('android:pathPrefix="/c/"')));
      expect(manifest, isNot(contains('android:pathPrefix="/u/"')));
      expect(manifest, isNot(contains('/social-intent/')));
    },
  );

  test(
    'Android pin success callback is mutable so the OS can fill the widget id',
    () {
      final kotlin = source(
        'android/app/src/main/kotlin/com/readendar/readendar/MainActivity.kt',
      );
      expect(kotlin, contains('PendingIntent.FLAG_MUTABLE'));
      expect(
        kotlin,
        isNot(
          contains(
            'PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE',
          ),
        ),
      );
      expect(kotlin, contains('"quotes" -> 2'));
      expect(kotlin, contains('"progress" -> 1'));
    },
  );

  test(
    'Android progress widget defaults to a 4x3 cell so progress fits',
    () {
      final info = source(
        'android/app/src/main/res/xml/readendar_progress_widget_info.xml',
      );
      expect(info, contains('android:targetCellWidth="4"'));
      expect(info, contains('android:targetCellHeight="3"'));
      expect(info, contains('android:minHeight="180dp"'));
      expect(info, contains('android:minResizeHeight="110dp"'));
    },
  );

  test(
    'Android widget picker exposes a distinct localized name per widget',
    () {
      final manifest = source('android/app/src/main/AndroidManifest.xml');

      expect(
        manifest,
        contains(
          'android:name=".ReadendarWidgetProvider"\n'
          '            android:label="@string/widget_events_name"',
        ),
      );
      expect(
        manifest,
        contains(
          'android:name=".ReadendarQuotesWidgetProvider"\n'
          '            android:label="@string/widget_quotes_name"',
        ),
      );
      expect(
        manifest,
        contains(
          'android:name=".ReadendarProgressWidgetProvider"\n'
          '            android:label="@string/widget_progress_name"',
        ),
      );

      final catalogs =
          Directory('${appDirectory.path}/android/app/src/main/res')
              .listSync()
              .whereType<Directory>()
              .where(
                (directory) =>
                    directory.path.split('/').last.startsWith('values'),
              )
              .map((directory) => File('${directory.path}/strings.xml'))
              .where((file) => file.existsSync());

      for (final catalog in catalogs) {
        final strings = catalog.readAsStringSync();
        expect(strings, contains('name="widget_events_name"'));
        expect(strings, contains('name="widget_quotes_name"'));
        expect(strings, contains('name="widget_progress_name"'));
      }
    },
  );

  test('iOS widget tokens share a device-only Keychain access group', () {
    final keychain = source('ios/ReadendarWidget/WidgetKeychain.swift');
    expect(
      keychain,
      contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'),
    );
    expect(keychain, contains('group.com.readendar.readendar'));
    expect(keychain, contains('wdg_access'));
    expect(keychain, contains('wdg_refresh'));

    final pbx = source('ios/Runner.xcodeproj/project.pbxproj');
    expect(pbx, contains('WidgetKeychain.swift in Sources'));
    expect(
      pbx.split('WidgetKeychain.swift in Sources').length,
      greaterThan(2),
      reason:
          'Runner and widget targets must both compile WidgetKeychain.swift',
    );

    final host = source('ios/Runner/AppDelegate.swift');
    expect(host, contains('readendar/widget_secrets'));
    expect(host, contains('WidgetKeychain.writeTokens'));
    expect(host, contains('WidgetKeychain.clearTokens()'));
    expect(host, contains('WidgetKeychain.read("wdg_access")'));
    expect(host, contains('"flushDefaults"'));
    expect(host, contains('"clearShared"'));
    expect(host, contains(r'flutter.\(key)'));
    expect(keychain, contains('func writeTokens(access:'));
    expect(
      keychain,
      contains('guard accessGroup != nil else { return false }'),
    );
    expect(keychain, contains('restore("wdg_access"'));
    expect(
      keychain,
      contains('guard accessGone && refreshGone else { return false }'),
      reason: 'clearTokens must not scrub defaults until both deletes succeed',
    );

    final widgets = source('ios/ReadendarWidget/ReadendarWidget.swift');
    expect(widgets, contains('setSecrets(access:'));
    expect(widgets, contains('WidgetKeychain.writeTokens'));
    expect(widgets, contains(r'flutter.\(key)'));
    expect(widgets, contains('secretPair()?.access'));
    expect(widgets, contains('guard setSecrets(access:'));
    final setShared = widgets.substring(
      widgets.indexOf('private func setShared'),
      widgets.indexOf('private func removeShared'),
    );
    expect(
      setShared,
      isNot(contains('forKey: "flutter.')),
      reason: 'new writes must stay unprefixed so Dart nulls cannot miss them',
    );
    expect(setShared, contains('synchronize()'));
    final removeShared = widgets.substring(
      widgets.indexOf('private func removeShared'),
      widgets.indexOf('/// Access+refresh'),
    );
    expect(removeShared, contains(r'flutter.\(key)'));
    expect(removeShared, contains('synchronize()'));
    expect(
      widgets,
      isNot(contains('setSecret(Keys.access')),
      reason: 'TokenRotator must persist access+refresh as one pair',
    );
  });

  test('iOS widget gallery exposes localized names for every widget', () {
    final events = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final quotes = source('ios/ReadendarWidget/ReadendarQuotesWidget.swift');

    expect(
      events,
      contains('.configurationDisplayName(Text(loc("events_widget_name")))'),
    );
    expect(
      events,
      contains('.configurationDisplayName(Text(loc("progress_widget_name")))'),
    );
    expect(events, contains('"events_widget_name": ['));
    expect(events, contains('"progress_widget_name": ['));

    expect(
      quotes,
      contains(
        '.configurationDisplayName(Text(quotesLoc("quotes_widget_name")))',
      ),
    );
    expect(quotes, contains('"quotes_widget_name": ['));
  });

  test('iOS widgets advertise Medium/Large families that fit without clipping', () {
    final events = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final quotes = source('ios/ReadendarWidget/ReadendarQuotesWidget.swift');

    // Events: family-sized prefix under a fixed header. Home Screen widgets
    // cannot scroll; a vertical scroll view renders as a giant prohibited icon.
    final mediumView = events.substring(
      events.indexOf('struct MediumView: View'),
      events.indexOf('/// "See more in calendar"'),
    );
    expect(mediumView, isNot(contains('ScrollView')));
    expect(mediumView, isNot(contains('LazyVStack')));
    expect(mediumView, contains('visibleEventLimit'));
    expect(mediumView, contains('family == .systemLarge ? 4 : 2'));
    expect(mediumView, contains('MoreFooter()'));
    expect(mediumView, contains('.layoutPriority(2)'));
    expect(
      mediumView,
      contains('.fixedSize(horizontal: false, vertical: true)'),
    );
    expect(
      events,
      contains(
        '.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)',
      ),
    );
    expect(
      events,
      contains(
        'return [.systemMedium, .systemLarge, .systemSmall, .accessoryRectangular, .accessoryCircular]',
      ),
    );
    // Small uses a compact wordmark so ~155pt cells stay legible.
    expect(events, contains('BrandWordmark(size: 11, tracking: 0.9)'));
    // Complete-toggle stays a sibling of the row Link with a larger tap target.
    expect(events, contains('.frame(width: 36, height: 36)'));

    // Progress can grow to Large (was Medium-only).
    expect(
      events,
      contains('.supportedFamilies([.systemMedium, .systemLarge])'),
    );

    // Quotes: Medium default + Large for long text; Small kept.
    expect(
      quotes,
      contains(
        '.supportedFamilies([.systemMedium, .systemLarge, .systemSmall])',
      ),
    );
    expect(quotes, contains('quoteLineLimit'));
    // Vertically center the quote in leftover space (Android center_vertical).
    expect(
      quotes,
      contains(
        '.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)',
      ),
    );
  });

  test(
    'iOS entitlements keep App Group; host files keep Sign in with Apple',
    () {
      const group = 'group.com.readendar.readendar';
      const appGroupKey = 'com.apple.security.application-groups';
      const siwaKey = 'com.apple.developer.applesignin';

      for (final path in [
        'ios/Runner/Runner.free-team.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.free-team.entitlements',
        'ios/Runner/Runner.siwa-debug.entitlements',
        'ios/Runner/Runner.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.entitlements',
      ]) {
        final xml = source(path);
        expect(xml, contains(appGroupKey), reason: path);
        expect(xml, contains(group), reason: path);
      }

      for (final path in [
        'ios/Runner/Runner.entitlements',
        'ios/Runner/Runner.siwa-debug.entitlements',
      ]) {
        expect(source(path), contains(siwaKey), reason: path);
      }
      for (final path in [
        'ios/Runner/Runner.free-team.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.free-team.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.entitlements',
      ]) {
        expect(source(path), isNot(contains(siwaKey)), reason: path);
      }

      const keychainGroup = 'keychain-access-groups';
      for (final path in [
        'ios/Runner/Runner.entitlements',
        'ios/Runner/Runner.siwa-debug.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.entitlements',
      ]) {
        final xml = source(path);
        expect(xml, contains(keychainGroup), reason: path);
        expect(
          xml,
          contains(r'$(AppIdentifierPrefix)group.com.readendar.readendar'),
          reason: path,
        );
      }
      for (final path in [
        'ios/Runner/Runner.free-team.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.free-team.entitlements',
      ]) {
        expect(
          source(path),
          isNot(contains(keychainGroup)),
          reason: path,
        );
      }

      // Push / Associated Domains stay off Debug/Profile files so an incomplete
      // provisioning profile cannot SIGKILL the host on launch.
      for (final path in [
        'ios/Runner/Runner.free-team.entitlements',
        'ios/Runner/Runner.siwa-debug.entitlements',
        'ios/ReadendarWidget/ReadendarWidget.free-team.entitlements',
      ]) {
        final xml = source(path);
        expect(
          xml,
          isNot(contains('<key>aps-environment</key>')),
          reason: path,
        );
        expect(
          xml,
          isNot(contains('<key>com.apple.developer.associated-domains</key>')),
          reason: path,
        );
      }

      final releaseEntitlements = source('ios/Runner/Runner.entitlements');
      expect(
        releaseEntitlements,
        contains('<key>com.apple.developer.associated-domains</key>'),
      );
      expect(releaseEntitlements, isNot(contains('<key>aps-environment</key>')));

      final pbx = source('ios/Runner.xcodeproj/project.pbxproj');
      final runnerConfigs = RegExp(
        r'CODE_SIGN_ENTITLEMENTS = "?Runner/Runner(?:\.free-team|\.siwa-debug)?\.entitlements"?;[\s\S]*?name = (Debug|Release|Profile);',
      ).allMatches(pbx).toList();
      expect(runnerConfigs.length, greaterThanOrEqualTo(3));
      for (final block in runnerConfigs) {
        final name = block.group(1)!;
        final body = block.group(0)!;
        if (name == 'Release') {
          expect(body, contains('Runner/Runner.entitlements'));
        } else {
          // Debug/Profile support both local free-team signing and a paid-team
          // App Group profile. Both entitlement files were validated above.
          expect(
            body.contains('Runner/Runner.free-team.entitlements') ||
                body.contains('Runner/Runner.siwa-debug.entitlements'),
            isTrue,
            reason: '$name must use a debug-safe entitlement set',
          );
        }
      }
    },
  );

  test('iOS widget target disables debug dylib (gallery crash workaround)', () {
    // Xcode 16+ defaults ENABLE_DEBUG_DYLIB=YES; that layout crashes WidgetKit
    // extensions (XPC_EXIT_REASON_FAULT) so Readendar vanishes from Add Widget.
    final pbx = source('ios/Runner.xcodeproj/project.pbxproj');
    final widgetConfigs = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = "?ReadendarWidget/ReadendarWidget(?:\.free-team)?\.entitlements"?;[\s\S]*?name = (Debug|Release|Profile);',
    ).allMatches(pbx).toList();
    expect(widgetConfigs.length, greaterThanOrEqualTo(3));
    for (final block in widgetConfigs) {
      expect(
        block.group(0),
        contains('ENABLE_DEBUG_DYLIB = NO;'),
        reason: 'ReadendarWidget ${block.group(1)}',
      );
    }
  });

  test('iOS Runner resigns widget + host Simulated entitlements on simulator', () {
    // Xcode signs with empty .xcent; real App Group keys live in *-Simulated.xcent.
    // Appex gets full Simulated. Host gets App-Group-only over Runner.app.xcent
    // so post-script CodeSign keeps sync without SB launch denial.
    final script = source('ios/resign_widget_simulator_entitlements.sh');
    expect(script, contains('ReadendarWidget.appex-Simulated.xcent'));
    expect(script, contains('Runner.app-Simulated.xcent'));
    expect(script, contains('Runner.app.xcent'));
    expect(script, contains('App-Group-only'));
    expect(script, contains('iphonesimulator'));
    expect(script, contains('codesign'));

    final pbx = source('ios/Runner.xcodeproj/project.pbxproj');
    expect(pbx, contains('Resign Widget Simulator Entitlements'));
    expect(pbx, contains('resign_widget_simulator_entitlements.sh'));
  });

  test('iOS Info.plist allows system appearance and local networking', () {
    final plist = source('ios/Runner/Info.plist');
    // Forced Light breaks Flutter dark/system theme parity on iOS chrome.
    expect(plist, isNot(contains('<key>UIUserInterfaceStyle</key>')));
    expect(plist, contains('<key>NSAllowsLocalNetworking</key>'));
    expect(plist, contains('<key>NSAppTransportSecurity</key>'));
  });

  test(
    'iOS Podfile enables permission_handler macros used by Info.plist',
    () {
      final podfile = source('ios/Podfile');
      expect(podfile, contains('PERMISSION_CAMERA=1'));
      expect(podfile, contains('PERMISSION_MICROPHONE=1'));
      expect(podfile, contains('PERMISSION_SPEECH_RECOGNIZER=1'));
    },
  );

  test('iOS progress widget follows the app light/dark override', () {
    final widgets = source('ios/ReadendarWidget/ReadendarWidget.swift');
    final progressStart = widgets.indexOf(
      'private struct ReadendarProgressEntryView: View',
    );
    final progressEnd = widgets.indexOf(
      'private struct ProgressKeyButtonStyle',
      progressStart,
    );

    expect(progressStart, greaterThanOrEqualTo(0));
    expect(progressEnd, greaterThan(progressStart));
    final progressView = widgets.substring(progressStart, progressEnd);
    expect(
      progressView,
      contains(
        '.modifier(PreferredColorSchemeModifier(scheme: preferredWidgetScheme()))',
      ),
    );
    expect(
      widgets,
      contains('switch shared(Keys.theme)'),
    );
  });

  test(
    'Android events widget embeds RemoteCollectionItems on API 31+',
    () {
      // notifyAppWidgetViewDataChanged + Intent remote adapters NPE on
      // Android 15/16 (replaceRemoteCollections on null getAppWidgetViews).
      // API 31+ must parcel RemoteCollectionItems and only call notify on the
      // pre-31 Intent-adapter branch.
      final kotlin = source(
        'android/app/src/main/kotlin/com/readendar/readendar/ReadendarWidgetProvider.kt',
      );
      expect(kotlin, contains('RemoteViews.RemoteCollectionItems.Builder()'));
      expect(kotlin, contains('Build.VERSION_CODES.S'));
      expect(
        kotlin,
        contains('mgr.notifyAppWidgetViewDataChanged(id, R.id.wdg_event_list)'),
      );
      // notify must stay inside the pre-31 else branch, not after a shared update.
      final notifyIndex = kotlin.indexOf(
        'mgr.notifyAppWidgetViewDataChanged(id, R.id.wdg_event_list)',
      );
      final collectionIndex = kotlin.indexOf(
        'RemoteViews.RemoteCollectionItems.Builder()',
      );
      final elseIndex = kotlin.lastIndexOf('} else {', notifyIndex);
      expect(collectionIndex, greaterThan(-1));
      expect(notifyIndex, greaterThan(collectionIndex));
      expect(elseIndex, greaterThan(collectionIndex));
      expect(elseIndex, lessThan(notifyIndex));
    },
  );

  test(
    'quotes widget appearance styles stay in lockstep across Dart, Swift, and Kotlin',
    () {
      const styles = [
        'parchment',
        'mist',
        'pine',
        'honey',
        'noirGold',
      ];
      final dart = source('lib/core/models/widget_models.dart');
      final preview = source('lib/features/widget/quotes_widget_preview.dart');
      final swift = source('ios/ReadendarWidget/ReadendarQuotesWidget.swift');
      final kotlin = source(
        'android/app/src/main/kotlin/com/readendar/readendar/ReadendarQuotesWidgetProvider.kt',
      );
      for (final style in styles) {
        expect(dart, contains("$style('$style')"));
        expect(
          preview,
          contains('QuoteWidgetStyle.$style => QuoteCardStyle.$style'),
        );
        expect(swift, contains('case .$style:'));
        expect(kotlin, contains('"$style"'));
      }
    },
  );

  test(
    'iOS ProMotion VSync guards cover keyboard hide, not only cold start',
    () {
      final host = source('ios/Runner/AppDelegate.swift');
      expect(host, contains('rd_installProMotionVSyncGuards'));
      expect(host, contains('createTouchRateCorrectionVSyncClientIfNeeded'));
      expect(host, contains('setUpKeyboardAnimationVsyncClient:'));
      final scene = source('ios/Runner/SceneDelegate.swift');
      expect(scene, contains('if window != nil'));
      expect(scene, contains('engine.viewController == nil'));
    },
  );
}
