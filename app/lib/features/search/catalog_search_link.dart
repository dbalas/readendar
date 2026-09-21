import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/features/search/search_screen.dart';

/// Tappable catalog query (author name, related title, …) that opens
/// [SearchScreen] prefilled.
class CatalogSearchLink extends StatelessWidget {
  const CatalogSearchLink({
    required this.query,
    super.key,
    this.column,
  });

  final String query;
  final String? column;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: context.colors.accent,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.accent.withValues(alpha: 0.5),
    );
    return InkWell(
      onTap: () {
        unawaited(
          Navigator.of(context).push<void>(
            rdPageRoute<void>(
              context,
              builder: (_) => SearchScreen(
                initialQuery: query,
                initialColumn: column,
              ),
            ),
          ),
        );
      },
      child: Text(query, style: style),
    );
  }
}
