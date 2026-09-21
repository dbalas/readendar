import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'package:readendar/features/widget/widget_bridge.dart';

/// Reads + clears text staged by the Share Extension / Android send intent.
/// Returns null when nothing is pending or the platform call fails.
Future<String?> takePendingShareQuoteText() async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    final text = await HomeWidget.getWidgetData<String?>(
      kSharePendingQuoteTextKey,
    );
    if (text == null || text.trim().isEmpty) return null;
    final cleared = await removeWidgetData(const [kSharePendingQuoteTextKey]);
    if (!cleared) return null;
    return text.trim();
  } catch (e) {
    if (kDebugMode) debugPrint('takePendingShareQuoteText failed: $e');
    return null;
  }
}

/// Stages share text (tests / Android native handoff via HomeWidget prefs).
/// Best-effort — never throws into UI / resume paths.
Future<void> stagePendingShareQuoteText(String text) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(
      kSharePendingQuoteTextKey,
      text,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('stagePendingShareQuoteText failed: $e');
  }
}
