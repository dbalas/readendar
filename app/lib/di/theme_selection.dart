import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';

enum ThemeSelectionOutcome {
  unchanged,
  applied,
  appliedWithWidgetWarning,
  failed,
  notEntitled,
}

class ThemeSelectionState {
  const ThemeSelectionState({this.pendingTheme});

  final ReadendarThemeId? pendingTheme;
  bool get isSaving => pendingTheme != null;
}

typedef ThemePreferenceWriter = Future<bool> Function(ReadendarThemeId theme);
typedef WidgetThemeWriter = Future<bool> Function(ReadendarThemeId theme);
typedef ThemeEntitlementChecker = bool Function(ReadendarThemeId theme);

bool _allowTheme(ReadendarThemeId _) => true;

final themePreferenceWriterProvider = Provider<ThemePreferenceWriter>(
  (ref) => ref.read(readendarThemeProvider.notifier).setTheme,
);

final widgetThemeWriterProvider = Provider<WidgetThemeWriter>(
  (ref) => pushWidgetAppTheme,
);

class ThemeSelectionController extends StateNotifier<ThemeSelectionState> {
  ThemeSelectionController({
    required this.selectedTheme,
    required this.persist,
    required this.syncWidgets,
    this.canSelect = _allowTheme,
  }) : super(const ThemeSelectionState());

  final ReadendarThemeId Function() selectedTheme;
  final ThemePreferenceWriter persist;
  final WidgetThemeWriter syncWidgets;
  final ThemeEntitlementChecker canSelect;

  Future<ThemeSelectionOutcome> select(ReadendarThemeId theme) async {
    if (!canSelect(theme)) return ThemeSelectionOutcome.notEntitled;
    if (state.isSaving || theme == selectedTheme()) {
      return ThemeSelectionOutcome.unchanged;
    }
    state = ThemeSelectionState(pendingTheme: theme);
    try {
      final bool saved;
      try {
        saved = await persist(theme);
      } catch (_) {
        return ThemeSelectionOutcome.failed;
      }
      if (!saved) return ThemeSelectionOutcome.failed;
      if (!canSelect(theme)) return ThemeSelectionOutcome.notEntitled;
      final bool widgetsUpdated;
      try {
        widgetsUpdated = await syncWidgets(theme);
      } catch (_) {
        return ThemeSelectionOutcome.appliedWithWidgetWarning;
      }
      return widgetsUpdated
          ? ThemeSelectionOutcome.applied
          : ThemeSelectionOutcome.appliedWithWidgetWarning;
    } finally {
      state = const ThemeSelectionState();
    }
  }
}

final StateNotifierProvider<ThemeSelectionController, ThemeSelectionState>
themeSelectionControllerProvider = StateNotifierProvider((ref) {
  return ThemeSelectionController(
    selectedTheme: () => ref.read(readendarThemeProvider),
    persist: ref.read(themePreferenceWriterProvider),
    syncWidgets: (theme) => ref.read(widgetThemeWriterProvider)(theme),
  );
});
