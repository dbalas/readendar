import 'package:flutter/widgets.dart';

/// Telemetry removed. Methods stay as no-ops so call sites compile.
class AnalyticsService {
  AnalyticsService([Object? _]);

  static final AnalyticsService disabled = AnalyticsService();

  NavigatorObserver? get observer => null;

  bool get collectionEnabled => false;

  Future<void> setCollectionEnabled({required bool enabled}) async {}

  Future<void> setUserId(String? id) async {}

  Future<void> logBookAdded({String? source}) async {}

  Future<void> logPlanCreated({String? mode}) async {}

  Future<void> logLibraryImported({int? count}) async {}

  Future<void> logQuoteSaved() async {}
}
