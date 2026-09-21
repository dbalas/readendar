import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';

/// Maps available empty-pane height → density `0` (compact) … `1` (designed).
///
/// Tight tab panes (book-detail quotes / events under a tall header) stay
/// compact so the scene fits without inner scroll. As the outer NestedScrollView
/// collapses and more height arrives, density rises a bit — not past the art's
/// designed size.
double emptyArtDensityForHeight(double maxHeight) {
  // Compact under ~300px; designed size by ~440px.
  return ((maxHeight - 300) / 140).clamp(0.0, 1.0);
}

/// Propagates [density] to [EmptyArtBackdrop] / [EmptyArtCard] under an
/// [EmptyState] so illustrations can shrink/grow with available height.
class EmptyStateDensity extends InheritedWidget {
  const EmptyStateDensity({
    required this.density,
    required super.child,
    super.key,
  });

  /// `0` = compact, `1` = designed size.
  final double density;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<EmptyStateDensity>()
          ?.density ??
      1.0;

  @override
  bool updateShouldNotify(EmptyStateDensity oldWidget) =>
      density != oldWidget.density;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    super.key,
    this.icon,
    this.illustration,
    this.action,
    this.secondaryAction,
  }) : assert(
         icon != null || illustration != null,
         'EmptyState needs an icon or illustration',
       );

  /// Simple glyph fallback. Prefer [illustration] for primary empty screens.
  final IconData? icon;

  /// Worked scene (composed vectors / CustomPaint). Replaces [icon] when set.
  final Widget? illustration;

  final String message;

  /// Primary call-to-action (prefer `RdButton.primary` / `RdButton.secondary`).
  final Widget? action;

  /// Optional second, lower-emphasis CTA rendered under [action] (prefer
  /// `RdButton.plain`). Keeps the spacing consistent across screens instead of
  /// each call site hand-rolling a Column.
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    // Tall illustrations + keyboard (e.g. search autofocus) must not overflow —
    // scroll when the parent height is tighter than the content. Density tracks
    // available height so tab empties stay compact until more room appears.
    return LayoutBuilder(
      builder: (context, constraints) {
        final density = constraints.hasBoundedHeight
            ? emptyArtDensityForHeight(constraints.maxHeight)
            : 1.0;
        final body = EmptyStateDensity(
          density: density,
          child: _EmptyStateBody(
            icon: icon,
            illustration: illustration,
            message: message,
            action: action,
            secondaryAction: secondaryAction,
            density: density,
          ),
        );

        if (!constraints.hasBoundedHeight) {
          return Center(child: body);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: body),
          ),
        );
      },
    );
  }
}

class _EmptyStateBody extends StatelessWidget {
  const _EmptyStateBody({
    required this.message,
    required this.density,
    this.icon,
    this.illustration,
    this.action,
    this.secondaryAction,
  });

  final IconData? icon;
  final Widget? illustration;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;
  final double density;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pad = lerpDouble(12, 24, density)!;
    final afterArt = illustration != null ? lerpDouble(12, 20, density)! : 12.0;
    final afterMessage = lerpDouble(12, 16, density)!;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration case final art?)
            Padding(
              // Room for floating bubbles that sit outside the art card.
              padding: EdgeInsets.symmetric(
                horizontal: lerpDouble(4, 12, density)!,
              ),
              child: art,
            )
          else
            Icon(icon, size: lerpDouble(28, 36, density), color: cs.outline),
          SizedBox(height: afterArt),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[SizedBox(height: afterMessage), action!],
          if (secondaryAction != null) ...[
            SizedBox(height: lerpDouble(6, 8, density)),
            secondaryAction!,
          ],
        ],
      ),
    );
  }
}

/// Pull-to-refresh wrapper that keeps an [EmptyState] vertically centered while
/// remaining scrollable even when there is no content.
class RefreshableEmptyState extends StatelessWidget {
  const RefreshableEmptyState({
    required this.message,
    required this.onRefresh,
    super.key,
    this.icon,
    this.illustration,
    this.action,
    this.secondaryAction,
  }) : assert(
         icon != null || illustration != null,
         'RefreshableEmptyState needs an icon or illustration',
       );

  final IconData? icon;
  final Widget? illustration;
  final String message;
  final RefreshCallback onRefresh;
  final Widget? action;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) => RdRefresh(
    onRefresh: onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final density = emptyArtDensityForHeight(
              constraints.remainingPaintExtent,
            );
            return SliverFillRemaining(
              hasScrollBody: false,
              // Use the body directly (not EmptyState) so we don't nest a
              // SingleChildScrollView inside the pull-to-refresh scroll view.
              child: Center(
                child: EmptyStateDensity(
                  density: density,
                  child: _EmptyStateBody(
                    icon: icon,
                    illustration: illustration,
                    message: message,
                    action: action,
                    secondaryAction: secondaryAction,
                    density: density,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

/// Soft radial wash behind empty-scene art.
class EmptyArtBackdrop extends StatelessWidget {
  const EmptyArtBackdrop({
    required this.child,
    required this.accent,
    super.key,
    this.height = 168,
  });

  final Widget child;
  final Color accent;

  /// Designed (full) height. Shrinks with [EmptyStateDensity] when the pane is
  /// tight — down to ~72% so book-detail tab empties fit without scroll.
  final double height;

  @override
  Widget build(BuildContext context) {
    final density = EmptyStateDensity.of(context);
    // Compact ≈ 72% of designed height; expands toward full as density rises.
    final h = height * lerpDouble(0.72, 1.0, density)!;
    return SizedBox(
      height: h,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0),
                ],
              ),
            ),
            child: SizedBox(width: h + 24, height: h + 24),
          ),
          child,
        ],
      ),
    );
  }
}

/// Rounded surface tile used inside empty illustrations.
class EmptyArtCard extends StatelessWidget {
  const EmptyArtCard({
    required this.child,
    required this.background,
    required this.border,
    super.key,
    this.width = 148,
    this.padding = const EdgeInsets.all(ReadendarTokens.sp3),
  });

  final Widget child;
  final Color background;
  final Color border;

  /// Designed width. Scales lightly with [EmptyStateDensity] (not as much as
  /// the backdrop — keep the card readable when compact).
  final double width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final density = EmptyStateDensity.of(context);
    final w = width * lerpDouble(0.9, 1.0, density)!;
    return Container(
      width: w,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: ReadendarTokens.ink900.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
