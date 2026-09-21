import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readendar/core/theme/tokens.dart';

/// System-bar styling shared by the root app surface and tests.
///
/// This is installed through an [AnnotatedRegion] instead of an imperative
/// [SystemChrome.setSystemUIOverlayStyle] call. Flutter samples annotated
/// regions at the top and bottom of every rendered frame; that prevents an
/// AppBar's status-bar-only style from replacing the navigation-bar style
/// before Android receives it.
SystemUiOverlayStyle readendarSystemUiOverlayStyle(
  Brightness brightness, {
  Color? backgroundColor,
}) {
  final isDark = brightness == Brightness.dark;
  final background =
      backgroundColor ??
      (isDark ? ReadendarTokens.darkBg : ReadendarTokens.paperCanvas);
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: background,
    systemNavigationBarDividerColor: background,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    // In edge-to-edge mode Android 10+ may otherwise replace the content under
    // 2/3-button navigation with its own contrast scrim. The app already paints
    // an appropriate light/dark surface and supplies matching icon brightness.
    systemNavigationBarContrastEnforced: false,
  );
}

/// Publishes Readendar's system-bar style over the full rendered window.
class ReadendarSystemUiStyle extends StatelessWidget {
  const ReadendarSystemUiStyle({
    required this.brightness,
    required this.child,
    this.backgroundColor,
    super.key,
  });

  final Brightness brightness;
  final Color? backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: readendarSystemUiOverlayStyle(
        brightness,
        backgroundColor: backgroundColor,
      ),
      child: child,
    );
  }
}
