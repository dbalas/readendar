import 'package:flutter/material.dart';

/// Adds the bottom inset that [showModalBottomSheet]'s `useSafeArea` deliberately
/// leaves out.
///
/// Bottom sheets should still pass `useSafeArea: true` to protect their top and
/// horizontal edges, then use this wrapper around content whose actions must
/// remain above gesture navigation or the Android three-button bar.
class BottomSheetSafeArea extends StatelessWidget {
  const BottomSheetSafeArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      top: false,
      right: false,
      child: child,
    );
  }
}
