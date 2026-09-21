import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';

/// Compact empty placeholder: glyph + short copy + optional CTA below.
class CompactEmptyCard extends StatelessWidget {
  const CompactEmptyCard({
    required this.message,
    required this.illustration,
    super.key,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  final String message;
  final Widget illustration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasAction = actionLabel != null && onAction != null;
    return RdCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          illustration,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.fg2,
                    height: 1.25,
                  ),
                ),
                if (hasAction) ...[
                  const SizedBox(height: 8),
                  RdButton.primary(
                    key: actionKey,
                    label: actionLabel!,
                    onPressed: onAction,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid tinted tile with a single icon — no stacked/transparent layers.
class CompactEmptyGlyph extends StatelessWidget {
  const CompactEmptyGlyph({
    required this.background,
    required this.foreground,
    required this.icon,
    super.key,
  });

  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: foreground),
    );
  }
}
