import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';

/// Whether this [context] should use Cupertino-flavored chrome (alerts, sheets,
/// switches, page transitions, centered titles).
///
/// Driven by [ThemeData.platform] so widget tests can override the platform via
/// [ThemeData] without touching `dart:io`.
bool usesCupertinoChrome(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Shared floating root-nav geometry (glass pill on Apple + Android).
///
/// Kept here (not on the widget) so scroll insets do not create an import
/// cycle with RdRootNavBar.
abstract final class RdRootNavBarMetrics {
  static const double barHeight = 64;
  static const double horizontalPad = ReadendarTokens.sp4;
  static const double bottomPad = ReadendarTokens.sp3;
  static const double gapAbove = 8;

  /// Pill + gap above it. System home-indicator / nav-bar inset is applied by
  /// [rdFloatingNavContentInset] via [MediaQueryData.viewPadding].
  static double get contentInset => barHeight + bottomPad + gapAbove;
}

/// Extra scroll padding so tab content clears the floating root nav pill when
/// [Scaffold.extendBody] is true (translucent glass on Apple + Android).
///
/// Use as the bottom inset of root-tab [ListView]/[CustomScrollView] padding.
/// Also the bottom offset for FABs on root tabs so they sit **above** the pill,
/// not under it (see `RdCreateAction.fab` `aboveFloatingNav`).
///
/// Includes [MediaQueryData.viewPadding] bottom: a root [Scaffold] with a
/// bottom navigation bar zeroes [MediaQueryData.padding] on the body even when
/// [Scaffold.extendBody] is true, while `RdRootNavBar` still sits in a
/// [SafeArea] over the home indicator.
double rdFloatingNavContentInset(BuildContext context) {
  final media = MediaQuery.of(context);
  final systemBottom = media.viewPadding.bottom > media.padding.bottom
      ? media.viewPadding.bottom
      : media.padding.bottom;
  return RdRootNavBarMetrics.contentInset + systemBottom;
}
