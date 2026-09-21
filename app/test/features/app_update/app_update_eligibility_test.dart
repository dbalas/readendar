import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/store/store_urls.dart';
import 'package:readendar/features/app_update/app_update_eligibility.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';
import 'package:readendar/features/app_update/app_update_play.dart';

void main() {
  const lookup = ItunesLookupResult(
    version: '1.1.7',
    releaseNotes: 'Notes for 1.1.7',
    trackViewUrl: 'https://apps.apple.com/app/id1',
  );

  test('iOS prompts when lookup version is newer', () {
    final offer = decideAppUpdate(
      platform: TargetPlatform.iOS,
      installedVersion: '1.1.6',
      play: PlayUpdateInfo.unavailable,
      lookup: lookup,
      snoozedToken: null,
    );
    expect(offer?.snoozeToken, '1.1.7');
    expect(offer?.releaseNotes, 'Notes for 1.1.7');
    expect(offer?.updateUri.toString(), 'https://apps.apple.com/app/id1');
  });

  test('iOS stays silent when lookup is missing or not newer', () {
    expect(
      decideAppUpdate(
        platform: TargetPlatform.iOS,
        installedVersion: '1.1.7',
        play: PlayUpdateInfo.unavailable,
        lookup: lookup,
        snoozedToken: null,
      ),
      isNull,
    );
    expect(
      decideAppUpdate(
        platform: TargetPlatform.iOS,
        installedVersion: '1.1.6',
        play: PlayUpdateInfo.unavailable,
        lookup: null,
        snoozedToken: null,
      ),
      isNull,
    );
  });

  test('iOS falls back to the App Store search URL without trackViewUrl', () {
    final offer = decideAppUpdate(
      platform: TargetPlatform.iOS,
      installedVersion: '1.0.0',
      play: PlayUpdateInfo.unavailable,
      lookup: const ItunesLookupResult(version: '1.1.0'),
      snoozedToken: null,
    );
    expect(offer?.updateUri.toString(), appStoreSearchUrl);
  });

  test('iOS discards untrusted trackViewUrl hosts', () {
    final offer = decideAppUpdate(
      platform: TargetPlatform.iOS,
      installedVersion: '1.0.0',
      play: PlayUpdateInfo.unavailable,
      lookup: const ItunesLookupResult(
        version: '1.1.0',
        trackViewUrl: 'https://evil.example/app',
      ),
      snoozedToken: null,
    );
    expect(offer?.updateUri.toString(), appStoreSearchUrl);
    expect(isTrustedAppStoreUri(Uri.parse('https://apps.apple.com/app/id1')), isTrue);
    expect(isTrustedAppStoreUri(Uri.parse('https://itunes.apple.com/app/id1')), isTrue);
    expect(isTrustedAppStoreUri(Uri.parse('http://apps.apple.com/app/id1')), isFalse);
    expect(
      isTrustedAppStoreUri(Uri.parse('https://apps.apple.com.evil.example/app')),
      isFalse,
    );
  });

  test('untrusted storefront language uses generic notes', () {
    final ios = decideAppUpdate(
      platform: TargetPlatform.iOS,
      installedVersion: '1.0.0',
      play: PlayUpdateInfo.unavailable,
      lookup: lookup,
      snoozedToken: null,
      lookupNotesTrusted: false,
    );
    expect(ios?.releaseNotes, isNull);
    expect(ios?.snoozeToken, '1.1.7');

    final android = decideAppUpdate(
      platform: TargetPlatform.android,
      installedVersion: '1.1.6',
      play: const PlayUpdateInfo(available: true, availableVersionCode: 10),
      lookup: lookup,
      snoozedToken: null,
      lookupNotesTrusted: false,
    );
    expect(android?.releaseNotes, isNull);
    expect(android?.snoozeToken, '1.1.7');
  });

  test('iOS snoozes the lookup version', () {
    expect(
      decideAppUpdate(
        platform: TargetPlatform.iOS,
        installedVersion: '1.1.6',
        play: PlayUpdateInfo.unavailable,
        lookup: lookup,
        snoozedToken: '1.1.7',
      ),
      isNull,
    );
  });

  test('Android requires Play availability', () {
    expect(
      decideAppUpdate(
        platform: TargetPlatform.android,
        installedVersion: '1.1.6',
        play: PlayUpdateInfo.unavailable,
        lookup: lookup,
        snoozedToken: null,
      ),
      isNull,
    );
  });

  test('Android uses lookup notes when App Store version is also newer', () {
    final offer = decideAppUpdate(
      platform: TargetPlatform.android,
      installedVersion: '1.1.6',
      play: const PlayUpdateInfo(available: true, availableVersionCode: 10),
      lookup: lookup,
      snoozedToken: null,
    );
    expect(offer?.releaseNotes, 'Notes for 1.1.7');
    expect(offer?.updateUri.toString(), googlePlayStoreUrl);
    expect(offer?.snoozeToken, '1.1.7');
  });

  test('Android Play-ahead uses generic notes and a version-code token', () {
    final offer = decideAppUpdate(
      platform: TargetPlatform.android,
      installedVersion: '1.1.6',
      play: const PlayUpdateInfo(available: true, availableVersionCode: 10),
      lookup: const ItunesLookupResult(version: '1.1.6'),
      snoozedToken: null,
    );
    expect(offer?.releaseNotes, isNull);
    expect(offer?.snoozeToken, 'play:10');
  });

  test('Android lookup failure after Play gate still offers a generic prompt', () {
    final offer = decideAppUpdate(
      platform: TargetPlatform.android,
      installedVersion: '1.1.6',
      play: const PlayUpdateInfo(available: true, availableVersionCode: 11),
      lookup: null,
      snoozedToken: null,
    );
    expect(offer?.releaseNotes, isNull);
    expect(offer?.snoozeToken, 'play:11');
  });

  test('Android snoozes the Play-ahead token', () {
    expect(
      decideAppUpdate(
        platform: TargetPlatform.android,
        installedVersion: '1.1.6',
        play: const PlayUpdateInfo(available: true, availableVersionCode: 10),
        lookup: const ItunesLookupResult(version: '1.1.6'),
        snoozedToken: 'play:10',
      ),
      isNull,
    );
  });
}
