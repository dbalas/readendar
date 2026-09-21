import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';

void main() {
  testWidgets('uses Cupertino and Material controls on their platforms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: RdIconButton(icon: Icons.add, onPressed: _noop),
        ),
      );
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const MaterialApp(
          home: RdIconButton(icon: Icons.add, onPressed: _noop),
        ),
      );
      expect(find.byType(IconButton), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('custom child stays inside the adaptive control', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: RdIconButton.custom(
            onPressed: _noop,
            child: Icon(Icons.filter_list),
          ),
        ),
      );
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('compact uses a 28pt control on both platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RdIconButton.compact(icon: Icons.close, onPressed: _noop),
          ),
        ),
      );
      expect(tester.getSize(find.byType(CupertinoButton)), const Size(28, 28));
      expect(find.byType(IconButton), findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RdIconButton.compact(icon: Icons.close, onPressed: _noop),
          ),
        ),
      );
      expect(find.byType(IconButton), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _noop() {}
