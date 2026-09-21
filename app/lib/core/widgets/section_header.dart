import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// Shared editorial title for prominent content-entry surfaces.
class EditorialTitle extends StatelessWidget {
  const EditorialTitle(
    this.text, {
    super.key,
    this.color,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final Color? color;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    final foreground =
        color ?? style?.color ?? Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: maxLines,
          overflow: overflow,
          style: style?.copyWith(color: foreground),
        ),
        const SizedBox(height: ReadendarTokens.sp2),
        TitleAccentRule(color: foreground),
      ],
    );
  }
}

/// Short interrupted rule shared by editorial and grouped-content titles.
class TitleAccentRule extends StatelessWidget {
  const TitleAccentRule({
    required this.color,
    super.key,
    this.leadKey,
    this.tailKey,
  });

  final Color color;
  final Key? leadKey;
  final Key? tailKey;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 38,
        height: 2,
        child: Row(
          children: [
            DecoratedBox(
              key: leadKey,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
              child: const SizedBox(width: 26, height: 2),
            ),
            const SizedBox(width: ReadendarTokens.sp2),
            DecoratedBox(
              key: tailKey,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(1),
              ),
              child: const SizedBox(width: 8, height: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.text, {
    super.key,
    this.color,
    this.count,
    this.expanded,
    this.onToggle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  }) : assert(
         (expanded == null && onToggle == null) ||
             (expanded != null && onToggle != null),
         'Pass expanded and onToggle together for collapsible sections',
       );

  final String text;

  /// Overrides the default brand-primary label color. Book-status sections
  /// pass `bookStatusColor` so the heading matches its group.
  final Color? color;

  /// Full integer badge for a non-empty section. Hidden when null or 0.
  /// Not [CountBadge]: that control caps at +99 and is a circle.
  final int? count;

  /// When set with [onToggle], the header becomes a disclosure control.
  final bool? expanded;
  final VoidCallback? onToggle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  bool get _collapsible => expanded != null;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final showCount = count != null && count! > 0;
    final label = text.toUpperCase();
    final semanticsLabel = showCount ? '$label, $count' : label;
    final collapseHint = _collapsible
        ? (expanded!
              ? AppL10n.of(context).bookSectionCollapse
              : AppL10n.of(context).bookSectionExpand)
        : null;
    final body = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: ReadendarTextStyles.sectionLabel(
                            color: accent,
                          ),
                        ),
                      ),
                      if (showCount) ...[
                        const SizedBox(width: ReadendarTokens.sp2),
                        _SectionCountPill(count: count!, color: accent),
                      ],
                    ],
                  ),
                ),
              ),
              if (_collapsible) ...[
                Icon(
                  expanded! ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  key: Key(
                    expanded!
                        ? 'sectionHeaderChevronUp'
                        : 'sectionHeaderChevronDown',
                  ),
                  size: 18,
                  color: accent.withValues(alpha: 0.72),
                ),
                const SizedBox(width: ReadendarTokens.sp2),
              ],
              ?action,
            ],
          ),
          const SizedBox(height: ReadendarTokens.sp2),
          TitleAccentRule(
            key: const Key('sectionHeaderCutRule'),
            color: accent,
            leadKey: const Key('sectionHeaderRuleLead'),
            tailKey: const Key('sectionHeaderRuleTail'),
          ),
        ],
      ),
    );

    Widget content = body;
    if (_collapsible) {
      content = usesCupertinoChrome(context)
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: body,
            )
          : InkWell(
              onTap: onToggle,
              child: body,
            );
    }

    return Semantics(
      header: !_collapsible,
      button: _collapsible,
      expanded: expanded,
      onTap: _collapsible ? onToggle : null,
      container: true,
      label: semanticsLabel,
      hint: collapseHint,
      child: content,
    );
  }
}

class _SectionCountPill extends StatelessWidget {
  const _SectionCountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sectionHeaderCount'),
      padding: const EdgeInsets.fromLTRB(7, 2, 7, 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
      child: Text(
        '$count',
        style: ReadendarTextStyles.sectionLabel(color: color).copyWith(
          letterSpacing: 0,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}
