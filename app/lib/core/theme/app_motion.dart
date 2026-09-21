import 'package:flutter/material.dart';
import 'package:readendar/core/theme/theme_background.dart';

/// Shared motion timings. Short enough to preserve responsiveness while making
/// state changes legible.
abstract final class ReadendarMotion {
  // Fast enough to keep navigation responsive, long enough to be perceptible.
  static const fast = Duration(milliseconds: 240);
  static const standard = Duration(milliseconds: 240);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve fadeCurve = Curves.easeInOutCubic;
}

/// Shared animation configuration for menus and modal sheets.
const readendarOverlayAnimationStyle = AnimationStyle(
  curve: ReadendarMotion.fadeCurve,
  duration: ReadendarMotion.fast,
  reverseCurve: ReadendarMotion.fadeCurve,
  reverseDuration: ReadendarMotion.fast,
);

/// Makes overlay content visibly fade in while the route presents it.
///
/// Material bottom sheets still use their native route motion for the panel;
/// this wrapper ensures the content itself does not appear instantaneously.
class ReadendarFadeIn extends StatefulWidget {
  const ReadendarFadeIn({required this.child, super.key});

  final Widget child;

  @override
  State<ReadendarFadeIn> createState() => _ReadendarFadeInState();
}

class _ReadendarFadeInState extends State<ReadendarFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ReadendarMotion.fast,
  )..forward();
  late final CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: ReadendarMotion.fadeCurve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

/// Animates direct changes between tab destinations.
///
/// Root destinations are not routes, so [PageTransitionsTheme] never sees
/// them. The retained destination fades while the navigation bar and offline
/// banner remain fixed.
class ReadendarTabSwitcher extends StatefulWidget {
  const ReadendarTabSwitcher({
    required this.index,
    required this.child,
    this.children,
    this.visited,
    this.animate = true,
    this.duration = ReadendarMotion.standard,
    super.key,
  });

  /// Retained, lazily-created root destinations. Unlike the single-child
  /// constructor, this keeps a visited page's State, scroll position and image
  /// cache alive while still animating between destinations.
  const ReadendarTabSwitcher.indexed({
    required this.index,
    required this.children,
    required this.visited,
    this.animate = true,
    this.duration = ReadendarMotion.standard,
    super.key,
  }) : child = const SizedBox.shrink();

  final int index;
  final Widget child;
  final Duration duration;
  final List<Widget>? children;
  final Set<int>? visited;

  /// Root tabs can opt out when an immediate switch is required by a caller.
  final bool animate;

  @override
  State<ReadendarTabSwitcher> createState() => _ReadendarTabSwitcherState();
}

class _ReadendarTabSwitcherState extends State<ReadendarTabSwitcher>
    with SingleTickerProviderStateMixin {
  double _direction = 1;
  late final AnimationController _controller;

  bool get _isIndexed => widget.children != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReadendarTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      // Retained Offstage tabs stay in the focus tree. Drop focus on switch so
      // a Library searcher cannot keep the keyboard open on Home.
      FocusManager.instance.primaryFocus?.unfocus();
      _direction = widget.index > oldWidget.index ? 1 : -1;
      if (_isIndexed && oldWidget.children != null && widget.animate) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          _controller.value = 1;
        } else {
          _controller
            ..duration = widget.duration
            ..forward(from: 0);
        }
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isIndexed) return _buildIndexed(context);
    final page = KeyedSubtree(
      key: ValueKey<int>(widget.index),
      child: widget.child,
    );
    if (MediaQuery.disableAnimationsOf(context)) return page;

    return AnimatedSwitcher(
      duration: widget.duration,
      reverseDuration: widget.duration,
      switchInCurve: ReadendarMotion.curve,
      switchOutCurve: ReadendarMotion.curve,
      transitionBuilder: (child, animation) {
        final key = child.key;
        if (key is! ValueKey<int>) return child;
        final childIndex = key.value;
        final isIncoming = childIndex == widget.index;
        final offset = isIncoming ? _direction : -_direction;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(offset * 0.035, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: page,
    );
  }

  Widget _buildIndexed(BuildContext context) {
    final children = widget.children!;
    final visited = widget.visited!;

    return AnimatedBuilder(
      animation: _controller,
      // Keep every slot at a stable stack position. Otherwise Flutter may
      // dispose an older page while reordering children for a transition.
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < children.length; index++)
            _retainedPage(
              index: index,
              child: children[index],
              mounted: visited.contains(index),
              active: index == widget.index,
              progress: _controller.value,
            ),
        ],
      ),
    );
  }

  Widget _retainedPage({
    required int index,
    required Widget child,
    required bool mounted,
    required bool active,
    required double progress,
  }) {
    final tabChild = mounted ? child : const SizedBox.shrink();
    return KeyedSubtree(
      key: ValueKey<String>('retained-tab-$index'),
      // Offstage + IgnorePointer hide the tab but leave focusables live.
      // ExcludeFocus is what stops inactive search fields from owning the
      // keyboard while another root destination is visible.
      child: ExcludeFocus(
        excluding: !active,
        child: Offstage(
          offstage: !active,
          child: TickerMode(
            enabled: active,
            child: IgnorePointer(
              ignoring: !active,
              // Root destinations are retained and are not routes, so make
              // their transition explicit here. The old destination is
              // offstage and the incoming one fades over the app canvas.
              child: FadeTransition(
                opacity: AlwaysStoppedAnimation(active ? progress : 0),
                child: KeyedSubtree(
                  key: ValueKey<int>(index),
                  child: tabChild,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fast fade used by every [MaterialPageRoute] in the app.
///
/// The route canvas stays fully painted while only its content fades. This is
/// required for gradient themes, whose transparent scaffolds would otherwise
/// reveal the previous route during the transition.
class ReadendarPageTransitionsBuilder extends PageTransitionsBuilder {
  const ReadendarPageTransitionsBuilder();

  @override
  Duration get transitionDuration => ReadendarMotion.fast;

  @override
  Duration get reverseTransitionDuration => ReadendarMotion.fast;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    return AnimatedBuilder(
      animation: animation,
      child: FadeTransition(opacity: curved, child: child),
      builder: (context, child) {
        // Transparent premium-theme scaffolds need a fully painted canvas only
        // while both routes are present. Drop it at completion so the app-level
        // animated theme background remains the single steady-state painter.
        if (animation.status == AnimationStatus.completed) return child!;
        return ReadendarThemeBackground(
          animateEffects: false,
          child: child!,
        );
      },
    );
  }
}

/// One fast transition contract prevents platform-specific route lag and
/// transparent-route bleed-through.
const readendarPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ReadendarPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ReadendarPageTransitionsBuilder(),
    TargetPlatform.iOS: ReadendarPageTransitionsBuilder(),
    TargetPlatform.linux: ReadendarPageTransitionsBuilder(),
    TargetPlatform.macOS: ReadendarPageTransitionsBuilder(),
    TargetPlatform.windows: ReadendarPageTransitionsBuilder(),
  },
);
