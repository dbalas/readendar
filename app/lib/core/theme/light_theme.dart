import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readendar/core/theme/app_motion.dart';

import 'package:readendar/core/theme/input_theme.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';

ThemeData buildLightTheme({
  ReadendarThemeId themeId = ReadendarThemeId.original,
}) {
  const colorScheme = ColorScheme.light(
    primary: ReadendarTokens.periwinkle500,
    primaryContainer: ReadendarTokens.periwinkle100,
    onPrimaryContainer: ReadendarTokens.periwinkle700,
    secondary: ReadendarTokens.teal500,
    onSecondary: ReadendarTokens.paper50,
    secondaryContainer: ReadendarTokens.teal100,
    onSecondaryContainer: ReadendarTokens.teal700,
    tertiary: ReadendarTokens.amber500,
    onTertiary: ReadendarTokens.ink900,
    error: ReadendarTokens.wine500,
    onSurface: ReadendarTokens.ink900,
    surfaceContainerHighest: ReadendarTokens.paper200,
    surfaceContainerHigh: ReadendarTokens.paper100,
    outline: ReadendarTokens.paper400,
    outlineVariant: ReadendarTokens.paper300,
  );

  final textTheme = ReadendarTextStyles.build(
    fg: ReadendarTokens.ink900,
    fg2: ReadendarTokens.ink500,
  );

  return applyReadendarTheme(
    ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ReadendarTokens.paperCanvas,
      fontFamily: ReadendarTokens.fontUi,
      fontFamilyFallback: ReadendarTokens.fontFamilyFallback,
      textTheme: textTheme,
      pageTransitionsTheme: readendarPageTransitionsTheme,
      // centerTitle left null so AppBar follows platform (centered on iOS).
      appBarTheme: AppBarTheme(
        backgroundColor: ReadendarTokens.paperCanvas,
        foregroundColor: ReadendarTokens.ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: ReadendarTokens.periwinkle500,
        applyThemeToAll: true,
      ),
      cardTheme: CardThemeData(
        color: ReadendarTokens.paper50,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
          side: const BorderSide(color: ReadendarTokens.paper300),
        ),
        margin: EdgeInsets.zero,
      ),
      // White-on-white overlays need border + shadow or they vanish into the
      // scaffold. Same separation contract as cards (line + float).
      popupMenuTheme: PopupMenuThemeData(
        color: ReadendarTokens.paper50,
        surfaceTintColor: Colors.transparent,
        elevation: ReadendarTokens.overlayElevation,
        shadowColor: ReadendarTokens.overlayShadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          side: const BorderSide(color: ReadendarTokens.paper300),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            ReadendarTokens.paper50,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(
            ReadendarTokens.overlayElevation,
          ),
          shadowColor: const WidgetStatePropertyAll(
            ReadendarTokens.overlayShadowLight,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              side: const BorderSide(color: ReadendarTokens.paper300),
            ),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ReadendarTokens.paper50,
        surfaceTintColor: Colors.transparent,
        elevation: ReadendarTokens.overlayElevation,
        shadowColor: ReadendarTokens.overlayShadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
          side: const BorderSide(color: ReadendarTokens.paper300),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: ReadendarTokens.periwinkle100,
        backgroundColor: ReadendarTokens.paperCanvas,
        surfaceTintColor: ReadendarTokens.paperCanvas,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : ReadendarTokens.ink500,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : ReadendarTokens.ink500,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        subtitleTextStyle: TextStyle(
          color: ReadendarTokens.ink300,
          fontSize: 13,
          height: 1.25,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ReadendarTokens.paper50,
        surfaceTintColor: Colors.transparent,
        elevation: ReadendarTokens.overlayElevation,
        shadowColor: ReadendarTokens.overlayShadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ReadendarTokens.radiusSheet),
          ),
          side: BorderSide(color: ReadendarTokens.paper300),
        ),
      ),
      inputDecorationTheme: buildInputDecorationTheme(
        border: ReadendarTokens.paper400,
        focus: ReadendarTokens.periwinkle500,
        label: ReadendarTokens.ink400,
        hint: ReadendarTokens.ink300,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ReadendarTokens.periwinkle500,
          foregroundColor: ReadendarTokens.paper50,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: ReadendarTokens.paper400),
          foregroundColor: ReadendarTokens.ink900,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ReadendarTokens.paper300,
        thickness: 1,
        space: 0,
      ),
      // Deep-lift icon-chip toasts style themselves via showRdToast /
      // buildRdSnackBar. Theme keeps the shell transparent so Material chrome
      // never paints a white slab behind the chip.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentTextStyle: TextStyle(color: ReadendarTokens.ink900),
      ),
    ),
    themeId,
    Brightness.light,
  );
}
