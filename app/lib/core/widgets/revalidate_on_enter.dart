import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Stale-while-revalidate helper for screens that are re-entered often (tabs,
/// pushed details). On (re)mount it kicks off a background refetch of the given
/// [providers] **without** clearing what's already cached, so the user keeps
/// seeing the data in memory while fresh data loads. Combined with the
/// session-scoped `keepAlive` on those providers (see `_cacheWhileLoggedIn` in
/// `di/providers.dart`) and `AsyncValue.when(skipLoadingOnRefresh: true)`, a
/// returning view never flashes a loading spinner — it updates silently if the
/// backend returns something new.
///
/// To avoid hammering the backend when the user rapidly flips between tabs, a
/// provider is only revalidated if it wasn't already revalidated within
/// [staleAfter]. The first time a provider is ever read it loads normally
/// (spinner), since there is nothing cached yet.
class RevalidateOnEnter extends ConsumerStatefulWidget {
  const RevalidateOnEnter({
    required this.providers,
    required this.child,
    this.active = true,
    this.staleAfter = const Duration(seconds: 20),
    super.key,
  });

  final List<ProviderBase<Object?>> providers;
  final Widget child;

  /// Retained tab pages remain mounted. Refresh when their destination becomes
  /// visible, not only when the widget is first inserted into the tree.
  final bool active;
  final Duration staleAfter;

  @override
  ConsumerState<RevalidateOnEnter> createState() => _RevalidateOnEnterState();
}

// Module-level so the throttle is shared across every screen that revalidates
// the same provider (e.g. Home and Library both back onto `booksProvider`).
final Map<ProviderOrFamily, DateTime> _lastRevalidated = {};

/// Clears the revalidation throttle. Call on logout so the next account starts
/// with a clean slate (its providers are torn down anyway).
void resetRevalidationThrottle() => _lastRevalidated.clear();

class _RevalidateOnEnterState extends ConsumerState<RevalidateOnEnter> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _scheduleRevalidation();
  }

  @override
  void didUpdateWidget(covariant RevalidateOnEnter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _scheduleRevalidation();
  }

  void _scheduleRevalidation() {
    // Capture this before the child builds. If the child is the provider's
    // first consumer, its normal initial read is the fetch; revalidating it in
    // the post-frame callback would immediately cancel/restart that request.
    final cachedOnEntry = {
      for (final provider in widget.providers)
        if (ref.exists(provider)) provider,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = DateTime.now();
      for (final provider in widget.providers) {
        if (!cachedOnEntry.contains(provider)) {
          _lastRevalidated[provider] = now;
          continue;
        }
        final current = ref.read(provider);
        if (current case AsyncValue(isLoading: true, hasValue: false)) {
          _lastRevalidated[provider] = now;
          continue;
        }
        final last = _lastRevalidated[provider];
        if (last != null && now.difference(last) < widget.staleAfter) continue;
        _lastRevalidated[provider] = now;
        ref.invalidate(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
