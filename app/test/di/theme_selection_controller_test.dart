import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/di/theme_selection.dart';

void main() {
  test(
    'successful selection exposes pending state and syncs widgets',
    () async {
      final persistence = Completer<bool>();
      final synced = <ReadendarThemeId>[];
      final controller = ThemeSelectionController(
        selectedTheme: () => ReadendarThemeId.original,
        persist: (theme) => persistence.future,
        syncWidgets: (theme) async {
          synced.add(theme);
          return true;
        },
      );

      final operation = controller.select(ReadendarThemeId.jade);
      expect(controller.state.pendingTheme, ReadendarThemeId.jade);
      persistence.complete(true);

      expect(await operation, ThemeSelectionOutcome.applied);
      expect(synced, [ReadendarThemeId.jade]);
      expect(controller.state.isSaving, isFalse);
    },
  );

  test(
    'persistence failure is reported and skips native synchronization',
    () async {
      var syncCalls = 0;
      final controller = ThemeSelectionController(
        selectedTheme: () => ReadendarThemeId.original,
        persist: (_) async => false,
        syncWidgets: (_) async {
          syncCalls++;
          return true;
        },
      );

      expect(
        await controller.select(ReadendarThemeId.celestial),
        ThemeSelectionOutcome.failed,
      );
      expect(syncCalls, 0);
      expect(controller.state.isSaving, isFalse);
    },
  );

  test(
    'native synchronization failure preserves selection with warning',
    () async {
      final controller = ThemeSelectionController(
        selectedTheme: () => ReadendarThemeId.original,
        persist: (_) async => true,
        syncWidgets: (_) async => false,
      );

      expect(
        await controller.select(ReadendarThemeId.aurora),
        ThemeSelectionOutcome.appliedWithWidgetWarning,
      );
    },
  );

  test('repeated or already-selected submissions are ignored', () async {
    final persistence = Completer<bool>();
    var writes = 0;
    final controller = ThemeSelectionController(
      selectedTheme: () => ReadendarThemeId.original,
      persist: (_) {
        writes++;
        return persistence.future;
      },
      syncWidgets: (_) async => true,
    );

    expect(
      await controller.select(ReadendarThemeId.original),
      ThemeSelectionOutcome.unchanged,
    );
    final first = controller.select(ReadendarThemeId.noir);
    expect(
      await controller.select(ReadendarThemeId.sapphire),
      ThemeSelectionOutcome.unchanged,
    );
    persistence.complete(true);
    expect(await first, ThemeSelectionOutcome.applied);
    expect(writes, 1);
  });

  test(
    'premium selection is rejected before persistence when not entitled',
    () async {
      var writes = 0;
      final controller = ThemeSelectionController(
        selectedTheme: () => ReadendarThemeId.original,
        canSelect: (_) => false,
        persist: (_) async {
          writes++;
          return true;
        },
        syncWidgets: (_) async => true,
      );

      expect(
        await controller.select(ReadendarThemeId.ethereal),
        ThemeSelectionOutcome.notEntitled,
      );
      expect(writes, 0);
      expect(controller.state.isSaving, isFalse);
    },
  );

  test(
    'entitlement loss during persistence skips native premium propagation',
    () async {
      var entitled = true;
      final persistence = Completer<bool>();
      var syncCalls = 0;
      final controller = ThemeSelectionController(
        selectedTheme: () => ReadendarThemeId.original,
        canSelect: (_) => entitled,
        persist: (_) => persistence.future,
        syncWidgets: (_) async {
          syncCalls++;
          return true;
        },
      );

      final operation = controller.select(ReadendarThemeId.ethereal);
      entitled = false;
      persistence.complete(true);

      expect(await operation, ThemeSelectionOutcome.notEntitled);
      expect(syncCalls, 0);
      expect(controller.state.isSaving, isFalse);
    },
  );
}
