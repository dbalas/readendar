import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/di/providers.dart';

/// Warm snapshot for the manage-fields screen (layout + definitions).
@immutable
class CustomFieldsManageSnapshot {
  const CustomFieldsManageSnapshot({
    required this.layout,
    required this.definitions,
  });

  final List<BookDetailFieldLayoutItem> layout;
  final Map<String, CustomFieldDefinition> definitions;

  @override
  bool operator ==(Object other) {
    if (other is! CustomFieldsManageSnapshot) return false;
    if (!listEquals(other.layout, layout)) return false;
    if (other.definitions.length != definitions.length) return false;
    for (final entry in definitions.entries) {
      if (other.definitions[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(layout),
    Object.hashAll(
      definitions.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Session-scoped manage-fields cache so re-entry can paint immediately and
/// only rebuild when a background refresh returns a different snapshot.
class CustomFieldsManageCache {
  CustomFieldsManageSnapshot? _snapshot;

  CustomFieldsManageSnapshot? read() => _snapshot;

  void write(CustomFieldsManageSnapshot snapshot) {
    _snapshot = CustomFieldsManageSnapshot(
      layout: List<BookDetailFieldLayoutItem>.unmodifiable(snapshot.layout),
      definitions: Map<String, CustomFieldDefinition>.unmodifiable(
        snapshot.definitions,
      ),
    );
  }

  void clear() => _snapshot = null;
}

final customFieldsManageCacheProvider = Provider<CustomFieldsManageCache>((
  ref,
) {
  ref.watch(sessionProvider.select((session) => session.user?.id));
  return CustomFieldsManageCache();
});
