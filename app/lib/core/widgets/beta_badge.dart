import 'package:flutter/material.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

/// Small "BETA" pill for pre-release surfaces so users know the feature is
/// still in testing. [compact] shrinks padding/type for tight slots.
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padH = compact ? 4.0 : 6.0;
    final padV = compact ? 1.0 : 2.0;
    final fontSize = compact ? 8.0 : 10.0;
    return Semantics(
      label: AppL10n.of(context).betaBadge,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: context.colors.warningSoftBg,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
        ),
        child: Text(
          AppL10n.of(context).betaBadge,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: 0.4,
            color: context.colors.warningSoftFg,
          ),
        ),
      ),
    );
  }
}

/// AppBar / screen title with a trailing [BetaBadge].
class BetaTitledText extends StatelessWidget {
  const BetaTitledText(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(title, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: ReadendarTokens.sp3),
        const BetaBadge(),
      ],
    );
  }
}
