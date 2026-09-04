import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

class NewEntryData {
  const NewEntryData({
    required this.markets,
    required this.gameConfig,
    required this.gameConfigMarketId,
  });

  final List<ReceiptMarket> markets;
  final GameConfigModel? gameConfig;
  final String? gameConfigMarketId;
}

class GameConfigModel {
  const GameConfigModel({
    required this.code,
    required this.label,
    required this.autoTypes,
    required this.numberSets,
    required this.missingBusinessRules,
  });

  final String code;
  final String label;
  final List<GameBetTypeConfig> autoTypes;
  final List<GameNumberSet> numberSets;
  final List<String> missingBusinessRules;

  factory GameConfigModel.fromJson(Map<String, dynamic> json) {
    return GameConfigModel(
      code: _stringValue(json['code']),
      label: _stringValue(json['label']),
      autoTypes: (json['autoTypes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GameBetTypeConfig.fromJson)
          .toList(),
      numberSets: (json['numberSets'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GameNumberSet.fromJson)
          .toList(),
      missingBusinessRules: (json['missingBusinessRules'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class GameBetTypeConfig {
  const GameBetTypeConfig({
    required this.id,
    required this.label,
    required this.betType,
    required this.backendType,
    required this.enabled,
    required this.requiresSubtype,
    required this.allowedLength,
    required this.options,
    required this.subtypes,
    this.missingRule,
  });

  final String id;
  final String label;
  final String betType;
  final String backendType;
  final bool enabled;
  final bool requiresSubtype;
  final int allowedLength;
  final List<GameNumberOption> options;
  final List<GameBetSubtypeConfig> subtypes;
  final String? missingRule;

  bool get hasConfiguredOptions {
    if (requiresSubtype) {
      return subtypes.any((subtype) => subtype.hasConfiguredOptions);
    }
    return enabled && options.isNotEmpty;
  }

  String get helperText {
    if (missingRule != null && missingRule!.isNotEmpty) return missingRule!;
    if (allowedLength > 0) {
      return AppLocalizations.trCurrent(
        'Only {length}-digit configured values are allowed for {label}.',
        params: {'length': allowedLength, 'label': label},
      );
    }
    return AppLocalizations.trCurrent(
      'Select a configured value for {label}.',
      params: {'label': label},
    );
  }

  factory GameBetTypeConfig.fromJson(Map<String, dynamic> json) {
    return GameBetTypeConfig(
      id: _stringValue(json['id']),
      label: _stringValue(json['label']),
      betType: _stringValue(json['betType']),
      backendType: _stringValue(json['backendType']),
      enabled: json['enabled'] == true,
      requiresSubtype: json['requiresSubtype'] == true,
      allowedLength: _intValue(json['allowedLength']),
      options: (json['options'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GameNumberOption.fromJson)
          .toList(),
      subtypes: (json['subtypes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GameBetSubtypeConfig.fromJson)
          .toList(),
      missingRule: _nullableString(json['missingRule']),
    );
  }
}

class GameBetSubtypeConfig {
  const GameBetSubtypeConfig({
    required this.id,
    required this.label,
    required this.enabled,
    required this.allowedLength,
    required this.options,
    this.missingRule,
  });

  final String id;
  final String label;
  final bool enabled;
  final int allowedLength;
  final List<GameNumberOption> options;
  final String? missingRule;

  bool get hasConfiguredOptions => enabled && options.isNotEmpty;

  String get helperText {
    if (missingRule != null && missingRule!.isNotEmpty) return missingRule!;
    return AppLocalizations.trCurrent(
      'Only {length}-digit configured values are allowed for {label}.',
      params: {'length': allowedLength, 'label': label},
    );
  }

  factory GameBetSubtypeConfig.fromJson(Map<String, dynamic> json) {
    return GameBetSubtypeConfig(
      id: _stringValue(json['id']),
      label: _stringValue(json['label']),
      enabled: json['enabled'] == true,
      allowedLength: _intValue(json['allowedLength']),
      options: (json['options'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GameNumberOption.fromJson)
          .toList(),
      missingRule: _nullableString(json['missingRule']),
    );
  }
}

class GameNumberOption {
  const GameNumberOption({
    required this.value,
    this.column,
    this.pannaType,
  });

  final String value;
  final int? column;
  final String? pannaType;

  factory GameNumberOption.fromJson(Map<String, dynamic> json) {
    return GameNumberOption(
      value: _stringValue(json['value']),
      column: json['column'] == null ? null : _intValue(json['column']),
      pannaType: _nullableString(json['pannaType']),
    );
  }
}

class GameNumberSet {
  const GameNumberSet({
    required this.code,
    required this.label,
    required this.totalEntries,
    required this.analysis,
  });

  final String code;
  final String label;
  final int totalEntries;
  final Map<String, dynamic> analysis;

  factory GameNumberSet.fromJson(Map<String, dynamic> json) {
    return GameNumberSet(
      code: _stringValue(json['code']),
      label: _stringValue(json['label']),
      totalEntries: _intValue(json['totalEntries']),
      analysis: json['analysis'] is Map<String, dynamic>
          ? json['analysis'] as Map<String, dynamic>
          : const {},
    );
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
