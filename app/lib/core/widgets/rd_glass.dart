import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/bottom_sheet_safe_area.dart';

/// Shared iOS glass surface — closest Flutter match to UIKit materials.
///
/// Mirrors [CupertinoPopupSurface] optics (saturate-then-blur σ30) with the
/// **action-sheet** fill, not the denser dialog fill. Dialog gray (`0xCCF2F2F2`
/// / `0xCC2D2D2D`) reads milky and opaque; menus/sheets use the clearer
/// Cupertino action-sheet material (`0xC8FCFCFC` / `0xBE292929`, iOS 17
/// eyeball) so content peeks through — aligned with Apple HIG Liquid Glass for
/// navigation-layer chrome (menus, sheets, floating nav).
///
/// Use for floating chrome (nav, menus, sheets, pickers). Prefer Material
/// surfaces for mundane Android chrome; floating root nav may reuse this
/// panel so content shows through like Telegram / iOS.
///
/// Prefer a single blurred panel per overlay. Sibling chrome should use
/// [blur] `false` so stacked [BackdropFilter]s stay cheap.
class RdGlassPanel extends StatelessWidget {
  const RdGlassPanel({
    required this.child,
    super.key,
    this.borderRadius,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
    this.blur = true,
    this.boxShadow,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  /// When false, keeps the translucent fill/shadow without a second
  /// [BackdropFilter] (use for stacked glass chrome).
  final bool blur;

  /// Override default lift shadow (e.g. stronger floating root-nav on Android).
  final List<BoxShadow>? boxShadow;

  /// [CupertinoPopupSurface.defaultBlurSigma] — eyeballed from iOS 17.
  static const double blurSigma = CupertinoPopupSurface.defaultBlurSigma;

  /// Action-sheet fill from Flutter Cupertino (iOS 17 eyeball). Clearer than
  /// dialog material so menus read as glass, not gray cards.
  static const Color _fillLight = Color(0xC8FCFCFC);
  static const Color _fillDark = Color(0xBE292929);

  /// Opaque cancel plate when [blur] is false (Cupertino action-sheet cancel).
  static const Color _fillCancelLight = Color(0xFFFFFFFF);
  static const Color _fillCancelDark = Color(0xFF2C2C2C);

  // Saturation matrices from [CupertinoPopupSurface] (iOS 17 vibrance).
  static const List<double> _lightSaturationMatrix = <double>[
    1.74,
    -0.40,
    -0.17,
    0,
    0,
    -0.26,
    1.60,
    -0.17,
    0,
    0,
    -0.26,
    -0.40,
    1.83,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _darkSaturationMatrix = <double>[
    1.39,
    -0.56,
    -0.11,
    0,
    0.30,
    -0.32,
    1.14,
    -0.11,
    0,
    0.30,
    -0.32,
    -0.56,
    1.59,
    0,
    0.30,
    0,
    0,
    0,
    1,
    0,
  ];

  static BorderRadius get pillRadius => BorderRadius.circular(28);

  static BorderRadius get sheetRadius => const BorderRadius.vertical(
    top: Radius.circular(ReadendarTokens.radiusSheet),
  );

  static BorderRadius get cardRadius =>
      BorderRadius.circular(ReadendarTokens.radiusLg);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = borderRadius ?? cardRadius;
    final fill = brightness == Brightness.dark
        ? (blur ? _fillDark : _fillCancelDark)
        : (blur ? _fillLight : _fillCancelLight);
    final shadows =
        boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.32 : 0.14,
            ),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ];

    final content = ColoredBox(
      color: fill,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    final clipped = ClipRSuperellipse(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                inner: ColorFilter.matrix(
                  brightness == Brightness.dark
                      ? _darkSaturationMatrix
                      : _lightSaturationMatrix,
                ),
              ),
              child: content,
            )
          : content,
    );

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: clipped,
    );
  }
}

/// Host for floating glass overlays (modal glass cards).
///
/// Material [BottomSheetThemeData] paints a rectangular [ShapeBorder] outline
/// even when [backgroundColor] is transparent. Override that host chrome so
/// only the inner [RdGlassPanel] cards are visible.
Future<T?> showRdFloatingGlassHost<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final overlayPadding = MediaQuery.viewPaddingOf(context);
  return showModalBottomSheet<T>(
    context: context,
    sheetAnimationStyle: readendarOverlayAnimationStyle,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    isScrollControlled: isScrollControlled,
    builder: (sheetContext) {
      // Transparent canvas Material (the sheet host) at elevation 0 can
      // flatten BackdropFilter children on Impeller so glyphs and explicit
      // colors drop out. A transparency Material keeps ink + compositing
      // without painting another sheet outline.
      //
      // Modal routes often zero MediaQuery padding; keep the opener's
      // viewPadding so headers stay below the status bar.
      return MediaQuery(
        data: MediaQuery.of(sheetContext).copyWith(
          padding: overlayPadding,
          viewPadding: overlayPadding,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}

/// Color for a leading icon in a sheet row (menus, nav, option pickers).
///
/// Explicit [color] wins. Destructive rows use danger. Everything else uses
/// the theme accent (primary) so unstyled icons don't sit in default ink.
Color rdSheetItemIconColor(
  BuildContext context, {
  Color? color,
  bool destructive = false,
}) {
  if (color != null) return color;
  if (destructive) return context.colors.danger;
  return context.colors.accent;
}

/// Platform modal sheet. Glass floating card on Apple; Material sheet elsewhere.
///
/// Prefer this over raw `showModalBottomSheet` for new / migrated sheets so iOS
/// keeps one glass language. Pass [builder] content only — chrome is owned here.
/// Keyboard `MediaQuery.viewInsets` are applied automatically.
Future<T?> showRdModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  // Always keep the same ancestor shape. Swapping Padding in/out when the
  // keyboard opens remounts focus under the field and dismisses the IME.
  Widget wrap(BuildContext ctx, Widget child) {
    final inset = MediaQuery.viewInsetsOf(ctx).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: BottomSheetSafeArea(child: child),
    );
  }

  if (!usesCupertinoChrome(context)) {
    return showModalBottomSheet<T>(
      context: context,
      sheetAnimationStyle: readendarOverlayAnimationStyle,
      useSafeArea: true,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      builder: (ctx) => ReadendarFadeIn(child: wrap(ctx, builder(ctx))),
    );
  }
  return showRdFloatingGlassHost<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (sheetContext) {
      final viewPadding = MediaQuery.viewPaddingOf(sheetContext);
      final maxH =
          (MediaQuery.sizeOf(sheetContext).height -
              viewPadding.top -
              viewPadding.bottom) *
          0.92;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          ReadendarTokens.sp3,
          0,
          ReadendarTokens.sp3,
          ReadendarTokens.sp3,
        ),
        child: ReadendarFadeIn(
          child: RdGlassPanel(
            borderRadius: RdGlassPanel.sheetRadius,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: wrap(
                sheetContext,
                // No Flexible: hug content for short forms. Tall builders that
                // need a viewport (SingleChildScrollView) still receive the
                // ConstrainedBox maxHeight above and scroll inside it.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showDragHandle)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: sheetContext.colors.fg3.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    builder(sheetContext),
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
