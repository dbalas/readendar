import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

/// Clamps [value] into [[firstDate], [lastDate]] so pickers never show one
/// date and Confirm another (Cupertino), and Material never asserts.
DateTime clampRdDate(DateTime value, DateTime firstDate, DateTime lastDate) {
  if (value.isBefore(firstDate)) return firstDate;
  if (value.isAfter(lastDate)) return lastDate;
  return value;
}

/// Platform-adaptive date picker. Material calendar dialog on Android;
/// Cupertino wheel sheet on iOS/macOS. Same inputs/outputs on both.
Future<DateTime?> showRdDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  Locale? locale,
}) {
  final clamped = clampRdDate(initialDate, firstDate, lastDate);
  if (!usesCupertinoChrome(context)) {
    return showDatePicker(
      context: context,
      initialDate: clamped,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      locale: locale,
    );
  }
  return _showCupertinoDateTimeSheet(
    context: context,
    initialDateTime: clamped,
    firstDate: firstDate,
    lastDate: lastDate,
    mode: CupertinoDatePickerMode.date,
  );
}

/// Platform-adaptive time picker.
Future<TimeOfDay?> showRdTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  if (!usesCupertinoChrome(context)) {
    return showTimePicker(context: context, initialTime: initialTime);
  }
  final now = DateTime.now();
  final initial = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );
  final picked = await _showCupertinoDateTimeSheet(
    context: context,
    initialDateTime: initial,
    firstDate: initial.subtract(const Duration(days: 1)),
    lastDate: initial.add(const Duration(days: 1)),
    mode: CupertinoDatePickerMode.time,
  );
  if (picked == null) return null;
  return TimeOfDay(hour: picked.hour, minute: picked.minute);
}

Future<DateTime?> _showCupertinoDateTimeSheet({
  required BuildContext context,
  required DateTime initialDateTime,
  required DateTime firstDate,
  required DateTime lastDate,
  required CupertinoDatePickerMode mode,
}) {
  // Keep [selected] aligned with what the wheel actually displays. Confirm
  // without scrolling must not return a pre-clamp out-of-range value.
  var selected = clampRdDate(initialDateTime, firstDate, lastDate);
  final l = AppL10n.of(context);
  return showRdFloatingGlassHost<DateTime>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.colors;
      return ReadendarFadeIn(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ReadendarTokens.sp3,
              0,
              ReadendarTokens.sp3,
              ReadendarTokens.sp3,
            ),
            child: RdGlassPanel(
              borderRadius: RdGlassPanel.sheetRadius,
              child: SizedBox(
                height: 280,
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(l.actionCancel),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () {
                              unawaited(RdHaptics.selection());
                              Navigator.of(sheetContext).pop(selected);
                            },
                            child: Text(
                              l.actionConfirm,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: mode,
                        initialDateTime: selected,
                        minimumDate: firstDate,
                        maximumDate: lastDate,
                        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(
                          sheetContext,
                        ),
                        onDateTimeChanged: (value) => selected = value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
