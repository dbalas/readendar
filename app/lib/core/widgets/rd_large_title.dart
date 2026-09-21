import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// Collapsing large-title sliver for root tabs.
///
/// Apple: `CupertinoSliverNavigationBar` with large title. Material:
/// `SliverAppBar.large`. Must be a direct child of [CustomScrollView] /
/// [NestedScrollView] header — never wrap in Material/Padding.
class RdSliverLargeTitle extends StatelessWidget {
  const RdSliverLargeTitle({
    required this.title,
    super.key,
    this.actions = const [],
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final Widget title;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      Widget? trailing;
      if (actions.isNotEmpty) {
        trailing = Row(mainAxisSize: MainAxisSize.min, children: actions);
      }
      return CupertinoSliverNavigationBar(
        // Root tabs stay mounted in an IndexedStack — Hero route transitions
        // collide across siblings when left enabled.
        transitionBetweenRoutes: false,
        largeTitle: DefaultTextStyle.merge(
          style: TextStyle(
            color: context.colors.fg1,
            fontWeight: FontWeight.w700,
          ),
          child: title,
        ),
        trailing: trailing,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        border: null,
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.85),
      );
    }
    return SliverAppBar.large(
      title: title,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}

/// Root-tab scaffold with collapsing large title + [bodySlivers].
class RdLargeTitleScaffold extends StatelessWidget {
  const RdLargeTitleScaffold({
    required this.title,
    required this.bodySlivers,
    super.key,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
    this.automaticallyImplyLeading = false,
  });

  final Widget title;
  final List<Widget> actions;
  final Widget? leading;
  final List<Widget> bodySlivers;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          RdSliverLargeTitle(
            title: title,
            actions: actions,
            leading: leading,
            automaticallyImplyLeading: automaticallyImplyLeading,
          ),
          ...bodySlivers,
        ],
      ),
    );
  }
}
