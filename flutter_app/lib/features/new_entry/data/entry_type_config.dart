import 'package:matka_management/core/language/app_localizations.dart';

class EntryTypeConfig {
  const EntryTypeConfig({
    required this.id,
    required this.name,
    required this.code,
    required this.backendType,
    required this.allowedLength,
    this.allowedNumbers,
    this.min,
    this.max,
    this.validationPattern = r'^[0-9]+$',
  });

  final String id;
  final String name;
  final String code;
  final String backendType;
  final int allowedLength;
  final Set<String>? allowedNumbers;
  final int? min;
  final int? max;
  final String validationPattern;

  String get helperText => AppLocalizations.trCurrent(
        'Only {length}-digit numbers are allowed for {name}.',
        params: {'length': allowedLength, 'name': name},
      );

  String? validateNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AppLocalizations.trCurrent('Number is required');
    if (!RegExp(validationPattern).hasMatch(trimmed)) {
      return AppLocalizations.trCurrent('Only digits are allowed');
    }
    if (trimmed.length != allowedLength) {
      return AppLocalizations.trCurrent(
        'Enter a {length}-digit number',
        params: {'length': allowedLength},
      );
    }
    if (allowedNumbers != null && !allowedNumbers!.contains(trimmed)) {
      return AppLocalizations.trCurrent(
        '{value} is not allowed for {name}',
        params: {'value': trimmed, 'name': name},
      );
    }
    final numeric = int.tryParse(trimmed);
    if (numeric == null) return AppLocalizations.trCurrent('Invalid number');
    if (min != null && numeric < min!) {
      return AppLocalizations.trCurrent(
        'Minimum allowed value is {min}',
        params: {'min': min},
      );
    }
    if (max != null && numeric > max!) {
      return AppLocalizations.trCurrent(
        'Maximum allowed value is {max}',
        params: {'max': max},
      );
    }
    return null;
  }
}

const entryTypeConfigs = [
  EntryTypeConfig(
    id: 'jule_pan',
    name: 'JULE PAN',
    code: 'JP',
    backendType: 'Patti',
    allowedLength: 2,
    min: 0,
    max: 99,
  ),
  EntryTypeConfig(
    id: 'supar_pan',
    name: 'SUPAR PAN',
    code: 'SP',
    backendType: 'Patti',
    allowedLength: 3,
    min: 0,
    max: 999,
  ),
  EntryTypeConfig(
    id: 'triple_pan',
    name: 'TRIPLE PAN',
    code: 'TP',
    backendType: 'Patti',
    allowedLength: 3,
    min: 0,
    max: 999,
  ),
  EntryTypeConfig(
    id: 'single',
    name: 'SINGLE',
    code: 'S',
    backendType: 'Single',
    allowedLength: 1,
    min: 0,
    max: 9,
  ),
  EntryTypeConfig(
    id: 'jodi',
    name: 'JODI',
    code: 'JD',
    backendType: 'Jodi',
    allowedLength: 2,
    min: 0,
    max: 99,
  ),
  EntryTypeConfig(
    id: 'half_sangam',
    name: 'HALF SANGAM',
    code: 'HS',
    backendType: 'Half Sangam',
    allowedLength: 3,
    min: 0,
    max: 999,
  ),
  EntryTypeConfig(
    id: 'full_sangam',
    name: 'FULL SANGAM',
    code: 'FS',
    backendType: 'Full Sangam',
    allowedLength: 5,
    min: 0,
    max: 99999,
  ),
  EntryTypeConfig(
    id: 'double_patti',
    name: 'DOUBLE PATTI',
    code: 'DP',
    backendType: 'Patti',
    allowedLength: 3,
    min: 0,
    max: 999,
  ),
  EntryTypeConfig(
    id: 'triple_patti',
    name: 'TRIPLE PATTI',
    code: 'TPA',
    backendType: 'Patti',
    allowedLength: 3,
    min: 0,
    max: 999,
  ),
];
