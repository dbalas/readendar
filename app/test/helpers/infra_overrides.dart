import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory prefs + [LocalStore] for widget tests that touch API repos.
class TestInfra {
  TestInfra._(this.prefs, this.store, this._rootDir);

  final SharedPreferences prefs;
  final LocalStore store;
  final Directory _rootDir;

  static Future<TestInfra> create({
    String prefix = 'readendar-test',
    Map<String, Object> preferenceValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferenceValues);
    final prefs = await SharedPreferences.getInstance();
    final root = Directory.systemTemp.createTempSync(prefix);
    final store = LocalStore.memory(
      Directory('${root.path}/covers')..createSync(),
    );
    return TestInfra._(prefs, store, root);
  }

  void dispose() {
    if (_rootDir.existsSync()) {
      _rootDir.deleteSync(recursive: true);
    }
  }

  List<Override> get baseOverrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    localStoreProvider.overrideWithValue(store),
  ];

  List<Override> combine(List<Override> more) => [...baseOverrides, ...more];
}
