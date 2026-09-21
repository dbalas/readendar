import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/rd_progress.dart';

/// Visual role for [RdButton].
enum RdButtonVariant { primary, secondary, destructive, plain }

/// Canonical CTA button. Solid (not glass) chrome; pill-shaped on Apple.
///
/// Prefer this over raw [FilledButton] / [OutlinedButton] / [TextButton] in
/// shared empty/error/form chrome so iOS and Android stay consistent.
class RdButton extends StatelessWidget {
  const RdButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = RdButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.compact = false,
    this.flushStart = false,
  });

  const RdButton.primary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.compact = false,
    this.flushStart = false,
  }) : variant = RdButtonVariant.primary;

  const RdButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.compact = false,
    this.flushStart = false,
  }) : variant = RdButtonVariant.secondary;

  const RdButton.destructive({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.compact = false,
    this.flushStart = false,
  }) : variant = RdButtonVariant.destructive;

  const RdButton.plain({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.compact = false,
    this.flushStart = false,
  }) : variant = RdButtonVariant.plain;

  final String label;
  final VoidCallback? onPressed;
  final RdButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final bool compact;

  /// When true, plain link-style buttons drop start padding so the label aligns
  /// with surrounding body text on its own row.
  final bool flushStart;

  bool get _enabled => onPressed != null && !loading;

  EdgeInsetsGeometry get _padding => compact
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  BorderRadius get _pillRadius =>
      BorderRadius.circular(ReadendarTokens.radiusPill);

  @override
  Widget build(BuildContext context) {
    final child = usesCupertinoChrome(context)
        ? _cupertino(context)
        : _material(context);
    if (!expand) return child;
    return SizedBox(width: double.infinity, child: child);
  }

  Widget _labelRow(Color fg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: RdProgress(color: fg),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: compact ? 16 : 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _cupertino(BuildContext context) {
    final c = context.colors;
    final enabled = _enabled;
    final tap = enabled ? onPressed : null;
    final sizeStyle = compact
        ? CupertinoButtonSize.small
        : CupertinoButtonSize.large;

    switch (variant) {
      case RdButtonVariant.primary:
        return CupertinoButton.filled(
          onPressed: tap,
          sizeStyle: sizeStyle,
          borderRadius: _pillRadius,
          padding: _padding,
          color: c.accent,
          foregroundColor: c.fgOnAccent,
          disabledColor: c.accent.withValues(alpha: 0.35),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: c.fgOnAccent,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 14 : 16,
            ),
            child: _labelRow(c.fgOnAccent),
          ),
        );
      case RdButtonVariant.secondary:
        final fg = enabled ? c.accentSoftFg : c.fgDisabled;
        return CupertinoButton(
          onPressed: tap,
          sizeStyle: sizeStyle,
          borderRadius: _pillRadius,
          padding: _padding,
          color: c.accentSoftBg,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 14 : 16,
            ),
            child: _labelRow(fg),
          ),
        );
      case RdButtonVariant.destructive:
        final fg = enabled ? c.dangerSoftFg : c.fgDisabled;
        return CupertinoButton(
          onPressed: tap,
          sizeStyle: sizeStyle,
          borderRadius: _pillRadius,
          padding: _padding,
          color: c.dangerSoftBg,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 14 : 16,
            ),
            child: _labelRow(fg),
          ),
        );
      case RdButtonVariant.plain:
        final fg = enabled ? c.accent : c.fgDisabled;
        return CupertinoButton(
          onPressed: tap,
          sizeStyle: sizeStyle,
          padding: flushStart
              ? EdgeInsetsDirectional.fromSTEB(
                  0,
                  compact ? 4 : 8,
                  compact ? 8 : 12,
                  compact ? 4 : 8,
                )
              : (compact
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          alignment: flushStart
              ? AlignmentDirectional.centerStart
              : Alignment.center,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 14 : 16,
            ),
            child: _labelRow(fg),
          ),
        );
    }
  }

  Widget _material(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabledOnPressed = _enabled ? onPressed : null;
    final child = _labelRow(switch (variant) {
      RdButtonVariant.primary => cs.onPrimary,
      RdButtonVariant.secondary => cs.primary,
      RdButtonVariant.destructive => cs.onError,
      RdButtonVariant.plain => cs.primary,
    });

    ButtonStyle? compactStyle({
      Color? backgroundColor,
      Color? foregroundColor,
    }) {
      if (!compact) {
        if (backgroundColor == null && foregroundColor == null) return null;
        return FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        );
      }
      return FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    switch (variant) {
      case RdButtonVariant.primary:
        return FilledButton(
          style: compactStyle(),
          onPressed: enabledOnPressed,
          child: child,
        );
      case RdButtonVariant.secondary:
        return OutlinedButton(
          style: compact
              ? OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null,
          onPressed: enabledOnPressed,
          child: child,
        );
      case RdButtonVariant.destructive:
        return FilledButton(
          style: compactStyle(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: enabledOnPressed,
          child: child,
        );
      case RdButtonVariant.plain:
        return TextButton(
          style: compact
              ? TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: flushStart
                      ? const EdgeInsetsDirectional.fromSTEB(0, 6, 8, 6)
                      : const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: flushStart
                      ? AlignmentDirectional.centerStart
                      : Alignment.center,
                )
              : TextButton.styleFrom(
                  padding: flushStart
                      ? const EdgeInsetsDirectional.fromSTEB(0, 8, 12, 8)
                      : null,
                  alignment: flushStart
                      ? AlignmentDirectional.centerStart
                      : Alignment.center,
                ),
          onPressed: enabledOnPressed,
          child: child,
        );
    }
  }
}
