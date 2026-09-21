import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/utils/platform_chrome.dart';

/// Primary create affordance: FAB on Material, toolbar plus on Cupertino.
///
/// Same action on both platforms — only chrome placement differs. Wire
/// `onPressed` into both `Scaffold.floatingActionButton` and `AppBar.actions`
/// via the helpers below.
///
/// When the screen has no AppBar (embedded tabs, nested scaffolds), pass
/// `forceFab` so Cupertino also keeps a FAB instead of dropping the action.
///
/// Root tabs under `RdRootNavBar` with [Scaffold.extendBody] must pass
/// `aboveFloatingNav` so the FAB clears the pill vertically (not z-order).
class RdCreateAction {
  const RdCreateAction._();

  /// Material FAB, or `null` on Cupertino (action lives in the app bar).
  ///
  /// Set [forceFab] when there is no AppBar to host [appBarActions].
  /// Set [aboveFloatingNav] on root-tab screens so the FAB sits above the
  /// floating nav pill ([rdFloatingNavContentInset]).
  static Widget? fab({
    required BuildContext context,
    required VoidCallback onPressed,
    required String tooltip,
    IconData icon = LucideIcons.plus,
    bool forceFab = false,
    bool aboveFloatingNav = false,
  }) {
    if (usesCupertinoChrome(context) && !forceFab) return null;
    final cs = Theme.of(context).colorScheme;
    Widget button = FloatingActionButton(
      tooltip: tooltip,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      onPressed: onPressed,
      // Root tabs stay mounted in an IndexedStack. Default FAB heroes all
      // share `<default FloatingActionButton tag>` and collide on pop.
      heroTag: null,
      child: Icon(icon),
    );
    if (aboveFloatingNav) {
      button = Padding(
        padding: EdgeInsets.only(bottom: rdFloatingNavContentInset(context)),
        child: button,
      );
    }
    return button;
  }

  /// Cupertino toolbar plus button, or empty on Material (FAB owns the action).
  static List<Widget> appBarActions({
    required BuildContext context,
    required VoidCallback onPressed,
    required String tooltip,
    IconData icon = LucideIcons.plus,
  }) {
    if (!usesCupertinoChrome(context)) return const [];
    return [
      IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    ];
  }
}
