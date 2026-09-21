import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';

/// Home-screen / long-press launcher shortcuts + mapping into widget deep links.
const kShortcutQuoteNew = 'quote_new';
const kShortcutProgress = 'progress';
const kShortcutCalendar = 'calendar';

/// Native template / drawable names (iOS Assets.xcassets + Android `res/drawable`).
const kShortcutIconQuote = 'shortcut_quote';
const kShortcutIconProgress = 'shortcut_progress';
const kShortcutIconCalendar = 'shortcut_calendar';

const _quickActions = QuickActions();
bool _handlerInstalled = false;

WidgetDeepLink? deepLinkForShortcutType(String type) => switch (type) {
  kShortcutQuoteNew => const WidgetDeepLink(WidgetLinkKind.quoteNew, ''),
  kShortcutProgress => const WidgetDeepLink(WidgetLinkKind.progress, ''),
  kShortcutCalendar => const WidgetDeepLink(WidgetLinkKind.calendar, ''),
  _ => null,
};

/// Registers OS app shortcuts and routes taps through the pending deep-link
/// pipeline. Idempotent — call when the signed-in shell rebuilds with a new
/// locale so titles stay translated.
Future<void> setupAppShortcuts(WidgetRef ref, AppL10n l) async {
  if (!_handlerInstalled) {
    _handlerInstalled = true;
    await _quickActions.initialize((type) {
      final link = deepLinkForShortcutType(type);
      if (link != null) {
        ref.read(pendingWidgetDeepLinkProvider.notifier).state = link;
      }
    });
  }
  await _quickActions.setShortcutItems([
    ShortcutItem(
      type: kShortcutQuoteNew,
      localizedTitle: l.quoteQuickActionTitle,
      icon: kShortcutIconQuote,
    ),
    ShortcutItem(
      type: kShortcutProgress,
      localizedTitle: l.shortcutLogProgressTitle,
      icon: kShortcutIconProgress,
    ),
    ShortcutItem(
      type: kShortcutCalendar,
      localizedTitle: l.shortcutWhatsNextTitle,
      icon: kShortcutIconCalendar,
    ),
  ]);
}

/// @Deprecated — use [setupAppShortcuts].
Future<void> setupQuoteQuickAction(WidgetRef ref, AppL10n l) =>
    setupAppShortcuts(ref, l);

/// Removes shortcuts on logout.
Future<void> clearAppShortcuts() => _quickActions.clearShortcutItems();

/// @Deprecated — use [clearAppShortcuts].
Future<void> clearQuoteQuickAction() => clearAppShortcuts();
