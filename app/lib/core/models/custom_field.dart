import 'package:flutter/foundation.dart';

enum CustomFieldType { text, number, datetime, boolean, singleSelect }

CustomFieldType _customFieldType(String raw) => switch (raw) {
  'number' => CustomFieldType.number,
  'datetime' => CustomFieldType.datetime,
  'boolean' => CustomFieldType.boolean,
  'single_select' => CustomFieldType.singleSelect,
  _ => CustomFieldType.text,
};

@immutable
class CustomFieldOption {
  const CustomFieldOption({
    required this.id,
    required this.label,
    required this.position,
    this.usageCount = 0,
  });
  factory CustomFieldOption.fromJson(Map<String, dynamic> json) =>
      CustomFieldOption(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        position: (json['position'] as num?)?.toInt() ?? 0,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      );
  final String id;
  final String label;
  final int position;
  final int usageCount;

  @override
  bool operator ==(Object other) =>
      other is CustomFieldOption &&
      other.id == id &&
      other.label == label &&
      other.position == position &&
      other.usageCount == usageCount;

  @override
  int get hashCode => Object.hash(id, label, position, usageCount);
}

@immutable
class CustomFieldDefinition {
  const CustomFieldDefinition({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.type,
    required this.position,
    this.textMode = '',
    this.usageCount = 0,
    this.options = const [],
  });
  factory CustomFieldDefinition.fromJson(Map<String, dynamic> json) =>
      CustomFieldDefinition(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconKey: json['iconKey'] as String? ?? 'tag',
        type: _customFieldType(json['type'] as String? ?? 'text'),
        textMode: json['textMode'] as String? ?? '',
        position: (json['position'] as num?)?.toInt() ?? 0,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
        options: ((json['options'] as List?) ?? const [])
            .map((e) => CustomFieldOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final String id;
  final String name;
  final String iconKey;
  final CustomFieldType type;
  final String textMode;
  final int position;
  final int usageCount;
  final List<CustomFieldOption> options;

  @override
  bool operator ==(Object other) {
    if (other is! CustomFieldDefinition) return false;
    if (other.id != id ||
        other.name != name ||
        other.iconKey != iconKey ||
        other.type != type ||
        other.textMode != textMode ||
        other.position != position ||
        other.usageCount != usageCount ||
        other.options.length != options.length) {
      return false;
    }
    for (var i = 0; i < options.length; i++) {
      if (other.options[i] != options[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconKey,
    type,
    textMode,
    position,
    usageCount,
    Object.hashAll(options),
  );
}

class CustomFieldValue {
  const CustomFieldValue({
    required this.kind,
    this.text,
    this.decimal,
    this.instant,
    this.boolean,
    this.optionId,
    this.optionLabel = '',
  });
  factory CustomFieldValue.fromJson(Map<String, dynamic> json) =>
      CustomFieldValue(
        kind: _customFieldType(json['kind'] as String? ?? 'text'),
        text: json['text'] as String?,
        decimal: json['decimal'] as String?,
        instant: DateTime.tryParse(json['instant'] as String? ?? ''),
        boolean: json['value'] as bool?,
        optionId: json['optionId'] as String?,
        optionLabel: json['optionLabel'] as String? ?? '',
      );
  final CustomFieldType kind;
  final String? text;
  final String? decimal;
  final DateTime? instant;
  final bool? boolean;
  final String? optionId;
  final String optionLabel;
  String get display => switch (kind) {
    CustomFieldType.text => text ?? '',
    CustomFieldType.number => decimal ?? '',
    CustomFieldType.datetime => instant?.toLocal().toString() ?? '',
    CustomFieldType.boolean => boolean == true ? 'Yes' : 'No',
    CustomFieldType.singleSelect => optionLabel,
  };
  Map<String, dynamic> toJson() => {
    'kind': switch (kind) {
      CustomFieldType.singleSelect => 'single_select',
      _ => kind.name,
    },
    if (text != null) 'text': text,
    if (decimal != null) 'decimal': decimal,
    if (instant != null) 'instant': instant!.toUtc().toIso8601String(),
    if (boolean != null) 'value': boolean,
    if (optionId != null) 'optionId': optionId,
  };
}

class BookCustomField {
  const BookCustomField({
    required this.fieldId,
    required this.name,
    required this.iconKey,
    required this.position,
    required this.source,
    required this.readOnly,
    required this.historical,
    required this.value,
    this.textMode = '',
  });
  factory BookCustomField.fromJson(Map<String, dynamic> json) =>
      BookCustomField(
        fieldId: json['fieldId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconKey: json['iconKey'] as String? ?? 'tag',
        textMode: json['textMode'] as String? ?? '',
        position: (json['position'] as num?)?.toInt() ?? 0,
        source: json['source'] as String? ?? 'personal',
        readOnly: json['readOnly'] as bool? ?? false,
        historical: json['historical'] as bool? ?? false,
        value: CustomFieldValue.fromJson(
          (json['value'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
  final String fieldId;
  final String name;
  final String iconKey;
  final String textMode;
  final int position;
  final String source;
  final bool readOnly;
  final bool historical;
  final CustomFieldValue value;
}

class CustomFieldChange {
  const CustomFieldChange(this.fieldId, this.value);
  final String fieldId;
  final CustomFieldValue? value;
  Map<String, dynamic> toJson() => {
    'fieldId': fieldId,
    'value': value?.toJson(),
  };
}

/// Unified book-detail field order/visibility (system metadata + custom fields).
enum BookDetailFieldKind { system, custom }

@immutable
class BookDetailFieldLayoutItem {
  const BookDetailFieldLayoutItem({
    required this.key,
    required this.kind,
    required this.hidden,
  });
  factory BookDetailFieldLayoutItem.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? '';
    final key = json['key'] as String? ?? '';
    return BookDetailFieldLayoutItem(
      key: key,
      kind: rawKind == 'system' || bookDetailSystemFieldKeys.contains(key)
          ? BookDetailFieldKind.system
          : BookDetailFieldKind.custom,
      hidden: json['hidden'] as bool? ?? false,
    );
  }
  final String key;
  final BookDetailFieldKind kind;
  final bool hidden;

  BookDetailFieldLayoutItem copyWith({bool? hidden}) =>
      BookDetailFieldLayoutItem(
        key: key,
        kind: kind,
        hidden: hidden ?? this.hidden,
      );

  Map<String, dynamic> toJson() => {
    'key': key,
    'hidden': hidden,
  };

  @override
  bool operator ==(Object other) =>
      other is BookDetailFieldLayoutItem &&
      other.key == key &&
      other.kind == kind &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(key, kind, hidden);
}

/// Stable system metadata keys — mirrors backend `SystemFieldKeys`.
/// Bibliographic strings from the local catalog plus consumption [BookFormat].
const bookDetailSystemFieldKeys = <String>[
  'synopsis',
  'publisher',
  'publication_date',
  'edition',
  'binding',
  'format',
  'language',
  'isbn',
  'dimensions',
  'msrp',
  'categories',
];
