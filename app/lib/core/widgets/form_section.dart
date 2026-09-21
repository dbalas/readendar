import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// A collapsible form section: a `titleMedium` header with a chevron toggle,
/// and its [children] shown when [open]. Shared across the app's forms (book,
/// event, …) so they group fields and behave consistently.
class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.children,
    super.key,
  });
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Icon(
            open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 20,
            color: context.colors.fg3,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (usesCupertinoChrome(context))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: header,
          )
        else
          InkWell(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
            onTap: onToggle,
            child: header,
          ),
        if (open) ...[
          const SizedBox(height: 10),
          ...children,
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
