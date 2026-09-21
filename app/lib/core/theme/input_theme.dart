import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';

/// Shared minimalist input styling for both light and dark themes: an outlined
/// field with **no fill** (transparent), a hairline rest border, and a thicker
/// brand-colored border on focus. Kept in one place so light/dark never drift.
InputDecorationTheme buildInputDecorationTheme({
  required Color border,
  required Color focus,
  required Color label,
  required Color hint,
  double radius = ReadendarTokens.radiusSm,
}) {
  OutlineInputBorder side(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecorationTheme(
    filled: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: side(border, 1),
    enabledBorder: side(border, 1),
    focusedBorder: side(focus, 1.5),
    errorBorder: side(ReadendarTokens.wine400, 1),
    focusedErrorBorder: side(ReadendarTokens.wine500, 1.5),
    labelStyle: TextStyle(color: label),
    floatingLabelStyle: TextStyle(color: focus),
    hintStyle: TextStyle(color: hint),
  );
}
