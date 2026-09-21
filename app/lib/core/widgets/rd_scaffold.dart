import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/theme/icon_fonts.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';

/// Compact adaptive page chrome for pushed screens.
///
/// Feature code owns information architecture; this seam owns Material versus
/// Cupertino navigation presentation.
class RdScaffold extends StatelessWidget {
  const RdScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions = const [],
    this.bottomNavigationBar,
  });

  final Widget title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return Scaffold(
        appBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          leading: _rdNavBackButton(context),
          middle: title,
          trailing: actions.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: actions),
          border: null,
          backgroundColor: Theme.of(
            context,
          ).scaffoldBackgroundColor.withValues(alpha: 0.88),
        ),
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      );
    }
    return Scaffold(
      appBar: AppBar(title: title, actions: actions),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Same back glyph as Material [AppBar] (via [rdBackIconData]), not the
/// Cupertino chevron-plus-previous-title that [CupertinoNavigationBar] implies.
Widget? _rdNavBackButton(BuildContext context) {
  if (ModalRoute.of(context)?.impliesAppBarDismissal != true) return null;
  final theme = Theme.of(context);
  return RdIconButton(
    icon: rdBackIconData(theme.platform),
    size: 22,
    color:
        theme.appBarTheme.foregroundColor ??
        theme.iconTheme.color ??
        theme.colorScheme.onSurface,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => Navigator.maybePop(context),
  );
}
