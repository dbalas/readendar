import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readendar/core/theme/app_motion.dart';

import 'package:readendar/core/theme/input_theme.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';

ThemeData buildDarkTheme({
  ReadendarThemeId themeId = ReadendarThemeId.original,
}) {
  const colorScheme = ColorScheme.dark(
    primary: ReadendarTokens.periwinkle300,
    onPrimary: ReadendarTokens.ink900,
    primaryContainer: ReadendarTokens.periwinkle800,
    onPrimaryContainer: ReadendarTokens.periwinkle100,
    secondary: ReadendarTokens.teal300,
    onSecondary: ReadendarTokens.ink900,
    secondaryContainer: ReadendarTokens.teal800,
    onSecondaryContainer: ReadendarTokens.teal100,
    tertiary: ReadendarTokens.amber400,
    onTertiary: ReadendarTokens.ink900,
    error: ReadendarTokens.wine300,
    onError: ReadendarTokens.ink900,
    surface: ReadendarTokens.darkSurface1,
    onSurface: ReadendarTokens.darkFg1,
    surfaceContainerHighest: ReadendarTokens.darkSurface2,
    surfaceContainerHigh: ReadendarTokens.darkSurface2,
    outline: Color(0x33F2F2F5),
    outlineVariant: Color(0x1AF2F2F5),
  );

  final textTheme = ReadendarTextStyles.build(
    fg: ReadendarTokens.darkFg1,
    fg2: ReadendarTokens.darkFg2,
  );

  return applyReadendarTheme(
    ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ReadendarTokens.darkBg,
      fontFamily: ReadendarTokens.fontUi,
      fontFamilyFallback: ReadendarTokens.fontFamilyFallback,
      textTheme: textTheme,
      pageTransitionsTheme: readendarPageTransitionsTheme,
      // centerTitle left null so AppBar follows platform (centered on iOS).
      appBarTheme: AppBarTheme(
        backgroundColor: ReadendarTokens.darkBg,
        foregroundColor: ReadendarTokens.darkFg1,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: ReadendarTokens.periwinkle300,
        applyThemeToAll: true,
      ),
      cardTheme: CardThemeData(
        color: ReadendarTokens.darkSurface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
          side: const BorderSide(color: Color(0x33F2F2F5)),
        ),
        margin: EdgeInsets.zero,
      ),
      // Floating overlays: border + shadow so menus/dialogs read against bg.
      popupMenuTheme: PopupMenuThemeData(
        color: ReadendarTokens.darkSurface1,
        surfaceTintColor: Colors.transparent,
        elevation: ReadendarTokens.overlayElevation,
        shadowColor: ReadendarTokens.overlayShadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          side: const BorderSide(color: Color(0x33F2F2F5)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(
            ReadendarTokens.darkSurface1,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(
            ReadendarTokens.overlayElevation,
          ),
          shadowColor: const WidgetStatePropertyAll(
            ReadendarTokens.overlayShadowDark,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              side: const BorderSide(color: Color(0x33F2F2F5)),
            ),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ReadendarTokens.darkSurface1,
        surfaceTintColor: Colors.transparent,
        elevation: ReadendarTokens.overlayElevation,
        shadowColor: ReadendarTokens.overlayShadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
          side: const BorderSide(color: Color(0x33F2F2F5)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: const Color(0x33A8ADDD),
        backgroundColor: ReadendarTokens.darkBg,
        surfaceTintColor: ReadendarTokens.darkBg,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : ReadendarTokens.darkFg2,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : ReadendarTokens.darkFg2,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        subtitleTextStyle: TextStyle(
          color: ReadendarTokens.darkFg3,
          fontSize: 13,
          height: 1.25,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ReadendarTokens.darkSurface1,
        surfaceTintColor: Colors.transparent,
        elevation: ReadendarTokens.overlayElevation,
        shadowColor: ReadendarTokens.overlayShadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ReadendarTokens.radiusSheet),
          ),
          side: BorderSide(color: Color(0x33F2F2F5)),
        ),
      ),
      inputDecorationTheme: buildInputDecorationTheme(
        border: const Color(0x66F2F2F5),
        focus: ReadendarTokens.periwinkle300,
        label: ReadendarTokens.darkFg3,
        hint: ReadendarTokens.darkFg3,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x33F2F2F5),
        thickness: 1,
        space: 0,
      ),
      // See light_theme snackBarTheme — content comes from showRdToast.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentTextStyle: TextStyle(color: ReadendarTokens.darkFg1),
      ),
    ),
    themeId,
    Brightness.dark,
  );
}
