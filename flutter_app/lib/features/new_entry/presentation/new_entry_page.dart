import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_provider.dart';
import 'package:matka_management/features/auth/data/models/access_status.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/presentation/entries_controller.dart';
import 'package:matka_management/features/new_entry/data/entry_type_config.dart';
import 'package:matka_management/features/new_entry/data/game_config_models.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_controller.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_draft_provider.dart';
import 'package:matka_management/features/printed_receipts/data/printer_store.dart';
import 'package:matka_management/features/share_records/presentation/providers/share_records_provider.dart';
import 'package:matka_management/shared/widgets/aligned_jackpot_marker.dart';
import 'package:matka_management/shared/widgets/status_screens.dart';

const _parchiEntriesPerPage = 10;
const _receiptAlphabetShadow = <Shadow>[
  Shadow(color: Colors.black, offset: Offset(0.18, 0), blurRadius: 0),
];
const _receiptGreenAlphabetShadow = <Shadow>[
  Shadow(color: Color(0xFF108438), offset: Offset(0.18, 0), blurRadius: 0),
];

class NewEntryPage extends ConsumerStatefulWidget {
  const NewEntryPage({super.key});

  @override
  ConsumerState<NewEntryPage> createState() => _NewEntryPageState();
}

class _LocalizedDigitsController extends TextEditingController {
  _LocalizedDigitsController({super.text}) {
    super.text = AppLocalizations.normalizeDigits(super.text);
  }

  void refreshLocale() {
    notifyListeners();
  }

  void applyKeypadValue(String value) {
    final normalized = AppLocalizations.normalizeDigits(value);
    if (normalized.isEmpty) {
      clear();
      return;
    }
    final nextValue = text + normalized;
    text = nextValue;
    selection = TextSelection.collapsed(offset: text.length);
  }

  void removeLastKeypadValue() {
    if (text.isEmpty) return;
    text = text.substring(0, text.length - 1);
    selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(
      style: style,
      text: AppLocalizations.localizeDigits(super.text),
    );
  }

  @override
  set text(String value) {
    super.text = AppLocalizations.normalizeDigits(value);
  }
}

class _BetEntry {
  _BetEntry({
    required String number,
    required String amount,
    List<JackpotEntryData> jackpotEntries = const [],
  })  : number = _LocalizedDigitsController(text: number),
        amount = _LocalizedDigitsController(text: amount),
        numberFocus = FocusNode(),
        amountFocus = FocusNode(),
        jackpotNumberFocus = List<FocusNode>.generate(10, (_) => FocusNode()),
        jackpotAmountFocus = List<FocusNode>.generate(10, (_) => FocusNode()),
        jackpotNumbers = List<TextEditingController>.generate(
          10,
          (index) => _LocalizedDigitsController(
            text: index < jackpotEntries.length
                ? jackpotEntries[index].number
                : '',
          ),
        ),
        jackpotAmounts = List<TextEditingController>.generate(
          10,
          (index) => _LocalizedDigitsController(
            text: index < jackpotEntries.length
                ? jackpotEntries[index].amount
                : '',
          ),
        ),
        jackpotRowCount = jackpotEntries.isEmpty
            ? 1
            : (jackpotEntries.length > 10 ? 10 : jackpotEntries.length);

  final TextEditingController number;
  final TextEditingController amount;
  final FocusNode numberFocus;
  final FocusNode amountFocus;
  final List<FocusNode> jackpotNumberFocus;
  final List<FocusNode> jackpotAmountFocus;
  final List<TextEditingController> jackpotNumbers;
  final List<TextEditingController> jackpotAmounts;
  int jackpotRowCount;
  bool isJackpot = false;
  String? sessionOverride;
  String? error;

  bool get hasAnyValue =>
      number.text.trim().isNotEmpty || amount.text.trim().isNotEmpty;

  void dispose() {
    number.dispose();
    amount.dispose();
    numberFocus.dispose();
    amountFocus.dispose();
    for (final node in jackpotNumberFocus) {
      node.dispose();
    }
    for (final node in jackpotAmountFocus) {
      node.dispose();
    }
    for (final controller in jackpotNumbers) {
      controller.dispose();
    }
    for (final controller in jackpotAmounts) {
      controller.dispose();
    }
  }
}

class _AutoBetEntry {
  _AutoBetEntry({
    required this.typeId,
    this.subtypeId,
    required String number,
    required String amount,
  })  : number = _LocalizedDigitsController(text: number),
        amount = _LocalizedDigitsController(text: amount);

  final String typeId;
  final String? subtypeId;
  final TextEditingController number;
  final TextEditingController amount;
  bool isJackpot = false;

  bool get hasAnyValue =>
      number.text.trim().isNotEmpty || amount.text.trim().isNotEmpty;

  void dispose() {
    number.dispose();
    amount.dispose();
  }
}

class _JackpotLine {
  const _JackpotLine({
    required this.number,
    required this.amount,
    required this.calculatedAmount,
  });

  final String number;
  final String amount;
  final String calculatedAmount;
}

class _ReceiptLine {
  const _ReceiptLine({
    required this.backendType,
    required this.betType,
    required this.number,
    required this.amount,
    required this.isManual,
    required this.isJackpot,
    this.sessionOverride,
    this.betSubtype,
    this.displayAmount,
    this.isBazarSangam = false,
    this.isFamily = false,
    this.isCpJodi = false,
    this.isCommon = false,
    this.familyMultiplier,
    this.jackpotEntries = const [],
    this.showMainEntry = true,
  });

  final String backendType;
  final String betType;
  final String number;
  final String amount;
  final bool isManual;
  final bool isJackpot;
  final String? sessionOverride;
  final String? betSubtype;
  final String? displayAmount;
  final bool isBazarSangam;
  final bool isFamily;
  final bool isCpJodi;
  final bool isCommon;
  final int? familyMultiplier;
  final List<_JackpotLine> jackpotEntries;
  final bool showMainEntry;

  String get effectiveDisplayAmount => displayAmount ?? amount;

  bool get isMotorPana =>
      _isMotorPanaCode(backendType) ||
      _isMotorPanaCode(betType) ||
      _isMotorPanaCode(betSubtype);

  bool get isSimpleJodi => backendType == 'Jodi' && !isCpJodi && !isFamily;

  _ReceiptLine copyForParchi({
    required bool showMainEntry,
    required List<_JackpotLine> jackpotEntries,
    String? amount,
  }) {
    return _ReceiptLine(
      backendType: backendType,
      betType: betType,
      number: number,
      amount: amount ?? this.amount,
      isManual: isManual,
      isJackpot: isJackpot,
      sessionOverride: sessionOverride,
      betSubtype: betSubtype,
      displayAmount: displayAmount,
      isBazarSangam: isBazarSangam,
      isFamily: isFamily,
      isCpJodi: isCpJodi,
      isCommon: isCommon,
      familyMultiplier: familyMultiplier,
      jackpotEntries: jackpotEntries,
      showMainEntry: showMainEntry,
    );
  }
}

List<List<_ReceiptLine>> _receiptLinePages(List<_ReceiptLine> lines) {
  if (lines.isEmpty) return [const <_ReceiptLine>[]];
  final pages = <List<_ReceiptLine>>[];
  var currentPage = <_ReceiptLine>[];
  var currentEntryCount = 0;

  void pushCurrentPage() {
    if (currentPage.isEmpty) return;
    pages.add(currentPage);
    currentPage = <_ReceiptLine>[];
    currentEntryCount = 0;
  }

  void ensurePageSpace() {
    if (currentEntryCount >= _parchiEntriesPerPage) pushCurrentPage();
  }

  for (final line in lines) {
    final jackpotEntries = _visibleJackpotLines(line);
    final requiredEntryCount = 1 + jackpotEntries.length;
    if (currentEntryCount > 0 &&
        currentEntryCount + requiredEntryCount > _parchiEntriesPerPage) {
      pushCurrentPage();
    }
    ensurePageSpace();
    final fullJackpotTotal = _jackpotAmountTotal(jackpotEntries);
    var mainAmount = _parseAmount(line.amount) - fullJackpotTotal;
    if (mainAmount < 0) mainAmount = 0;

    final jackpotSpaceOnMainPage =
        _parchiEntriesPerPage - currentEntryCount - 1;
    final mainJackpotCount = jackpotEntries.length < jackpotSpaceOnMainPage
        ? jackpotEntries.length
        : jackpotSpaceOnMainPage;
    final mainJackpotEntries = jackpotEntries.sublist(0, mainJackpotCount);
    currentPage.add(line.copyForParchi(
      showMainEntry: true,
      jackpotEntries: mainJackpotEntries,
      amount:
          _formatAmount(mainAmount + _jackpotAmountTotal(mainJackpotEntries)),
    ));
    currentEntryCount += 1 + mainJackpotCount;

    var jackpotIndex = mainJackpotCount;
    while (jackpotIndex < jackpotEntries.length) {
      ensurePageSpace();
      final available = _parchiEntriesPerPage - currentEntryCount;
      final nextIndex = jackpotIndex + available > jackpotEntries.length
          ? jackpotEntries.length
          : jackpotIndex + available;
      final continuationJackpotEntries =
          jackpotEntries.sublist(jackpotIndex, nextIndex);
      currentPage.add(line.copyForParchi(
        showMainEntry: false,
        jackpotEntries: continuationJackpotEntries,
        amount: _formatAmount(_jackpotAmountTotal(continuationJackpotEntries)),
      ));
      currentEntryCount += nextIndex - jackpotIndex;
      jackpotIndex = nextIndex;
    }
  }
  pushCurrentPage();
  return pages;
}

String _parchiNoForPage(String parchiNo, int pageIndex) {
  if (pageIndex <= 0) return parchiNo;
  final match = RegExp(r'^(.*?)(\d+)$').firstMatch(parchiNo.trim());
  if (match == null) return '$parchiNo-${pageIndex + 1}';
  final prefix = match.group(1) ?? '';
  final numberText = match.group(2) ?? '';
  final number = int.tryParse(numberText);
  if (number == null) return '$parchiNo-${pageIndex + 1}';
  return '$prefix${(number + pageIndex).toString().padLeft(numberText.length, '0')}';
}

num _receiptPageTotal(List<_ReceiptLine> lines, {required bool isOtc}) {
  final baseTotal = lines.fold<num>(
    0,
    (total, line) => total + _parseAmount(line.amount),
  );
  return isOtc ? baseTotal * 2 : baseTotal;
}

List<_JackpotLine> _visibleJackpotLines(_ReceiptLine line) {
  if (!line.isJackpot) return const <_JackpotLine>[];
  return line.jackpotEntries
      .where((entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty)
      .toList(growable: false);
}

final _singleSpDpPattern = RegExp(
  r'^(?:([0-9]) *(sp|dp)|(sp|dp) *([0-9]))$',
  caseSensitive: false,
);
final _singleCutPPattern = RegExp(
  r'^(?:(?:ct|cut *p) *([0-9])|([0-9]) *(?:ct|cut *p))$',
  caseSensitive: false,
);
final _singleSpDpDraftPattern = RegExp(
  r'^(?:[0-9]? *(?:[sS][pP]?|[dD][pP]?)|(?:[sS][pP]?|[dD][pP]?) *[0-9]?)$',
);
final _singleCutPDraftPattern = RegExp(
  r'^(?:(?:[cC][tT]?|[cC][uU]?[tT]?(?: *[pP])?) *[0-9]?|[0-9]? *(?:[cC][tT]?|[cC][uU]?[tT]?(?: *[pP])?))$',
);
final _commonInputPattern = RegExp(
  r'^(?:[cC][mM] *([0-9])|([0-9]) *(?:[cC][mM]|[cC][oO][mM][mM][oO][nN]))$',
);
final _commonDraftPattern = RegExp(
  r'^(?:[cC][mM]? *[0-9]?|[0-9]? *(?:[cC][mM]?|[cC][oO][mM]{0,2}[oO]?[nN]?)?)$',
);
final _bazarSangamPattern = RegExp(
  r'^(.+?) *bz$',
  caseSensitive: false,
);
final _bazarSangamDraftPattern = RegExp(
  r'^[0-9> \-*]+ *(?:[bB][zZ]?)?$',
);
final _familyInputPattern = RegExp(
  r'^(?:[fF] *([0-9]{2,3})|([0-9]{2,3}) *[fF])$',
);
final _familyDraftPattern = RegExp(
  r'^(?:[fF] *[0-9]{0,3}|[0-9]{0,3} *[fF]?)$',
);
final _cpJodiInputPattern = RegExp(
  r'^(?:[cC][pP] *([0-9]{2})|([0-9]{2}) *[cC][pP])$',
);
final _cpJodiDraftPattern = RegExp(
  r'^(?:[cC][pP]? *[0-9]{0,2}|[0-9]{0,2} *(?:[cC][pP]?)?)$',
);
final _letterPattern = RegExp(r'[A-Za-z]');
final _amountPattern = RegExp(r'^\d+(?:\.\d{1,2})?$');
final _jackpotNumberPattern = RegExp(r'^\d$');
const _commonMultiplier = 36;
const _familyDigitPairs = {
  '0': '5',
  '1': '6',
  '2': '7',
  '3': '8',
  '4': '9',
  '5': '0',
  '6': '1',
  '7': '2',
  '8': '3',
  '9': '4',
};

num _parseAmount(String value) {
  return num.tryParse(value.trim()) ?? 0;
}

bool _isPositiveAmount(String value) {
  final amount = num.tryParse(value.trim());
  return amount != null && amount > 0;
}

String? _singleCutPNumber(String rawNumber) {
  final match = _singleCutPPattern.firstMatch(rawNumber.trim());
  if (match == null) return null;
  return match.group(1) ?? match.group(2);
}

String? _singleSpDpNumber(String rawNumber) {
  final match = _singleSpDpPattern.firstMatch(rawNumber.trim());
  if (match == null) return null;
  return match.group(1) ?? match.group(4);
}

String? _singleSpDpType(String rawNumber) {
  final match = _singleSpDpPattern.firstMatch(rawNumber.trim());
  if (match == null) return null;
  return match.group(2) ?? match.group(3);
}

String _formatAmount(num amount) {
  final text = amount.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

bool _isMotorPanaCode(String? value) {
  final normalized =
      value?.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_') ?? '';
  return normalized == 'SP_MOTOR' ||
      normalized == 'MOTOR' ||
      normalized == 'MOTORPANA' ||
      normalized.startsWith('SP_MOTOR_');
}

int _motorPanaMultiplier(String number) {
  final digits = _digitsOnly(number);
  if (_hasRepeatedDigit(digits)) return 0;
  final uniqueDigits = digits.split('').toSet().length;
  return uniqueDigits >= 3
      ? (uniqueDigits * (uniqueDigits - 1) * (uniqueDigits - 2)) ~/ 6
      : 0;
}

bool _isValidAmountText(String value) {
  final text = value.trim();
  return _amountPattern.hasMatch(text) && _isPositiveAmount(text);
}

bool _isValidJackpotNumber(String value) {
  return _jackpotNumberPattern.hasMatch(value.trim());
}

String? _jackpotNumberError(String value) {
  final number = value.trim();
  if (number.isEmpty || _isValidJackpotNumber(number)) return null;
  return 'Jackpot requires a single digit';
}

String? _familyNumber(String rawNumber) {
  final match = _familyInputPattern.firstMatch(rawNumber.trim());
  if (match == null) return null;
  return match.group(1) ?? match.group(2);
}

String? _cpJodiNumber(String rawNumber) {
  final match = _cpJodiInputPattern.firstMatch(rawNumber.trim());
  if (match == null) return null;
  return match.group(1) ?? match.group(2);
}

String? _commonNumber(String rawNumber) {
  final match = _commonInputPattern.firstMatch(rawNumber.trim());
  if (match == null) return null;
  return match.group(1) ?? match.group(2);
}

int _familyDigitWeight(String digit) {
  return digit == '0' ? 10 : int.parse(digit);
}

String _canonicalFamilyPana(String value) {
  final digits = value.split('');
  digits.sort((a, b) => _familyDigitWeight(a).compareTo(_familyDigitWeight(b)));
  return digits.join();
}

int _familyMultiplierFor(String number) {
  final value = number.trim();
  if (!RegExp(r'^[0-9]{2,3}$').hasMatch(value)) return 0;
  if (value.length == 2) {
    final firstDigit = value[0];
    final secondDigit = value[1];
    final sameFamily = firstDigit == secondDigit ||
        _familyDigitPairs[firstDigit] == secondDigit;
    return sameFamily ? 4 : 8;
  }
  final variants = <String>{};
  for (var mask = 0; mask < 8; mask++) {
    final mapped = <String>[];
    for (var index = 0; index < value.length; index++) {
      final digit = value[index];
      mapped.add(
        (mask & (1 << index)) == 0
            ? digit
            : (_familyDigitPairs[digit] ?? digit),
      );
    }
    variants.add(_canonicalFamilyPana(mapped.join()));
  }
  return variants.length;
}

bool _isAscendingNumberInput(String numberString) {
  final parts =
      numberString.replaceAll('-', '*').replaceAll('>', '*').split('*');
  for (final part in parts) {
    final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < digits.length - 1; i++) {
      final w1 = digits[i] == '0' ? 10 : int.parse(digits[i]);
      final w2 = digits[i + 1] == '0' ? 10 : int.parse(digits[i + 1]);
      if (w1 > w2) return false;
    }
  }
  return true;
}

String? _manualNumberError(String rawNumber, {bool isCloseSession = false}) {
  final value = rawNumber.trim();
  if (value.isEmpty) return null;
  if (value.contains(RegExp(r'[fF]'))) {
    final familyNumber = _familyNumber(value);
    if (familyNumber == null) return 'Use F with 2 or 3-digit family';
    if (_familyMultiplierFor(familyNumber) <= 0) {
      return 'Family number is invalid';
    }
    if (isCloseSession && familyNumber.length == 2) {
      return 'Jodi not allowed in Close';
    }
    return null;
  }
  if (value.contains(RegExp(r'[mM]')) || value.contains(RegExp(r'[cC][oO]'))) {
    final commonNumber = _commonNumber(value);
    return commonNumber == null ? 'Use CM with single digit' : null;
  }
  if (value.contains(RegExp(r'[cC]'))) {
    if (_singleCutPNumber(value) != null) return null;
    final commonNumber = _commonNumber(value);
    if (commonNumber != null) return null;
    final cpJodiNumber = _cpJodiNumber(value);
    if (cpJodiNumber == null) {
      return 'Use CM with single digit or CP with 2-digit Jodi';
    }
    if (isCloseSession) return null;
    return _isAscendingNumberInput(cpJodiNumber) ? null : 'Ascending only';
  }
  if (_isManualMotorPanaNumber(value) && _hasRepeatedDigit(value)) {
    return 'Repeat not allowed in MP';
  }
  if (RegExp(r'^\d{9,}$').hasMatch(value)) {
    return 'Max 8 digits allowed';
  }
  if (isCloseSession) {
    final bazarSangamNumber = _bazarSangamNumber(value);
    if (bazarSangamNumber != null) return 'BZ not allowed in Close';
    if (_isManualSangamNumber(value)) return 'Sangam not allowed in Close';
    if (_isManualJodiNumber(value)) return 'Jodi not allowed in Close';
  }
  if (_letterPattern.hasMatch(value)) {
    if (_commonInputPattern.hasMatch(value)) return null;
    if (_singleSpDpNumber(value) != null) return null;
    if (_singleCutPPattern.hasMatch(value)) return null;
    final bazarSangamNumber = _bazarSangamNumber(value);
    if (bazarSangamNumber != null) {
      if (!_isManualSangamNumber(bazarSangamNumber)) {
        return 'Use BZ only with Sangam';
      }
      return _isAscendingNumberInput(bazarSangamNumber)
          ? null
          : 'Ascending only';
    }
    return 'Use single digit SP/DP/CM or BZ Sangam only';
  }
  if (RegExp(r'^[0-9]{2}$').hasMatch(value)) return null;
  return _isAscendingNumberInput(value) ? null : 'Ascending only';
}

String? _bazarSangamNumber(String rawNumber) {
  final match = _bazarSangamPattern.firstMatch(rawNumber.trim());
  final number = match?.group(1)?.trim();
  return number == null || number.isEmpty ? null : number;
}

bool _isManualSangamNumber(String rawNumber) {
  return rawNumber
      .trim()
      .replaceAll('-', '*')
      .replaceAll('>', '*')
      .contains('*');
}

bool _isManualJodiNumber(String rawNumber) {
  return RegExp(r'^\d{2}$').hasMatch(rawNumber.trim());
}

bool _isManualMotorPanaNumber(String rawNumber) {
  return RegExp(r'^\d{4,8}$').hasMatch(rawNumber.trim());
}

String _effectiveEntrySession(String session, String? override) {
  final value = override?.trim();
  return value == 'Close' || value == 'Open' ? value! : session;
}

List<_JackpotLine> _filledJackpotEntries(
  _BetEntry entry, {
  int multiplier = 1,
  bool allowJackpot = true,
}) {
  if (!allowJackpot ||
      !entry.isJackpot ||
      _cpJodiNumber(entry.number.text) != null ||
      _familyNumber(entry.number.text) != null ||
      _isManualSangamNumber(entry.number.text)) {
    return const [];
  }
  final rows = <_JackpotLine>[];
  for (var index = 0; index < entry.jackpotRowCount; index++) {
    final number = entry.jackpotNumbers[index].text.trim();
    final rawAmount = entry.jackpotAmounts[index].text.trim();
    final parsedAmount = num.tryParse(rawAmount);
    final calculatedAmount =
        parsedAmount == null ? '' : _formatAmount(parsedAmount * multiplier);
    if (_isValidJackpotNumber(number)) {
      rows.add(_JackpotLine(
        number: number,
        amount: parsedAmount == null ? rawAmount : _formatAmount(parsedAmount),
        calculatedAmount: calculatedAmount,
      ));
    }
  }
  return rows;
}

num _jackpotAmountTotal(List<_JackpotLine> entries) {
  return entries.fold<num>(
    0,
    (total, entry) => total + _parseAmount(entry.calculatedAmount),
  );
}

Map<String, Object>? _receiptLineComponents(_ReceiptLine line) {
  final components = <String, Object>{};
  if (line.displayAmount != null) {
    components['displayAmount'] = line.displayAmount!;
  }
  if (line.isBazarSangam) {
    components['bazar'] = true;
  }
  if (line.isFamily) {
    components['family'] = true;
    if (line.familyMultiplier != null) {
      components['familyMultiplier'] = line.familyMultiplier!;
    }
  }
  if (line.isCpJodi) {
    components['cp'] = true;
    components['cpMultiplier'] = 10;
  }
  if (line.isCommon) {
    components['common'] = true;
    components['commonMultiplier'] = _commonMultiplier;
  }
  if (line.jackpotEntries.isNotEmpty) {
    components['jackpotEntries'] = line.jackpotEntries
        .map(
          (entry) => {
            'number': entry.number,
            'amount': entry.amount,
            if (entry.calculatedAmount.isNotEmpty)
              'calculatedAmount': entry.calculatedAmount,
          },
        )
        .toList();
  }
  return components.isEmpty ? null : components;
}

Map<String, dynamic> _receiptLinePayload(_ReceiptLine line) {
  final components = _receiptLineComponents(line);
  return {
    'type': line.backendType,
    'number': line.number,
    'amount': _parseAmount(line.amount),
    'mode': line.isManual ? 'Manual' : 'Auto',
    'isJackpot': line.isJackpot,
    if (line.sessionOverride != null) 'sessionOverride': line.sessionOverride,
    if (!line.isManual) 'betType': line.betType,
    if (line.betSubtype != null) 'betSubtype': line.betSubtype,
    if (components != null) 'components': components,
  };
}

class _NewEntryPageState extends ConsumerState<NewEntryPage> {
  static const _blue = Color(0xFF064DB5);
  static const _green = Color(0xFF108438);
  static const _red = Color(0xFFF20D16);
  static const _line = Color(0xFFD8DCE3);

  final _manualEntries = <_BetEntry>[
    _BetEntry(number: '', amount: ''),
  ];
  final _autoEntries = <_AutoBetEntry>[];
  final _autoSearch = TextEditingController();

  ReceiptMarket? _market;
  List<ReceiptMarket> _markets = const [];
  GameConfigModel? _gameConfig;
  String _session = 'Open';
  final Set<int> _otcPages = <int>{};
  final String _mode = 'MANUAL';
  String _selectedAutoTypeId = '';
  String? _selectedAutoSubtypeId;
  int? _selectedColumn;
  bool _isLoadingData = false;
  bool _saving = false;
  String? _autoSearchError;
  int? _amountFillStartIndex;
  int? _amountFillEndIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshLocalizedInputs();
  }

  void _refreshLocalizedInputs() {
    for (final entry in _manualEntries) {
      (entry.number as _LocalizedDigitsController).refreshLocale();
      (entry.amount as _LocalizedDigitsController).refreshLocale();
      for (final controller in entry.jackpotNumbers) {
        (controller as _LocalizedDigitsController).refreshLocale();
      }
      for (final controller in entry.jackpotAmounts) {
        (controller as _LocalizedDigitsController).refreshLocale();
      }
    }
  }

  ReceiptMarket? get _selectedMarket {
    if (_markets.isEmpty) return null;
    final availableMarkets =
        _markets.where((market) => market.canEnter).toList();
    if (_market == null) {
      return availableMarkets.isEmpty ? null : availableMarkets.first;
    }
    for (final market in _markets) {
      if (market.id == _market!.id && market.canEnter) return market;
    }
    return availableMarkets.isEmpty ? null : availableMarkets.first;
  }

  final Map<String, int> _localParchiCounters = {};

  String get _previewParchiNo {
    if (_market == null) return 'NEW';
    final count = _localParchiCounters[_market!.id] ?? 1;
    final marketName = _market!.name.trim().toUpperCase();
    final parts = marketName.split(RegExp(r'\s+'));

    String prefix = 'M';
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      prefix = '${parts[0][0]}${parts[1][0]}';
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      prefix = parts[0][0];
    }

    return '$prefix${count.toString().padLeft(2, '0')}';
  }

  bool get _isAutoMode => _mode == 'AUTO';

  bool _isCloseBlockedAutoType(GameBetTypeConfig type) {
    final betType =
        type.betType.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final backendType = type.backendType
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    return betType == 'JODI' ||
        backendType == 'JODI' ||
        betType == 'HALF_SANGAM' ||
        betType == 'FULL_SANGAM' ||
        backendType == 'HALF_SANGAM' ||
        backendType == 'FULL_SANGAM';
  }

  List<GameBetTypeConfig> get _autoConfigs {
    final types = _gameConfig?.autoTypes ?? const <GameBetTypeConfig>[];
    return types
        .where((t) =>
            !(_session == 'Close' && _isCloseBlockedAutoType(t)) &&
            t.id != 'dp_motor' &&
            t.id != 'mp' &&
            t.label.toUpperCase() != 'MP' &&
            t.label.toUpperCase() != 'MOTOR PATTI')
        .map((t) {
      if (t.id == 'sp_motor') {
        return GameBetTypeConfig(
          id: t.id,
          label: 'MotorPana',
          betType: t.betType,
          backendType: t.backendType,
          enabled: t.enabled,
          requiresSubtype: t.requiresSubtype,
          allowedLength: t.allowedLength,
          options: t.options,
          subtypes: t.subtypes,
          missingRule: t.missingRule,
        );
      }
      return t;
    }).toList();
  }

  GameBetTypeConfig? get _selectedAutoType {
    for (final type in _autoConfigs) {
      if (type.id == _selectedAutoTypeId) return type;
    }
    return _autoConfigs.isEmpty ? null : _autoConfigs.first;
  }

  GameBetSubtypeConfig? get _selectedAutoSubtype {
    final type = _selectedAutoType;
    if (type == null || !type.requiresSubtype) return null;
    for (final subtype in type.subtypes) {
      if (subtype.id == _selectedAutoSubtypeId) return subtype;
    }
    return type.subtypes.isEmpty ? null : type.subtypes.first;
  }

  List<GameNumberOption> get _selectedAutoNumberOptions {
    final type = _selectedAutoType;
    if (type == null) return const [];
    return type.requiresSubtype
        ? (_selectedAutoSubtype?.options ?? const <GameNumberOption>[])
        : type.options;
  }

  List<GameNumberOption> get _currentNumberOptions {
    final options = _selectedAutoNumberOptions;
    final search = _autoSearch.text.trim();
    return options.where((option) {
      final matchesColumn =
          _selectedColumn == null || option.column == _selectedColumn;
      return matchesColumn && _matchesAutoNumberSearch(option.value, search);
    }).toList(growable: false);
  }

  List<_AutoBetEntry> get _selectedAutoEntries =>
      _autoEntries.where(_isEntryForSelectedAutoConfig).toList(growable: false);

  List<int> get _availableColumns {
    final type = _selectedAutoType;
    final options = type?.requiresSubtype == true
        ? (_selectedAutoSubtype?.options ?? const <GameNumberOption>[])
        : (type?.options ?? const <GameNumberOption>[]);
    final columns = options
        .map((option) => option.column)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    return columns;
  }

  bool get _showAutoNumberTable {
    return _selectedAutoNumberOptions.isNotEmpty;
  }

  bool get _hasBazarInput =>
      !_isAutoMode &&
      _manualEntries.any(
        (entry) => _bazarSangamNumber(entry.number.text) != null,
      );

  bool get _canUseOtc => _session == 'Open' && !_hasBazarInput;

  List<List<_ReceiptLine>> get _receiptPages =>
      _receiptLinePages(_receiptLines);

  Set<int> get _activeOtcPages {
    if (!_canUseOtc) return <int>{};
    final pageCount = _receiptPages.length;
    return _otcPages
        .where((pageIndex) => pageIndex >= 0 && pageIndex < pageCount)
        .toSet();
  }

  bool get _areAllReceiptPagesOtcActive {
    if (!_canUseOtc) return false;
    final pages = _receiptPages;
    if (pages.isEmpty) return false;
    final activePages = _activeOtcPages;
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      if (!activePages.contains(pageIndex)) return false;
    }
    return true;
  }

  bool get _hasAnyOtcPage => _activeOtcPages.isNotEmpty;

  num get _totalAmount {
    final pages = _receiptPages;
    final otcPages = _activeOtcPages;
    num total = 0;
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      total += _receiptPageTotal(
        pages[pageIndex],
        isOtc: otcPages.contains(pageIndex),
      );
    }
    return total;
  }

  int get _totalBets => _receiptLines.length;

  bool get _canSave =>
      !_saving &&
      _selectedMarket != null &&
      _selectedMarket!.canEnter &&
      _receiptLines.isNotEmpty &&
      (_isAutoMode
          ? _autoEntries
              .where((entry) => entry.hasAnyValue)
              .every(_isValidAutoEntry)
          : _manualEntries
              .where((entry) => entry.hasAnyValue)
              .every(_isValidManualEntry));

  String _effectiveManualSession(_BetEntry entry) {
    return _effectiveEntrySession(_session, entry.sessionOverride);
  }

  String? _manualEntryError(_BetEntry entry) {
    final isCloseSession = _effectiveManualSession(entry) == 'Close';
    if (isCloseSession && entry.isJackpot) {
      return 'Jackpot not allowed in Close';
    }
    if (_isManualJodiNumber(entry.number.text) && entry.isJackpot) {
      return 'Jackpot not allowed in Jodi';
    }
    if (entry.isJackpot) {
      for (var index = 0; index < entry.jackpotRowCount; index++) {
        final error = _jackpotNumberError(entry.jackpotNumbers[index].text);
        if (error != null) return error;
      }
    }
    return _manualNumberError(
      entry.number.text,
      isCloseSession: isCloseSession,
    );
  }

  void _syncManualEntryRules() {
    for (final entry in _manualEntries) {
      if (_session == 'Close') {
        entry.sessionOverride = null;
      }
      if (_effectiveManualSession(entry) == 'Close' ||
          _isManualJodiNumber(entry.number.text)) {
        entry.isJackpot = false;
      }
      entry.error = _manualEntryError(entry);
    }
  }

  List<_ReceiptLine> get _receiptLines {
    final lines = <_ReceiptLine>[];
    if (_isAutoMode) {
      for (final entry in _autoEntries) {
        if (entry.hasAnyValue && _isValidAutoEntry(entry)) {
          final type = _configFor(entry.typeId);
          if (type == null) continue;
          final subtype = _subtypeFor(type, entry.subtypeId);

          num finalAmount = _parseAmount(entry.amount.text);
          final numberText = entry.number.text.trim();

          if (subtype?.id == 'sp_motor') {
            final n = numberText
                .replaceAll(RegExp(r'[^0-9]'), '')
                .split('')
                .toSet()
                .length;
            if (n >= 3) {
              final combinations = (n * (n - 1) * (n - 2)) ~/ 6;
              finalAmount = finalAmount * combinations;
            } else {
              finalAmount = 0;
            }
          } else if (subtype?.id == 'dp_motor') {
            final n = numberText
                .replaceAll(RegExp(r'[^0-9]'), '')
                .split('')
                .toSet()
                .length;
            if (n >= 2) {
              final combinations = n * (n - 1);
              finalAmount = finalAmount * combinations;
            } else {
              finalAmount = 0;
            }
          }

          final isAutoJodi =
              type.betType == 'JODI' || type.backendType == 'Jodi';
          lines.add(_ReceiptLine(
            backendType: type.backendType,
            betType: type.betType,
            betSubtype: subtype?.id,
            number: numberText,
            amount: _formatAmount(finalAmount),
            isManual: false,
            isJackpot: _session == 'Open' && !isAutoJodi && entry.isJackpot,
          ));
        }
      }
    } else {
      for (final entry in _manualEntries) {
        if (entry.number.text.trim().isNotEmpty &&
            entry.amount.text.trim().isNotEmpty) {
          if (!_isValidManualEntry(entry)) continue;
          final String rawNumber = entry.number.text.trim();
          final String? sessionOverride =
              _session == 'Open' ? entry.sessionOverride : null;
          if (_manualNumberError(
                rawNumber,
                isCloseSession: (sessionOverride ?? _session) == 'Close',
              ) !=
              null) {
            continue;
          }
          final familyNumber = _familyNumber(rawNumber);
          if (familyNumber != null) {
            final baseAmount = _parseAmount(entry.amount.text);
            final multiplier = _familyMultiplierFor(familyNumber);
            final calculatedAmount = baseAmount * multiplier;
            lines.add(_ReceiptLine(
              backendType: familyNumber.length == 2 ? 'Jodi' : 'Patti',
              betType: familyNumber.length == 2 ? 'JODI' : 'PANNA',
              betSubtype: 'family',
              number: familyNumber,
              amount: _formatAmount(calculatedAmount),
              displayAmount: _formatAmount(baseAmount),
              isManual: true,
              isJackpot: false,
              isFamily: true,
              familyMultiplier: multiplier,
              sessionOverride: sessionOverride,
            ));
            continue;
          }
          final cpJodiNumber = _cpJodiNumber(rawNumber);
          if (cpJodiNumber != null) {
            final baseAmount = _parseAmount(entry.amount.text);
            final calculatedAmount = baseAmount * 10;
            lines.add(_ReceiptLine(
              backendType: 'Jodi',
              betType: 'JODI',
              betSubtype: 'cp',
              number: cpJodiNumber,
              amount: _formatAmount(calculatedAmount),
              displayAmount: _formatAmount(baseAmount),
              isManual: true,
              isJackpot: false,
              isCpJodi: true,
              sessionOverride: sessionOverride,
            ));
            continue;
          }
          final commonNumber = _commonNumber(rawNumber);
          if (commonNumber != null) {
            final baseAmount = _parseAmount(entry.amount.text);
            final calculatedAmount = baseAmount * _commonMultiplier;
            final canUseJackpot =
                (sessionOverride ?? _session) == 'Open' && entry.isJackpot;
            final jackpotEntries = canUseJackpot
                ? _filledJackpotEntries(
                    entry,
                    multiplier: _commonMultiplier,
                  )
                : const <_JackpotLine>[];
            final totalAmount =
                calculatedAmount + _jackpotAmountTotal(jackpotEntries);
            lines.add(_ReceiptLine(
              backendType: 'Single',
              betType: 'SINGLE',
              betSubtype: 'common',
              number: commonNumber,
              amount: _formatAmount(totalAmount),
              displayAmount: _formatAmount(baseAmount),
              isManual: true,
              isJackpot: canUseJackpot,
              isCommon: true,
              jackpotEntries: jackpotEntries,
              sessionOverride: sessionOverride,
            ));
            continue;
          }
          final bazarSangamNumber = _bazarSangamNumber(rawNumber);
          final String entryNumber = bazarSangamNumber ?? rawNumber;

          final spDpDigit = _singleSpDpNumber(entryNumber);
          final spDpType = _singleSpDpType(entryNumber)?.toLowerCase();

          if (spDpDigit != null && spDpType != null) {
            final digit = spDpDigit;
            final baseAmount = _parseAmount(entry.amount.text);
            final multiplier = spDpType == 'sp' ? 12 : 10;
            final calculatedAmount = baseAmount * multiplier;
            final canUseJackpot =
                (sessionOverride ?? _session) == 'Open' && entry.isJackpot;
            final jackpotEntries = canUseJackpot
                ? _filledJackpotEntries(entry, multiplier: multiplier)
                : const <_JackpotLine>[];
            final totalAmount =
                calculatedAmount + _jackpotAmountTotal(jackpotEntries);
            lines.add(_ReceiptLine(
              backendType: 'Single',
              betType: 'SINGLE',
              number: '$digit ${spDpType.toUpperCase()}',
              amount: _formatAmount(totalAmount),
              displayAmount: _formatAmount(baseAmount),
              isManual: true,
              isJackpot: canUseJackpot,
              jackpotEntries: jackpotEntries,
              sessionOverride: sessionOverride,
            ));
            continue;
          }

          final cutPNumber = _singleCutPNumber(entryNumber);
          if (cutPNumber != null) {
            final baseAmount = _parseAmount(entry.amount.text);
            const multiplier = 5;
            final calculatedAmount = baseAmount * multiplier;
            final canUseJackpot =
                (sessionOverride ?? _session) == 'Open' && entry.isJackpot;
            final jackpotEntries = canUseJackpot
                ? _filledJackpotEntries(entry, multiplier: multiplier)
                : const <_JackpotLine>[];
            final totalAmount =
                calculatedAmount + _jackpotAmountTotal(jackpotEntries);
            lines.add(_ReceiptLine(
              backendType: 'Single',
              betType: 'SINGLE',
              betSubtype: 'cut_p',
              number: '$cutPNumber CUT P',
              amount: _formatAmount(totalAmount),
              displayAmount: _formatAmount(baseAmount),
              isManual: true,
              isJackpot: canUseJackpot,
              jackpotEntries: jackpotEntries,
              sessionOverride: sessionOverride,
            ));
            continue;
          }

          final number = entryNumber.replaceAll('-', '*').replaceAll('>', '*');
          String backendType = 'Patti';
          String? betType;
          String? betSubtype;
          final baseAmount = _parseAmount(entry.amount.text);
          num finalAmount = baseAmount;
          int jackpotMultiplier = 1;
          String? displayAmount;

          if (number.length == 1) {
            backendType = 'Single';
          } else if (number.length == 2) {
            backendType = 'Jodi';
          } else if (number.contains('*')) {
            backendType = 'Full Sangam';
            if (bazarSangamNumber == null) {
              finalAmount = baseAmount;
            } else {
              finalAmount = baseAmount * 10;
              displayAmount = _formatAmount(baseAmount);
            }
          } else if (number.length >= 4) {
            backendType = 'Patti';
            betType = 'SP_MOTOR';
            betSubtype = 'sp_motor';
            final multiplier = _motorPanaMultiplier(number);
            jackpotMultiplier = multiplier;
            if (multiplier > 0) {
              finalAmount = baseAmount * multiplier;
              displayAmount = _formatAmount(baseAmount);
            } else {
              finalAmount = 0;
            }
          }

          betType ??= backendType.toUpperCase().replaceAll(' ', '_');
          final isFullSangam = backendType == 'Full Sangam';
          final isBazarSangam = isFullSangam && bazarSangamNumber != null;
          final allowJackpot = backendType != 'Jodi' && !isFullSangam;
          final canUseJackpot = allowJackpot &&
              (sessionOverride ?? _session) == 'Open' &&
              entry.isJackpot;
          final jackpotEntries = isFullSangam || !canUseJackpot
              ? const <_JackpotLine>[]
              : _filledJackpotEntries(
                  entry,
                  multiplier: jackpotMultiplier,
                  allowJackpot: allowJackpot,
                );
          final totalAmount = isFullSangam
              ? finalAmount
              : finalAmount + _jackpotAmountTotal(jackpotEntries);
          final lineDisplayAmount = displayAmount ??
              (jackpotEntries.isNotEmpty ? _formatAmount(finalAmount) : null);

          lines.add(_ReceiptLine(
            backendType: backendType,
            betType: betType,
            betSubtype: betSubtype,
            number: number,
            amount: _formatAmount(totalAmount),
            displayAmount: lineDisplayAmount,
            isManual: true,
            isJackpot: !isFullSangam && canUseJackpot,
            isBazarSangam: isBazarSangam,
            jackpotEntries: jackpotEntries,
            sessionOverride: sessionOverride,
          ));
        }
      }
    }
    return lines;
  }

  @override
  void initState() {
    super.initState();
    final draft = ref.read(newEntryDraftProvider);
    _applyDraft(draft, disposeExisting: true);
    _clearDisallowedJackpots();
    _syncOtcAvailability();

    Future.microtask(
      () => ref.read(authProvider.notifier).refreshAccessStatus(),
    );
  }

  @override
  void dispose() {
    // Save draft BEFORE calling super.dispose (ref becomes invalid after)
    try {
      final draftEntries = _manualEntries
          .map((e) => BetEntryData(
                number: e.number.text,
                amount: e.amount.text,
                isJackpot: (_session == 'Close' ||
                        (e.sessionOverride ?? _session) == 'Close' ||
                        _cpJodiNumber(e.number.text) != null ||
                        _familyNumber(e.number.text) != null ||
                        _isManualSangamNumber(e.number.text))
                    ? false
                    : e.isJackpot,
                jackpotEntries: List<JackpotEntryData>.generate(
                  e.jackpotRowCount,
                  (index) => JackpotEntryData(
                    number: e.jackpotNumbers[index].text.trim(),
                    amount: e.jackpotAmounts[index].text.trim(),
                  ),
                ),
                sessionOverride: _session == 'Close' ? null : e.sessionOverride,
              ))
          .toList();
      ref.read(newEntryDraftProvider.notifier).updateDraft(NewEntryDraftState(
            market: _market,
            session: _session,
            isOtc: _hasAnyOtcPage,
            otcPages: _activeOtcPages,
            localParchiCounters: _localParchiCounters,
            manualEntries: draftEntries,
          ));
    } catch (_) {}

    for (final entry in _manualEntries) {
      entry.dispose();
    }
    for (final entry in _autoEntries) {
      entry.dispose();
    }
    _autoSearch.dispose();
    super.dispose();
  }

  void _applyDraft(
    NewEntryDraftState draft, {
    required bool disposeExisting,
  }) {
    if (disposeExisting) {
      for (final entry in _manualEntries) {
        entry.dispose();
      }
    }
    _market = draft.market;
    _session = draft.session;
    _otcPages
      ..clear()
      ..addAll(draft.otcPages.isEmpty && draft.isOtc ? {0} : draft.otcPages);
    _localParchiCounters
      ..clear()
      ..addAll(draft.localParchiCounters);
    _manualEntries.clear();
    final entries = draft.manualEntries.isEmpty
        ? [BetEntryData(number: '', amount: '')]
        : draft.manualEntries;
    for (final entry in entries) {
      _manualEntries.add(_BetEntry(
        number: entry.number,
        amount: entry.amount,
        jackpotEntries: entry.jackpotEntries,
      )
        ..isJackpot = (_session == 'Close' ||
                entry.sessionOverride == 'Close' ||
                _cpJodiNumber(entry.number) != null ||
                _familyNumber(entry.number) != null ||
                _isManualSangamNumber(entry.number))
            ? false
            : entry.isJackpot
        ..sessionOverride = _session == 'Close' ? null : entry.sessionOverride);
    }
  }

  List<BetEntryData> _draftManualEntries() {
    return _manualEntries
        .map((entry) => BetEntryData(
              number: entry.number.text,
              amount: entry.amount.text,
              isJackpot: (_session == 'Close' ||
                      (entry.sessionOverride ?? _session) == 'Close' ||
                      _cpJodiNumber(entry.number.text) != null ||
                      _familyNumber(entry.number.text) != null ||
                      _isManualSangamNumber(entry.number.text))
                  ? false
                  : entry.isJackpot,
              jackpotEntries: List<JackpotEntryData>.generate(
                entry.jackpotRowCount,
                (index) => JackpotEntryData(
                  number: entry.jackpotNumbers[index].text.trim(),
                  amount: entry.jackpotAmounts[index].text.trim(),
                ),
              ),
              sessionOverride:
                  _session == 'Close' ? null : entry.sessionOverride,
            ))
        .toList();
  }

  void _persistCurrentDraft() {
    unawaited(
      ref.read(newEntryDraftProvider.notifier).updateDraft(NewEntryDraftState(
            userId: ref.read(authProvider).user?.id,
            market: _market,
            session: _session,
            isOtc: _hasAnyOtcPage,
            otcPages: _activeOtcPages,
            localParchiCounters: Map<String, int>.from(_localParchiCounters),
            manualEntries: _draftManualEntries(),
          )),
    );
  }

  void _syncOtcAvailability() {
    if (!_canUseOtc) {
      _otcPages.clear();
      return;
    }
    final pageCount = _receiptPages.length;
    _otcPages.removeWhere(
      (pageIndex) => pageIndex < 0 || pageIndex >= pageCount,
    );
  }

  void _clearDisallowedJackpots() {
    for (final entry in _manualEntries) {
      final raw = entry.number.text.trim();
      final effectiveSession = entry.sessionOverride ?? _session;
      if (_session == 'Close') {
        entry.sessionOverride = null;
      }
      if (_session == 'Close' ||
          effectiveSession == 'Close' ||
          _cpJodiNumber(raw) != null ||
          _familyNumber(raw) != null ||
          _isManualSangamNumber(raw)) {
        entry.isJackpot = false;
      }
    }
    if (_session == 'Close') {
      for (final entry in _autoEntries) {
        entry.isJackpot = false;
      }
    }
  }

  void _selectSession(String value) {
    setState(() {
      _session = value;
      _clearDisallowedJackpots();
      _syncManualEntryRules();
      _syncOtcAvailability();
    });
    _persistCurrentDraft();
  }

  void _handleManualEntriesChanged() {
    setState(() {
      _clearDisallowedJackpots();
      _syncOtcAvailability();
    });
  }

  void _toggleOtc() {
    setState(() {
      if (!_canUseOtc) {
        _otcPages.clear();
      } else {
        final pageIndexes = Iterable<int>.generate(_receiptPages.length);
        if (_areAllReceiptPagesOtcActive) {
          _otcPages.removeWhere(pageIndexes.toSet().contains);
        } else {
          _otcPages.addAll(pageIndexes);
        }
      }
    });
    _persistCurrentDraft();
  }

  void _focusManualNumber(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index < 0 || index >= _manualEntries.length) return;
      _manualEntries[index].numberFocus.requestFocus();
    });
  }

  void _handleManualRowSubmitted(int index) {
    final nextIndex = index + 1;
    if (nextIndex < _manualEntries.length) {
      _focusManualNumber(nextIndex);
      return;
    }
    _addEntry();
  }

  void _addEntry() {
    final newIndex = _manualEntries.length;
    setState(() => _manualEntries.add(_BetEntry(number: '', amount: '')));
    _focusManualNumber(newIndex);
    _persistCurrentDraft();
  }

  void _removeEntry(int index) {
    if (_manualEntries.length == 1) {
      setState(() {
        _manualEntries[index].number.clear();
        _manualEntries[index].amount.clear();
        _manualEntries[index].isJackpot = false;
        for (final controller in _manualEntries[index].jackpotNumbers) {
          controller.clear();
        }
        for (final controller in _manualEntries[index].jackpotAmounts) {
          controller.clear();
        }
        _manualEntries[index].jackpotRowCount = 1;
        _syncOtcAvailability();
      });
      _persistCurrentDraft();
      return;
    }
    setState(() {
      _manualEntries.removeAt(index).dispose();
      _syncOtcAvailability();
    });
  }

  void _selectMarket(ReceiptMarket market) {
    setState(() {
      _market = market;
    });
    _persistCurrentDraft();
    if (market.canEnter) {
      ref
          .read(newEntryControllerProvider.notifier)
          .loadGameConfigForMarket(market.id);
    }
  }

  void _startAmountFill(int index) {
    final value = _manualEntries[index].amount.text.trim();
    if (!_isValidAmountText(value)) return;
    setState(() {
      _amountFillStartIndex = index;
      _amountFillEndIndex = index;
    });
  }

  void _hoverAmountFill(int index) {
    if (_amountFillStartIndex == null) return;
    setState(() {
      _amountFillEndIndex = index;
    });
  }

  void _endAmountFill() {
    final start = _amountFillStartIndex;
    final end = _amountFillEndIndex;
    if (start == null || end == null) {
      return;
    }
    final value = _manualEntries[start].amount.text.trim();
    setState(() {
      if (_isValidAmountText(value) && end > start) {
        for (var index = start + 1; index <= end; index++) {
          _manualEntries[index].amount.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
        }
      }
      _amountFillStartIndex = null;
      _amountFillEndIndex = null;
    });
    _persistCurrentDraft();
  }

  void _fillAmountBelow(int index) {
    if (index < 0 || index >= _manualEntries.length) return;
    final value = _manualEntries[index].amount.text.trim();
    if (!_isValidAmountText(value) || index >= _manualEntries.length - 1) {
      return;
    }
    setState(() {
      for (var targetIndex = index + 1;
          targetIndex < _manualEntries.length;
          targetIndex++) {
        _manualEntries[targetIndex].amount.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    });
    _handleManualEntriesChanged();
  }

  void _selectAutoType(String typeId) {
    setState(() {
      _selectedAutoTypeId = typeId;
      final type = _selectedAutoType;
      _selectedAutoSubtypeId =
          type?.requiresSubtype == true && type!.subtypes.isNotEmpty
              ? type.subtypes.first.id
              : null;
      _selectedColumn = null;
      _autoSearch.clear();
      _ensureAutoRowForSelection();
    });
  }

  void _selectAutoSubtype(String subtypeId) {
    setState(() {
      _selectedAutoSubtypeId = subtypeId;
      _selectedColumn = null;
      _autoSearch.clear();
      _ensureAutoRowForSelection();
    });
  }

  void _selectColumn(int? column) {
    setState(() {
      _selectedColumn = column;
    });
  }

  String? _motorAutoSearchError(String inputText) {
    final value = inputText.trim();
    if (value.isEmpty || !_isMotorAutoType(_selectedAutoType)) return null;
    if (_hasRepeatedDigit(value)) return 'Repeat not allowed in MP';
    return _isAscendingNumberInput(value) ? null : 'Ascending only';
  }

  void _onAutoSearchChanged() {
    setState(() {
      _autoSearchError = _motorAutoSearchError(_autoSearch.text);
    });
  }

  void _selectAutoNumber(GameNumberOption option) {
    final type = _selectedAutoType;
    final subtype = _selectedAutoSubtype;
    if (type == null || (type.requiresSubtype && subtype == null)) return;
    setState(() {
      final rows = _selectedAutoEntries;
      _AutoBetEntry? target;
      for (final row in rows) {
        if (row.number.text.trim().isEmpty) {
          target = row;
          break;
        }
      }
      target ??= _newAutoEntryFor(type, subtype);
      if (!rows.contains(target)) {
        _autoEntries.add(target);
      }
      target.number.text = option.value;
    });
  }

  void _addAutoEntries([int count = 1]) {
    final type = _selectedAutoType;
    final subtype = _selectedAutoSubtype;
    if (type == null || _selectedAutoNumberOptions.isEmpty) return;
    if (type.requiresSubtype && subtype == null) return;
    setState(() {
      for (var index = 0; index < count; index++) {
        _autoEntries.add(_newAutoEntryFor(type, subtype));
      }
    });
  }

  void _ensureAutoEntryCount(int targetCount) {
    final type = _selectedAutoType;
    final subtype = _selectedAutoSubtype;
    if (type == null || _selectedAutoNumberOptions.isEmpty) return;
    if (type.requiresSubtype && subtype == null) return;
    setState(() {
      final existingCount = _selectedAutoEntries.length;
      for (var index = existingCount; index < targetCount; index++) {
        _autoEntries.add(_newAutoEntryFor(type, subtype));
      }
    });
  }

  void _removeAutoEntry(_AutoBetEntry entry) {
    if (_selectedAutoEntries.length == 1) {
      setState(() {
        entry.number.clear();
        entry.amount.clear();
      });
      return;
    }
    setState(() {
      _autoEntries.remove(entry);
      entry.dispose();
    });
  }

  GameBetTypeConfig? _configFor(String typeId) {
    for (final type in _autoConfigs) {
      if (type.id == typeId) return type;
    }
    return null;
  }

  GameBetSubtypeConfig? _subtypeFor(
    GameBetTypeConfig type,
    String? subtypeId,
  ) {
    if (subtypeId == null) return null;
    for (final subtype in type.subtypes) {
      if (subtype.id == subtypeId) return subtype;
    }
    return null;
  }

  List<GameNumberOption> _optionsForAutoEntry(_AutoBetEntry entry) {
    final type = _configFor(entry.typeId);
    if (type == null) return const [];
    if (!type.requiresSubtype) return type.options;
    return _subtypeFor(type, entry.subtypeId)?.options ??
        const <GameNumberOption>[];
  }

  String? _autoNumberError(_AutoBetEntry entry) {
    final value = entry.number.text.trim();
    if (value.isEmpty) return 'Number is required';
    final options = _optionsForAutoEntry(entry);
    if (!options.any((option) => option.value == value)) {
      return 'Select configured number';
    }
    return null;
  }

  String? _autoAmountError(_AutoBetEntry entry) {
    final value = entry.amount.text.trim();
    if (value.isEmpty) return 'Amount is required';
    if (!_isValidAmountText(value)) return 'Enter amount above 0';
    return null;
  }

  bool _isValidAutoEntry(_AutoBetEntry entry) {
    return _autoNumberError(entry) == null && _autoAmountError(entry) == null;
  }

  bool _isValidManualEntry(_BetEntry entry) {
    final number = entry.number.text.trim();
    return number.isNotEmpty &&
        _isValidAmountText(entry.amount.text) &&
        _manualEntryError(entry) == null &&
        entry.error == null;
  }

  bool _isEntryForSelectedAutoConfig(_AutoBetEntry entry) {
    final type = _selectedAutoType;
    if (type == null || entry.typeId != type.id) return false;
    final selectedSubtypeId =
        type.requiresSubtype ? _selectedAutoSubtype?.id : null;
    return entry.subtypeId == selectedSubtypeId;
  }

  _AutoBetEntry _newAutoEntryFor(
    GameBetTypeConfig type,
    GameBetSubtypeConfig? subtype,
  ) {
    return _AutoBetEntry(
      typeId: type.id,
      subtypeId: subtype?.id,
      number: '',
      amount: '',
    );
  }

  void _ensureAutoRowForSelection() {
    final type = _selectedAutoType;
    final subtype = _selectedAutoSubtype;
    if (type == null || _selectedAutoNumberOptions.isEmpty) return;
    if (type.requiresSubtype && subtype == null) return;
    if (_autoEntries.any(_isEntryForSelectedAutoConfig)) return;
    _autoEntries.add(_newAutoEntryFor(type, subtype));
  }

  void _syncAutoSelection() {
    if (_autoConfigs.isEmpty) {
      _selectedAutoTypeId = '';
      _selectedAutoSubtypeId = null;
      return;
    }
    if (!_autoConfigs.any((type) => type.id == _selectedAutoTypeId)) {
      _selectedAutoTypeId = _autoConfigs.first.id;
    }
    final type = _selectedAutoType;
    if (type?.requiresSubtype == true) {
      final hasSubtype =
          type!.subtypes.any((subtype) => subtype.id == _selectedAutoSubtypeId);
      if (!hasSubtype) {
        _selectedAutoSubtypeId =
            type.subtypes.isEmpty ? null : type.subtypes.first.id;
      }
    } else {
      _selectedAutoSubtypeId = null;
    }
    if (_isAutoMode) {
      _ensureAutoRowForSelection();
    }
  }

  Future<void> _save({required bool print}) async {
    final market = _selectedMarket;
    if (market == null || !_canSave) return;

    final printerStore = PrinterStore();
    var activePrinter = await printerStore.loadActivePrinter();

    if (activePrinter == null) {
      await printerStore.ensureDefaultPrinterConfiguration();
      activePrinter = await printerStore.loadActivePrinter();
    }

    final shouldPrint = print && activePrinter != null;

    if (print && activePrinter == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No active printer configured. Entry saved without printing.',
          ),
        ),
      );
    }

    bool hasError = false;
    setState(() {
      if (!_isAutoMode) {
        for (final entry in _manualEntries) {
          entry.error = null;
          final rawNumber = entry.number.text.trim();
          if (rawNumber.isNotEmpty && entry.amount.text.trim().isNotEmpty) {
            final error = _manualEntryError(entry);
            if (error != null) {
              entry.error = error;
              hasError = true;
            }
          }
        }
      } else {
        _autoSearchError = null;
        if (_selectedAutoType?.id == 'sp_motor' ||
            _selectedAutoType?.id == 'dp_motor') {
          final error = _motorAutoSearchError(_autoSearch.text);
          if (error != null) {
            hasError = true;
            _autoSearchError = error;
          }
        }
      }
    });
    if (hasError) return;

    final receiptLines = _receiptLines;
    final pages = _receiptLinePages(receiptLines);
    final pageCount = pages.length;
    final activeOtcPages = _activeOtcPages;
    final hasMixedPageOtc = pageCount > 1 &&
        activeOtcPages.isNotEmpty &&
        activeOtcPages.length < pageCount;
    final items = receiptLines.map(_receiptLinePayload).toList();

    if (items.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      final savedReceipts = <ReceiptDetail>[];
      if (hasMixedPageOtc) {
        for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
          final pageItems = pages[pageIndex].map(_receiptLinePayload).toList();
          if (pageItems.isEmpty) continue;
          final receipt =
              await ref.read(newEntryControllerProvider.notifier).saveReceipt(
                    market: market.id,
                    marketName: market.name,
                    session: _session,
                    items: pageItems,
                    isOtc: activeOtcPages.contains(pageIndex),
                    shouldPrint: shouldPrint,
                  );
          if (receipt == null) {
            if (!mounted) return;
            throw StateError(
              AppLocalizations.trCurrent(
                'Receipt page {page} was not saved.',
                params: {'page': pageIndex + 1},
              ),
            );
          }
          savedReceipts.add(receipt);
        }
      } else {
        final receipt =
            await ref.read(newEntryControllerProvider.notifier).saveReceipt(
                  market: market.id,
                  marketName: market.name,
                  session: _session,
                  items: items,
                  isOtc: activeOtcPages.isNotEmpty,
                  shouldPrint: shouldPrint,
                );
        if (receipt == null) {
          if (!mounted) return;
          throw StateError(
              AppLocalizations.trCurrent('Receipt was not saved.'));
        }
        savedReceipts.add(receipt);
      }

      if (savedReceipts.isEmpty) {
        if (!mounted) return;
        throw StateError(AppLocalizations.trCurrent('Receipt was not saved.'));
      }
      if (!mounted) return;

      unawaited(
        ref.read(entriesControllerProvider.notifier).refresh(),
      );
      unawaited(
        ref.read(shareRecordsControllerProvider.notifier).refresh(),
      );

      final mId = market.id;
      _clearAll();

      setState(() {
        _saving = false;
        final current = _localParchiCounters[mId] ?? 1;
        final next = current + pageCount;
        _localParchiCounters[mId] = ((next - 1) % 99) + 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedReceipts.length == 1
                ? context.tr(
                    print
                        ? 'Receipt {receipt} saved. Print job added.'
                        : 'Receipt {receipt} saved.',
                    params: {
                      'receipt': savedReceipts.first.receipt.receiptNumber,
                    },
                  )
                : context.tr(
                    print
                        ? '{count} receipts saved. Print jobs added.'
                        : '{count} receipts saved.',
                    params: {'count': savedReceipts.length},
                  ),
          ),
        ),
      );
    } on Object catch (e, st) {
      debugPrint('Save error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Failed to save receipt: {error}',
              params: {'error': e},
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      ref.read(newEntryDraftProvider.notifier).clearDraft();
      _otcPages.clear();
      if (_isAutoMode) {
        for (final entry in _autoEntries) {
          entry.dispose();
        }
        _autoEntries.clear();
        _selectedColumn = null;
        _autoSearch.clear();
        _ensureAutoRowForSelection();
      } else {
        for (final entry in _manualEntries) {
          entry.dispose();
        }
        _manualEntries
          ..clear()
          ..add(_BetEntry(number: '', amount: ''));
      }
    });
    unawaited(
      ref.read(newEntryDraftProvider.notifier).clearDraft(
            userId: ref.read(authProvider).user?.id,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLanguageProvider);
    _refreshLocalizedInputs();
    final auth = ref.watch(authProvider);
    if (auth.accessStatus?.allowed == false) {
      return SubscriptionLockedScreen(status: auth.accessStatus);
    }

    final state = ref.watch(newEntryControllerProvider);
    final isLoading = state.isLoading;
    _isLoadingData = isLoading;
    if (state.hasValue) {
      final data = state.value!;
      _markets = data.markets;
      _gameConfig = data.gameConfig;
      _syncAutoSelection();
      if (_market != null) {
        ReceiptMarket? matchedMarket;
        for (final market in _markets) {
          if (market.id == _market!.id) {
            matchedMarket = market;
            break;
          }
        }
        _market = matchedMarket?.canEnter == true ? matchedMarket : null;
      }
      if (_market != null &&
          !_markets.any((market) => market.id == _market!.id)) {
        _market = null;
      }
      if (_market == null && _markets.isNotEmpty) {
        Future.microtask(() {
          if (mounted && _market == null) {
            ReceiptMarket? firstAvailable;
            for (final market in _markets) {
              if (market.canEnter) {
                firstAvailable = market;
                break;
              }
            }
            if (firstAvailable != null) {
              setState(() => _market = firstAvailable);
              _persistCurrentDraft();
              ref
                  .read(newEntryControllerProvider.notifier)
                  .loadGameConfigForMarket(firstAvailable.id);
            }
          }
        });
      } else if (_market != null && data.gameConfigMarketId != _market!.id) {
        Future.microtask(() {
          if (mounted) {
            ref
                .read(newEntryControllerProvider.notifier)
                .loadGameConfigForMarket(_market!.id);
          }
        });
      }
    }

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 24,
                  compact ? 14 : 12,
                  compact ? 14 : 24,
                  compact ? 24 : 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: compact
                        ? _buildMobileContent(isLoading)
                        : _buildDesktopContent(isLoading),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopContent(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          number: null,
          label: 'NEW ENTRY',
          icon: Icons.edit_outlined,
          large: true,
        ),
        const SizedBox(height: 18),
        _SectionTitle(number: '1.', label: 'SELECT MARKET'),
        const SizedBox(height: 10),
        if (_isLoadingData && _markets.isEmpty)
          const Padding(
              padding: EdgeInsets.all(12), child: LinearProgressIndicator())
        else if (_markets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(context.tr('No markets found.')),
          )
        else
          _MarketTabs(
            markets: _markets,
            selected: _market,
            onSelected: _selectMarket,
          ),
        if (ref.watch(authProvider).accessStatus != null) ...[
          const SizedBox(height: 10),
          _TrialStatusBar(status: ref.watch(authProvider).accessStatus!),
        ],
        const Divider(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ChoiceBlock(
                number: '2.',
                label: 'SESSION',
                choices: const ['Open', 'Close'],
                selected: _session,
                selectedColor: _green,
                onSelected: _selectSession,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(
                    number: '3.',
                    label: 'ADD BETS',
                  ),
                  const SizedBox(height: 12),
                  if (_isAutoMode)
                    _AutoConfigPanel(
                      configs: _autoConfigs,
                      selectedType: _selectedAutoType,
                      selectedSubtype: _selectedAutoSubtype,
                      numberOptions: _currentNumberOptions,
                      hasConfiguredNumbers:
                          _selectedAutoNumberOptions.isNotEmpty,
                      showNumberTable: _showAutoNumberTable,
                      availableColumns: _availableColumns,
                      selectedColumn: _selectedColumn,
                      searchController: _autoSearch,
                      entries: _selectedAutoEntries,
                      compact: false,
                      onTypeSelected: _selectAutoType,
                      onSubtypeSelected: _selectAutoSubtype,
                      onColumnSelected: _selectColumn,
                      onSearchChanged: _onAutoSearchChanged,
                      onNumberSelected: _selectAutoNumber,
                      numberError: _autoNumberError,
                      amountError: _autoAmountError,
                      onChanged: () => setState(() {}),
                      onAddRow: () => _addAutoEntries(),
                      onAddTenRows: () => _ensureAutoEntryCount(10),
                      onDelete: _removeAutoEntry,
                      autoSearchError: _autoSearchError,
                      onClearError: () =>
                          setState(() => _autoSearchError = null),
                    )
                  else
                    _BetTable(
                      entries: _manualEntries,
                      compact: false,
                      session: _session,
                      isOtc: _areAllReceiptPagesOtcActive,
                      canUseOtc: _canUseOtc,
                      onToggleOtc: _toggleOtc,
                      onChanged: _handleManualEntriesChanged,
                      onAdd: _addEntry,
                      onSubmitRow: _handleManualRowSubmitted,
                      onDelete: _removeEntry,
                      amountFillStartIndex: _amountFillStartIndex,
                      amountFillEndIndex: _amountFillEndIndex,
                      onAmountFillStart: _startAmountFill,
                      onAmountFillHover: _hoverAmountFill,
                      onAmountFillEnd: _endAmountFill,
                      onMobileAmountFill: _fillAmountBelow,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(
                    number: '5.',
                    label: 'PREVIEW (RECEIPT)',
                  ),
                  const SizedBox(height: 12),
                  _ReceiptPreview(
                    parchiNo: _previewParchiNo,
                    marketSession: _market == null
                        ? ''
                        : '${_market!.name} - ${context.trMaybe(_session)}',
                    session: _session,
                    lines: _receiptLines,
                    otcPages: _activeOtcPages,
                    compact: false,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle(number: '6.', label: 'TOTAL'),
        const SizedBox(height: 10),
        _TotalsBar(
          totalBets: _totalBets,
          totalAmount: _totalAmount,
          isOtc: _hasAnyOtcPage,
          marketSession:
              '${_market?.name ?? ''} - ${context.trMaybe(_session)} (${context.trMaybe(_mode)})',
        ),
        const SizedBox(height: 20),
        const _SectionTitle(number: '7.', label: 'ACTIONS'),
        const SizedBox(height: 12),
        _ActionBar(
          onClear: _clearAll,
          onSaveAndPrint: () => _save(print: true),
          canSave: _canSave,
          isLoading: _saving || _isLoadingData,
          compact: false,
        ),
        const SizedBox(height: 20),
        const _InfoNote(),
      ],
    );
  }

  Widget _buildMobileContent(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(number: '1.', label: 'MARKET'),
        const SizedBox(height: 8),
        if (_isLoadingData && _markets.isEmpty)
          const Padding(
              padding: EdgeInsets.all(12), child: LinearProgressIndicator())
        else if (_markets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(context.tr('No markets found.')),
          )
        else
          _MarketDropdown(
            markets: _markets,
            value: _market,
            onChanged: _selectMarket,
          ),
        if (ref.watch(authProvider).accessStatus != null) ...[
          const SizedBox(height: 10),
          _TrialStatusBar(status: ref.watch(authProvider).accessStatus!),
        ],
        const SizedBox(height: 18),
        _ChoiceBlock(
          number: '2.',
          label: 'SESSION',
          choices: const ['Open', 'Close'],
          selected: _session,
          selectedColor: _green,
          onSelected: _selectSession,
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          number: '3.',
          label: 'ADD BETS',
        ),
        const SizedBox(height: 8),
        if (_isAutoMode)
          _AutoConfigPanel(
            configs: _autoConfigs,
            selectedType: _selectedAutoType,
            selectedSubtype: _selectedAutoSubtype,
            numberOptions: _currentNumberOptions,
            hasConfiguredNumbers: _selectedAutoNumberOptions.isNotEmpty,
            showNumberTable: _showAutoNumberTable,
            availableColumns: _availableColumns,
            selectedColumn: _selectedColumn,
            searchController: _autoSearch,
            entries: _selectedAutoEntries,
            compact: true,
            onTypeSelected: _selectAutoType,
            onSubtypeSelected: _selectAutoSubtype,
            onColumnSelected: _selectColumn,
            onSearchChanged: _onAutoSearchChanged,
            onNumberSelected: _selectAutoNumber,
            numberError: _autoNumberError,
            amountError: _autoAmountError,
            onChanged: () => setState(() {}),
            onAddRow: () => _addAutoEntries(),
            onAddTenRows: () => _ensureAutoEntryCount(10),
            onDelete: _removeAutoEntry,
          )
        else
          _BetTable(
            entries: _manualEntries,
            compact: true,
            session: _session,
            isOtc: _areAllReceiptPagesOtcActive,
            canUseOtc: _canUseOtc,
            onToggleOtc: _toggleOtc,
            onChanged: _handleManualEntriesChanged,
            onAdd: _addEntry,
            onSubmitRow: _handleManualRowSubmitted,
            onDelete: _removeEntry,
            amountFillStartIndex: _amountFillStartIndex,
            amountFillEndIndex: _amountFillEndIndex,
            onAmountFillStart: _startAmountFill,
            onAmountFillHover: _hoverAmountFill,
            onAmountFillEnd: _endAmountFill,
            onMobileAmountFill: _fillAmountBelow,
          ),
        const SizedBox(height: 16),
        const _SectionTitle(number: '5.', label: 'PREVIEW (RECEIPT)'),
        const SizedBox(height: 8),
        _ReceiptPreview(
          parchiNo: _previewParchiNo,
          marketSession: _market == null
              ? ''
              : '${_market!.name} - ${context.trMaybe(_session)}',
          session: _session,
          lines: _receiptLines,
          otcPages: _activeOtcPages,
          compact: true,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(number: '6.', label: 'SUMMARY'),
        const SizedBox(height: 8),
        _MobileTotalsBar(
          totalBets: _totalBets,
          totalAmount: _totalAmount,
          isOtc: _hasAnyOtcPage,
          marketSession:
              '${_market?.name ?? ''} - ${context.trMaybe(_session)} (${context.trMaybe(_mode)})',
        ),
        const SizedBox(height: 18),
        const _SectionTitle(number: '7.', label: 'ACTIONS'),
        const SizedBox(height: 8),
        _ActionBar(
          onClear: _clearAll,
          onSaveAndPrint: () => _save(print: true),
          canSave: _canSave,
          isLoading: _saving || _isLoadingData,
          compact: true,
        ),
      ],
    );
  }
}

class _TrialStatusBar extends StatelessWidget {
  const _TrialStatusBar({required this.status});

  final AccessStatus status;

  @override
  Widget build(BuildContext context) {
    final label = status.subscriptionType == 'TRIAL'
        ? 'Free Trial'
        : status.subscriptionType == 'PAID'
            ? 'Paid Plan'
            : 'Subscription';
    final days = status.daysRemaining;
    final expiry = status.expiryDate == null
        ? ''
        : context.tr(
            ' Expires {date}',
            params: {
              'date': DateFormat('dd MMM yyyy').format(status.expiryDate!)
            },
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: _NewEntryPageState._blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(
                '{plan} active - {days} days remaining.{expiry}',
                params: {
                  'plan': context.trMaybe(label),
                  'days': days,
                  'expiry': expiry,
                },
              ),
              style: const TextStyle(
                color: _NewEntryPageState._blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.label,
    this.icon,
    this.large = false,
  });

  final String? number;
  final String label;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: _NewEntryPageState._blue,
      fontSize: large ? 24 : 14,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.black87, size: large ? 24 : 17),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            '${number ?? ''} ${context.trMaybe(label)}'.trim(),
            style: style,
          ),
        ),
      ],
    );
  }
}

class _MarketTabs extends StatelessWidget {
  const _MarketTabs({
    required this.markets,
    required this.selected,
    required this.onSelected,
  });

  final List<ReceiptMarket> markets;
  final ReceiptMarket? selected;
  final ValueChanged<ReceiptMarket> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: markets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          if (index == markets.length) {
            return _SquareIconButton(
              icon: Icons.chevron_right,
              onPressed: () {},
            );
          }
          final market = markets[index];
          final active = market.id == selected?.id;
          return SizedBox(
            width: _tabWidth(market.name),
            child: OutlinedButton(
              onPressed: market.canEnter ? () => onSelected(market) : null,
              style: OutlinedButton.styleFrom(
                backgroundColor: active
                    ? _NewEntryPageState._blue
                    : market.canEnter
                        ? Colors.white
                        : const Color(0xFFE5E7EB),
                foregroundColor: active
                    ? Colors.white
                    : market.canEnter
                        ? Colors.black
                        : Colors.black54,
                side: BorderSide(
                  color: active
                      ? _NewEntryPageState._blue
                      : _NewEntryPageState._line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.localizeMarketName(market.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    context.trMaybe(_marketStatusLabel(market)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _tabWidth(String label) {
    if (label.length > 9) return 126;
    if (label.length > 6) return 104;
    return 92;
  }

  String _marketStatusLabel(ReceiptMarket market) {
    final message = market.availabilityMessage.trim();
    if (message.isNotEmpty) return message.toUpperCase();
    final state = market.availabilityState.trim();
    if (state.isNotEmpty) return state.toUpperCase();
    return market.canEnter ? 'OPEN' : 'CLOSED';
  }
}

class _MarketDropdown extends StatelessWidget {
  const _MarketDropdown({
    required this.markets,
    required this.value,
    required this.onChanged,
  });

  final List<ReceiptMarket> markets;
  final ReceiptMarket? value;
  final ValueChanged<ReceiptMarket> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ReceiptMarket>(
      initialValue: _selectedMarket(markets, value),
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      ),
      items: markets
          .map(
            (market) => DropdownMenuItem(
              value: market,
              enabled: market.canEnter,
              child: Text(
                AppLocalizations.localizeMarketName(market.name),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: market.canEnter ? null : Colors.black54,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  ReceiptMarket? _selectedMarket(
    List<ReceiptMarket> markets,
    ReceiptMarket? value,
  ) {
    if (value == null) return null;
    for (final market in markets) {
      if (market.id == value.id) return market;
    }
    return null;
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.number,
    required this.label,
    required this.choices,
    required this.selected,
    required this.selectedColor,
    required this.onSelected,
  });

  final String number;
  final String label;
  final List<String> choices;
  final String selected;
  final Color selectedColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(number: number, label: label),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < choices.length; index++) ...[
              Expanded(
                child: _ChoiceButton(
                  label: choices[index],
                  selected: selected == choices[index],
                  selectedColor: selectedColor,
                  onPressed: () => onSelected(choices[index]),
                ),
              ),
              if (index < choices.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? selectedColor : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black,
          side: BorderSide(
            color: selected ? selectedColor : _NewEntryPageState._line,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        child: Text(context.trMaybe(label)),
      ),
    );
  }
}

class _BetTable extends StatelessWidget {
  const _BetTable({
    required this.entries,
    required this.compact,
    required this.session,
    required this.isOtc,
    required this.canUseOtc,
    required this.onToggleOtc,
    required this.onChanged,
    required this.onAdd,
    required this.onSubmitRow,
    required this.onDelete,
    required this.amountFillStartIndex,
    required this.amountFillEndIndex,
    required this.onAmountFillStart,
    required this.onAmountFillHover,
    required this.onAmountFillEnd,
    required this.onMobileAmountFill,
  });

  final List<_BetEntry> entries;
  final bool compact;
  final String session;
  final bool isOtc;
  final bool canUseOtc;
  final VoidCallback onToggleOtc;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onSubmitRow;
  final ValueChanged<int> onDelete;
  final int? amountFillStartIndex;
  final int? amountFillEndIndex;
  final ValueChanged<int> onAmountFillStart;
  final ValueChanged<int> onAmountFillHover;
  final VoidCallback onAmountFillEnd;
  final ValueChanged<int> onMobileAmountFill;

  @override
  Widget build(BuildContext context) {
    final showJackpotColumn = session == 'Open';
    final showSessionToggle = session == 'Open';
    final showOtcButton = session == 'Open';
    final headerStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 9 : 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );

    TextEditingController? previousManualController(
      TextEditingController controller,
    ) {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (identical(controller, entry.amount)) return entry.number;
        if (identical(controller, entry.number) && index > 0) {
          return entries[index - 1].amount;
        }
      }
      return null;
    }

    TextEditingController? nextManualController(
      TextEditingController controller,
    ) {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (identical(controller, entry.number)) return entry.amount;
        if (identical(controller, entry.amount) && index + 1 < entries.length) {
          return entries[index + 1].number;
        }
      }
      return null;
    }

    TextEditingController? enterManualController(
      TextEditingController controller,
    ) {
      final next = nextManualController(controller);
      if (next != null) return next;

      for (var index = 0; index < entries.length; index++) {
        if (identical(controller, entries[index].amount)) {
          onSubmitRow(index);
          return nextManualController(controller);
        }
      }
      return null;
    }

    void focusManualController(TextEditingController controller) {
      for (final entry in entries) {
        if (identical(controller, entry.number)) {
          entry.numberFocus.requestFocus();
          return;
        }
        if (identical(controller, entry.amount)) {
          entry.amountFocus.requestFocus();
          return;
        }
      }
    }

    void validateManualKeypadValue(TextEditingController controller) {
      for (final entry in entries) {
        if (!identical(controller, entry.number)) continue;
        final effectiveSession =
            _effectiveEntrySession(session, entry.sessionOverride);
        final raw = entry.number.text.trim();
        final shouldClearJackpot = (effectiveSession == 'Close' ||
                _cpJodiNumber(raw) != null ||
                _familyNumber(raw) != null ||
                _isManualSangamNumber(raw)) &&
            entry.isJackpot;
        if (shouldClearJackpot) entry.isJackpot = false;
        entry.error = _manualNumberError(
          raw,
          isCloseSession: effectiveSession == 'Close',
        );
        break;
      }
      onChanged();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _NewEntryPageState._line),
        ),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF111820),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 14,
                vertical: compact ? 8 : 12,
              ),
              child: Row(
                children: [
                  _HeaderCell('#', flex: compact ? 5 : 7, style: headerStyle),
                  if (showJackpotColumn)
                    _HeaderCell('JACKPOT', flex: 15, style: headerStyle),
                  _HeaderCell('NO.', flex: 20, style: headerStyle),
                  _HeaderCell('AMOUNT ($_rs)', flex: 16, style: headerStyle),
                  if (showSessionToggle)
                    _HeaderCell('O/C', flex: 15, style: headerStyle),
                  _HeaderCell(compact ? 'DEL' : 'ACTION',
                      flex: 12, style: headerStyle),
                ],
              ),
            ),
            for (var index = 0; index < entries.length; index++)
              _BetRow(
                key: ValueKey(index),
                index: index,
                entry: entries[index],
                compact: compact,
                session: session,
                amountFillStartIndex: amountFillStartIndex,
                amountFillEndIndex: amountFillEndIndex,
                onAmountFillStart: onAmountFillStart,
                onAmountFillHover: onAmountFillHover,
                onAmountFillEnd: onAmountFillEnd,
                onMobileAmountFill: onMobileAmountFill,
                onChanged: onChanged,
                onSubmitted: () => onSubmitRow(index),
                previousEntryAmountController:
                    index > 0 ? entries[index - 1].amount : null,
                previousEntryAmountFocus:
                    index > 0 ? entries[index - 1].amountFocus : null,
                nextEntryNumberController: () => index + 1 < entries.length
                    ? entries[index + 1].number
                    : null,
                keypadBackTargetFor: previousManualController,
                keypadNextTargetFor: nextManualController,
                keypadEnterTargetFor: enterManualController,
                keypadOnActiveControllerChanged: focusManualController,
                keypadOnActiveValueChanged: validateManualKeypadValue,
                onDelete: () => onDelete(index),
              ),
            Container(
              height: compact ? 40 : 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFBFCFF),
                border:
                    Border(top: BorderSide(color: _NewEntryPageState._line)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SquareIconButton(icon: Icons.add, onPressed: onAdd),
                  if (showOtcButton) ...[
                    const SizedBox(width: 8),
                    _OtcToggleButton(
                      selected: isOtc,
                      enabled: canUseOtc,
                      onPressed: onToggleOtc,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BetRow extends StatefulWidget {
  const _BetRow({
    super.key,
    required this.index,
    required this.entry,
    required this.compact,
    required this.session,
    required this.amountFillStartIndex,
    required this.amountFillEndIndex,
    required this.onAmountFillStart,
    required this.onAmountFillHover,
    required this.onAmountFillEnd,
    required this.onMobileAmountFill,
    required this.onChanged,
    required this.onSubmitted,
    required this.previousEntryAmountController,
    required this.previousEntryAmountFocus,
    required this.nextEntryNumberController,
    required this.keypadBackTargetFor,
    required this.keypadNextTargetFor,
    required this.keypadEnterTargetFor,
    required this.keypadOnActiveControllerChanged,
    required this.keypadOnActiveValueChanged,
    required this.onDelete,
  });

  final int index;
  final _BetEntry entry;
  final bool compact;
  final String session;
  final int? amountFillStartIndex;
  final int? amountFillEndIndex;
  final ValueChanged<int> onAmountFillStart;
  final ValueChanged<int> onAmountFillHover;
  final VoidCallback onAmountFillEnd;
  final ValueChanged<int> onMobileAmountFill;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final TextEditingController? previousEntryAmountController;
  final FocusNode? previousEntryAmountFocus;
  final TextEditingController? Function() nextEntryNumberController;
  final TextEditingController? Function(TextEditingController controller)
      keypadBackTargetFor;
  final TextEditingController? Function(TextEditingController controller)
      keypadNextTargetFor;
  final TextEditingController? Function(TextEditingController controller)
      keypadEnterTargetFor;
  final ValueChanged<TextEditingController> keypadOnActiveControllerChanged;
  final ValueChanged<TextEditingController> keypadOnActiveValueChanged;
  final VoidCallback onDelete;

  @override
  State<_BetRow> createState() => _BetRowState();
}

class _BetRowState extends State<_BetRow> {
  _BetEntry get entry => widget.entry;
  bool get compact => widget.compact;
  String get session => widget.session;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onDelete => widget.onDelete;
  int get index => widget.index;
  bool get isAmountFillSource => widget.amountFillStartIndex == index;
  bool get isAmountFillTarget {
    final start = widget.amountFillStartIndex;
    final end = widget.amountFillEndIndex;
    return start != null && end != null && index > start && index <= end;
  }

  String get effectiveSession =>
      _effectiveEntrySession(session, entry.sessionOverride);
  bool get isCloseSession => effectiveSession == 'Close';

  void _validateNumber() {
    final raw = entry.number.text.trim();
    final effectiveSession = entry.sessionOverride ?? session;
    final shouldClearJackpot = (effectiveSession == 'Close' ||
            _cpJodiNumber(raw) != null ||
            _familyNumber(raw) != null ||
            _isManualSangamNumber(raw)) &&
        entry.isJackpot;
    final newError = _manualNumberError(
      raw,
      isCloseSession: effectiveSession == 'Close',
    );
    setState(() {
      if (shouldClearJackpot) entry.isJackpot = false;
      entry.error = newError;
    });
    onChanged();
  }

  void _focusJackpotNumber(int rowIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          rowIndex < 0 ||
          rowIndex >= entry.jackpotNumberFocus.length) {
        return;
      }
      entry.jackpotNumberFocus[rowIndex].requestFocus();
    });
  }

  void _focusJackpotAmount(int rowIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          rowIndex < 0 ||
          rowIndex >= entry.jackpotAmountFocus.length) {
        return;
      }
      entry.jackpotAmountFocus[rowIndex].requestFocus();
    });
  }

  void _submitJackpotNumber(int rowIndex) {
    _focusJackpotAmount(rowIndex);
  }

  void _submitJackpotAmount(int rowIndex) {
    final nextIndex = rowIndex + 1;
    if (nextIndex < entry.jackpotRowCount) {
      _focusJackpotNumber(nextIndex);
      return;
    }
    if (entry.jackpotRowCount < 10) {
      setState(() {
        entry.jackpotRowCount++;
      });
      onChanged();
      _focusJackpotNumber(nextIndex);
      return;
    }
    widget.onSubmitted();
  }

  void _submitMainAmount() {
    if (entry.isJackpot && entry.jackpotRowCount > 0) {
      _focusJackpotNumber(0);
      return;
    }
    widget.onSubmitted();
  }

  int _jackpotNumberIndex(TextEditingController controller) {
    return entry.jackpotNumbers.indexWhere(
      (candidate) => identical(candidate, controller),
    );
  }

  int _jackpotAmountIndex(TextEditingController controller) {
    return entry.jackpotAmounts.indexWhere(
      (candidate) => identical(candidate, controller),
    );
  }

  TextEditingController? _advanceFromJackpotAmount(int index) {
    final nextIndex = index + 1;
    if (nextIndex < entry.jackpotRowCount) {
      return entry.jackpotNumbers[nextIndex];
    }
    if (entry.jackpotRowCount < 10) {
      setState(() {
        entry.jackpotRowCount++;
      });
      onChanged();
      return entry.jackpotNumbers[nextIndex];
    }
    widget.onSubmitted();
    return widget.nextEntryNumberController();
  }

  TextEditingController? _keypadBackTargetFor(
    TextEditingController controller,
  ) {
    final numberIndex = _jackpotNumberIndex(controller);
    if (numberIndex >= 0) {
      return numberIndex == 0
          ? entry.amount
          : entry.jackpotAmounts[numberIndex - 1];
    }
    final amountIndex = _jackpotAmountIndex(controller);
    if (amountIndex >= 0) return entry.jackpotNumbers[amountIndex];
    return widget.keypadBackTargetFor(controller);
  }

  TextEditingController? _keypadNextTargetFor(
    TextEditingController controller,
  ) {
    if (identical(controller, entry.amount) && entry.isJackpot) {
      return entry.jackpotNumbers.first;
    }
    final numberIndex = _jackpotNumberIndex(controller);
    if (numberIndex >= 0) return entry.jackpotAmounts[numberIndex];
    final amountIndex = _jackpotAmountIndex(controller);
    if (amountIndex >= 0) return _advanceFromJackpotAmount(amountIndex);
    return widget.keypadNextTargetFor(controller);
  }

  TextEditingController? _keypadEnterTargetFor(
    TextEditingController controller,
  ) {
    if (identical(controller, entry.amount) && entry.isJackpot) {
      return entry.jackpotNumbers.first;
    }

    final numberIndex = _jackpotNumberIndex(controller);
    if (numberIndex >= 0) return entry.jackpotAmounts[numberIndex];

    final amountIndex = _jackpotAmountIndex(controller);
    if (amountIndex >= 0) return _advanceFromJackpotAmount(amountIndex);

    return widget.keypadEnterTargetFor(controller);
  }

  void _focusKeypadController(TextEditingController controller) {
    final numberIndex = _jackpotNumberIndex(controller);
    if (numberIndex >= 0) {
      _focusJackpotNumber(numberIndex);
      return;
    }
    final amountIndex = _jackpotAmountIndex(controller);
    if (amountIndex >= 0) {
      _focusJackpotAmount(amountIndex);
      return;
    }
    widget.keypadOnActiveControllerChanged(controller);
  }

  void _handleKeypadValueChanged(TextEditingController controller) {
    if (_jackpotNumberIndex(controller) >= 0 ||
        _jackpotAmountIndex(controller) >= 0) {
      onChanged();
      return;
    }
    widget.keypadOnActiveValueChanged(controller);
  }

  void _addJackpotRow() {
    if (entry.jackpotRowCount >= 10) return;
    final newIndex = entry.jackpotRowCount;
    setState(() {
      entry.jackpotRowCount++;
    });
    onChanged();
    _focusJackpotNumber(newIndex);
  }

  TextEditingController? _openJackpot() {
    final isFamily = _familyNumber(entry.number.text) != null;
    final isCpJodi = _cpJodiNumber(entry.number.text) != null;
    final isSangam = _isManualSangamNumber(entry.number.text);
    final canUseJackpot =
        session == 'Open' && !isCpJodi && !isFamily && !isSangam;
    if (!canUseJackpot) return null;
    setState(() {
      entry.isJackpot = true;
    });
    onChanged();
    _focusJackpotNumber(0);
    return entry.jackpotNumbers.first;
  }

  void _fillJackpotAmountBelow(int index) {
    if (index < 0 || index >= entry.jackpotAmounts.length) return;
    final value = entry.jackpotAmounts[index].text.trim();
    if (!_isValidAmountText(value) || index >= entry.jackpotRowCount - 1) {
      return;
    }
    for (var targetIndex = index + 1;
        targetIndex < entry.jackpotRowCount;
        targetIndex++) {
      entry.jackpotAmounts[targetIndex].value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isFamily = _familyNumber(entry.number.text) != null;
    final isCpJodi = _cpJodiNumber(entry.number.text) != null;
    final isSangam = _isManualSangamNumber(entry.number.text);
    final effectiveSession = entry.sessionOverride ?? session;
    final canUseJackpot =
        effectiveSession == 'Open' && !isCpJodi && !isFamily && !isSangam;
    final showJackpotBoxes = entry.isJackpot && canUseJackpot;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _NewEntryPageState._line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _DataCell(Text('${index + 1}'), flex: compact ? 5 : 7),
              if (session == 'Open')
                _DataCell(
                  !canUseJackpot
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: context.tr('Jackpot'),
                          padding: EdgeInsets.zero,
                          isSelected: entry.isJackpot,
                          icon: const Icon(Icons.stars_outlined, size: 18),
                          selectedIcon: const Icon(Icons.stars, size: 18),
                          color: entry.isJackpot ? Colors.green : Colors.grey,
                          onPressed: _openJackpot,
                        ),
                  flex: 15,
                ),
              _DataCell(
                _EntryTextField(
                  controller: entry.number,
                  focusNode: entry.numberFocus,
                  errorText: entry.error,
                  showErrorText: false,
                  compact: compact,
                  maxLength: 14,
                  prefixText: isCloseSession ? '>' : null,
                  suffixText: effectiveSession == 'Open' ? '>' : null,
                  textInputAction: entry.amount.text.trim().isEmpty
                      ? TextInputAction.next
                      : TextInputAction.done,
                  keypadBackController:
                      widget.previousEntryAmountController ?? entry.number,
                  keypadNextController: entry.amount,
                  keypadOnChanged: _validateNumber,
                  keypadBackOnChanged: onChanged,
                  keypadNextOnChanged: onChanged,
                  keypadOnBack: () => widget.previousEntryAmountFocus == null
                      ? entry.numberFocus.requestFocus()
                      : widget.previousEntryAmountFocus!.requestFocus(),
                  keypadOnNext: () => entry.amountFocus.requestFocus(),
                  keypadOnEnter: () => entry.amountFocus.requestFocus(),
                  keypadOnJackpot: _openJackpot,
                  nextEntryNumberController: () => entry.amount,
                  keypadBackTargetFor: _keypadBackTargetFor,
                  keypadNextTargetFor: _keypadNextTargetFor,
                  keypadEnterTargetFor: _keypadEnterTargetFor,
                  keypadOnActiveControllerChanged: _focusKeypadController,
                  keypadOnActiveValueChanged: _handleKeypadValueChanged,
                  onSubmitted: () {
                    if (entry.amount.text.trim().isEmpty) {
                      entry.amountFocus.requestFocus();
                      return;
                    }
                    widget.onSubmitted();
                  },
                  onChanged: () {
                    _validateNumber();
                  },
                ),
                flex: 20,
              ),
              _DataCell(
                _AmountFillField(
                  controller: entry.amount,
                  focusNode: entry.amountFocus,
                  compact: compact,
                  highlighted: isAmountFillSource || isAmountFillTarget,
                  isSource: isAmountFillSource,
                  onFillStart: () => widget.onAmountFillStart(index),
                  onFillHover: () => widget.onAmountFillHover(index),
                  onFillEnd: widget.onAmountFillEnd,
                  onMobileFill: () => widget.onMobileAmountFill(index),
                  keypadBackController: entry.number,
                  keypadNextController: widget.nextEntryNumberController(),
                  keypadOnChanged: onChanged,
                  keypadBackOnChanged: _validateNumber,
                  keypadNextOnChanged: onChanged,
                  keypadOnBack: () => entry.numberFocus.requestFocus(),
                  keypadOnNext: _submitMainAmount,
                  keypadOnEnter: _submitMainAmount,
                  keypadOnJackpot: _openJackpot,
                  keypadBackTargetFor: _keypadBackTargetFor,
                  keypadNextTargetFor: _keypadNextTargetFor,
                  keypadEnterTargetFor: _keypadEnterTargetFor,
                  keypadOnActiveControllerChanged: _focusKeypadController,
                  keypadOnActiveValueChanged: _handleKeypadValueChanged,
                  onSubmitted: _submitMainAmount,
                  onChanged: onChanged,
                ),
                flex: 16,
              ),
              if (session == 'Open')
                _DataCell(
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final nextSession =
                            effectiveSession == 'Open' ? 'Close' : 'Open';
                        entry.sessionOverride =
                            nextSession == session ? null : nextSession;
                        if (nextSession == 'Close') {
                          entry.isJackpot = false;
                        }
                      });
                      onChanged();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: effectiveSession == 'Open'
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: effectiveSession == 'Open'
                              ? Colors.orange
                              : Colors.blue,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        effectiveSession == 'Open' ? 'O' : 'C',
                        style: TextStyle(
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w900,
                          color: effectiveSession == 'Open'
                              ? Colors.orange.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ),
                  flex: 15,
                ),
              _DataCell(
                IconButton(
                  tooltip: context.tr('Delete row'),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.delete_outline,
                    color: _NewEntryPageState._red,
                    size: compact ? 17 : 22,
                  ),
                ),
                flex: 12,
              ),
            ],
          ),
          if (showJackpotBoxes)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 28 : 44,
                compact ? 3 : 6,
                compact ? 28 : 44,
                compact ? 4 : 7,
              ),
              child: _JackpotEntryRows(
                numberControllers: entry.jackpotNumbers,
                amountControllers: entry.jackpotAmounts,
                numberFocusNodes: entry.jackpotNumberFocus,
                amountFocusNodes: entry.jackpotAmountFocus,
                rowCount: entry.jackpotRowCount,
                compact: compact,
                onAdd: entry.jackpotRowCount >= 10 ? null : _addJackpotRow,
                mainAmountController: entry.amount,
                mainAmountFocus: entry.amountFocus,
                onNumberSubmitted: _submitJackpotNumber,
                onAmountSubmitted: _submitJackpotAmount,
                onMobileAmountFill: _fillJackpotAmountBelow,
                keypadBackTargetFor: _keypadBackTargetFor,
                keypadNextTargetFor: _keypadNextTargetFor,
                keypadEnterTargetFor: _keypadEnterTargetFor,
                keypadOnActiveControllerChanged: _focusKeypadController,
                keypadOnActiveValueChanged: _handleKeypadValueChanged,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _JackpotEntryRows extends StatelessWidget {
  const _JackpotEntryRows({
    required this.numberControllers,
    required this.amountControllers,
    required this.numberFocusNodes,
    required this.amountFocusNodes,
    required this.rowCount,
    required this.compact,
    required this.onAdd,
    required this.mainAmountController,
    required this.mainAmountFocus,
    required this.onNumberSubmitted,
    required this.onAmountSubmitted,
    required this.onMobileAmountFill,
    required this.keypadBackTargetFor,
    required this.keypadNextTargetFor,
    required this.keypadEnterTargetFor,
    required this.keypadOnActiveControllerChanged,
    required this.keypadOnActiveValueChanged,
    required this.onChanged,
  });

  final List<TextEditingController> numberControllers;
  final List<TextEditingController> amountControllers;
  final List<FocusNode> numberFocusNodes;
  final List<FocusNode> amountFocusNodes;
  final int rowCount;
  final bool compact;
  final VoidCallback? onAdd;
  final TextEditingController mainAmountController;
  final FocusNode mainAmountFocus;
  final ValueChanged<int> onNumberSubmitted;
  final ValueChanged<int> onAmountSubmitted;
  final ValueChanged<int> onMobileAmountFill;
  final TextEditingController? Function(TextEditingController controller)
      keypadBackTargetFor;
  final TextEditingController? Function(TextEditingController controller)
      keypadNextTargetFor;
  final TextEditingController? Function(TextEditingController controller)
      keypadEnterTargetFor;
  final ValueChanged<TextEditingController> keypadOnActiveControllerChanged;
  final ValueChanged<TextEditingController> keypadOnActiveValueChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final numberWidth = compact ? 32.0 : 38.0;
    final amountWidth = compact ? 58.0 : 68.0;
    final height = compact ? 24.0 : 28.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < rowCount; index++)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 3 : 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _JackpotSmallField(
                  controller: numberControllers[index],
                  focusNode: numberFocusNodes[index],
                  width: numberWidth,
                  height: height,
                  maxLength: 1,
                  compact: compact,
                  errorText: _jackpotNumberError(numberControllers[index].text),
                  textInputAction: TextInputAction.next,
                  backController: index == 0
                      ? mainAmountController
                      : amountControllers[index - 1],
                  nextController: amountControllers[index],
                  onBack: () => index == 0
                      ? mainAmountFocus.requestFocus()
                      : amountFocusNodes[index - 1].requestFocus(),
                  onNext: () => amountFocusNodes[index].requestFocus(),
                  enterController: () => amountControllers[index],
                  backTargetFor: keypadBackTargetFor,
                  nextTargetFor: keypadNextTargetFor,
                  enterTargetFor: keypadEnterTargetFor,
                  onActiveControllerChanged: keypadOnActiveControllerChanged,
                  onActiveValueChanged: keypadOnActiveValueChanged,
                  onSubmitted: () => onNumberSubmitted(index),
                  onChanged: onChanged,
                ),
                SizedBox(width: compact ? 5 : 8),
                _JackpotSmallField(
                  controller: amountControllers[index],
                  focusNode: amountFocusNodes[index],
                  width: amountWidth,
                  height: height,
                  maxLength: 8,
                  compact: compact,
                  allowDecimal: true,
                  textInputAction: index + 1 < rowCount
                      ? TextInputAction.next
                      : TextInputAction.done,
                  backController: numberControllers[index],
                  nextController: index + 1 < rowCount
                      ? numberControllers[index + 1]
                      : null,
                  onBack: () => numberFocusNodes[index].requestFocus(),
                  onNext: () => onAmountSubmitted(index),
                  onEnter: () => onAmountSubmitted(index),
                  enterController: () {
                    if (index + 1 >= rowCount && onAdd != null) {
                      onAdd!();
                    }
                    return index + 1 < numberControllers.length
                        ? numberControllers[index + 1]
                        : null;
                  },
                  backTargetFor: keypadBackTargetFor,
                  nextTargetFor: keypadNextTargetFor,
                  enterTargetFor: keypadEnterTargetFor,
                  onActiveControllerChanged: keypadOnActiveControllerChanged,
                  onActiveValueChanged: keypadOnActiveValueChanged,
                  onSubmitted: () => onAmountSubmitted(index),
                  onMobileFill: () => onMobileAmountFill(index),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        SizedBox(
          width: compact ? 26 : 30,
          height: compact ? 24 : 28,
          child: IconButton(
            tooltip: context.tr('Add jackpot row'),
            onPressed: onAdd,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.add,
              size: compact ? 16 : 18,
              color: onAdd == null ? Colors.grey : _NewEntryPageState._blue,
            ),
          ),
        ),
      ],
    );
  }
}

class _JackpotSmallField extends StatelessWidget {
  const _JackpotSmallField({
    required this.controller,
    required this.width,
    required this.height,
    required this.maxLength,
    required this.compact,
    required this.onChanged,
    this.focusNode,
    this.errorText,
    this.allowDecimal = false,
    this.textInputAction,
    this.onSubmitted,
    this.onMobileFill,
    this.backController,
    this.nextController,
    this.onBack,
    this.onNext,
    this.onEnter,
    this.enterController,
    this.backTargetFor,
    this.nextTargetFor,
    this.enterTargetFor,
    this.onActiveControllerChanged,
    this.onActiveValueChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final double width;
  final double height;
  final int maxLength;
  final bool compact;
  final VoidCallback onChanged;
  final String? errorText;
  final bool allowDecimal;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final VoidCallback? onMobileFill;
  final TextEditingController? backController;
  final TextEditingController? nextController;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onEnter;
  final TextEditingController? Function()? enterController;
  final TextEditingController? Function(TextEditingController controller)?
      backTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      nextTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      enterTargetFor;
  final ValueChanged<TextEditingController>? onActiveControllerChanged;
  final ValueChanged<TextEditingController>? onActiveValueChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            textInputAction: textInputAction,
            keyboardType: allowDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: [
              allowDecimal
                  ? const _DecimalAmountInputFormatter()
                  : const _LocalizedDigitsOnlyInputFormatter(),
              LengthLimitingTextInputFormatter(maxLength),
            ],
            readOnly: true,
            onTap: () async {
              await Scrollable.ensureVisible(
                context,
                alignment: 0.2,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
              if (!context.mounted) return;
              Scaffold.of(context).showBottomSheet(
                (_) => MatkaNumberKeypadSheet(
                  controller: controller,
                  backController: backController,
                  nextController: nextController,
                  onChanged: onChanged,
                  onBack: onBack,
                  onNext: onNext,
                  onEnter: onEnter ?? onSubmitted,
                  enterController: enterController,
                  backTargetFor: backTargetFor,
                  nextTargetFor: nextTargetFor,
                  enterTargetFor: enterTargetFor,
                  onActiveControllerChanged: onActiveControllerChanged,
                  onActiveValueChanged: onActiveValueChanged,
                ),
                backgroundColor: Colors.transparent,
              );
            },
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted?.call(),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: hasError ? Colors.red.shade100 : Colors.white,
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: hasError
                    ? const BorderSide(color: Colors.red, width: 2)
                    : const BorderSide(color: Color(0xFF566175)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: hasError
                    ? const BorderSide(color: Colors.red, width: 2)
                    : const BorderSide(
                        color: _NewEntryPageState._blue,
                        width: 2,
                      ),
              ),
            ),
          ),
          if (allowDecimal && onMobileFill != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: compact ? onMobileFill : null,
                child: SizedBox(
                  width: compact ? 18 : 8,
                  height: compact ? 18 : 8,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: compact ? 7 : 5,
                      height: compact ? 7 : 5,
                      decoration: BoxDecoration(
                        color: _NewEntryPageState._blue,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MatkaNumberKeypadSheet extends StatefulWidget {
  const MatkaNumberKeypadSheet({
    required this.controller,
    this.backController,
    this.nextController,
    this.onChanged,
    this.backOnChanged,
    this.nextOnChanged,
    this.onBack,
    this.onNext,
    this.onJackpot,
    this.onEnter,
    this.enterController,
    this.backTargetFor,
    this.nextTargetFor,
    this.enterTargetFor,
    this.onActiveControllerChanged,
    this.onActiveValueChanged,
    super.key,
  });

  final TextEditingController controller;
  final TextEditingController? backController;
  final TextEditingController? nextController;
  final VoidCallback? onChanged;
  final VoidCallback? backOnChanged;
  final VoidCallback? nextOnChanged;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final TextEditingController? Function()? onJackpot;
  final VoidCallback? onEnter;
  final TextEditingController? Function()? enterController;
  final TextEditingController? Function(TextEditingController controller)?
      backTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      nextTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      enterTargetFor;
  final ValueChanged<TextEditingController>? onActiveControllerChanged;
  final ValueChanged<TextEditingController>? onActiveValueChanged;

  @override
  State<MatkaNumberKeypadSheet> createState() => _MatkaNumberKeypadSheetState();
}

class _MatkaNumberKeypadSheetState extends State<MatkaNumberKeypadSheet> {
  late TextEditingController _activeController;
  bool _valueChangeScheduled = false;

  @override
  void initState() {
    super.initState();
    _activeController = widget.controller;
  }

  void _setActiveController(TextEditingController controller) {
    setState(() => _activeController = controller);
    widget.onActiveControllerChanged?.call(controller);
  }

  void _scheduleValueChanged() {
    if (_valueChangeScheduled) return;
    _valueChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _valueChangeScheduled = false;
      if (!mounted) return;
      if (widget.onActiveValueChanged != null) {
        widget.onActiveValueChanged!.call(_activeController);
      } else {
        widget.onChanged?.call();
      }
    });
  }

  void _appendKey(String key) {
    final controller = _activeController;
    if (controller is _LocalizedDigitsController) {
      controller.applyKeypadValue(key);
      return;
    }

    final text = controller.text + key;
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void _removeLastKey() {
    final controller = _activeController;
    if (controller is _LocalizedDigitsController) {
      controller.removeLastKeypadValue();
      return;
    }
    if (controller.text.isEmpty) return;

    final text = controller.text.substring(0, controller.text.length - 1);
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = <List<String>>[
      ['SP', 'DP', 'CP', 'CM'],
      ['CT', 'F', 'BZ'],
      ['7', '8', '9', widget.onJackpot == null ? 'remove' : 'Jackpot'],
      ['4', '5', '6', 'back'],
      ['1', '2', '3', widget.onJackpot == null ? 'next' : 'remove'],
      ['0', '*', 'Enter'],
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F9FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Color(0xFFD9E8FF), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB7CFF7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            for (final row in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: _MatkaKey(
                            label: key,
                            onTap: () {
                              if (key == 'remove') {
                                _removeLastKey();
                                _scheduleValueChanged();
                                return;
                              }
                              if (key == 'Jackpot') {
                                final target = widget.onJackpot?.call();
                                if (target != null) {
                                  _setActiveController(target);
                                }
                                return;
                              }
                              if (key == 'back' || key == 'next') {
                                if (key == 'back') {
                                  final target = widget.backTargetFor
                                          ?.call(_activeController) ??
                                      widget.backController;
                                  if (target != null) {
                                    _setActiveController(target);
                                  }
                                  if (widget.backTargetFor == null) {
                                    widget.backOnChanged?.call();
                                    widget.onBack?.call();
                                  }
                                } else {
                                  final target = widget.nextTargetFor
                                          ?.call(_activeController) ??
                                      widget.nextController;
                                  if (target != null) {
                                    _setActiveController(target);
                                  }
                                  if (widget.nextTargetFor == null) {
                                    widget.nextOnChanged?.call();
                                    widget.onNext?.call();
                                  }
                                }
                                return;
                              }
                              if (key == 'Enter') {
                                if (widget.enterTargetFor != null) {
                                  final target = widget.enterTargetFor!
                                      .call(_activeController);
                                  if (target != null) {
                                    _setActiveController(target);
                                  }
                                  return;
                                }
                                final immediateTarget =
                                    widget.enterController?.call();
                                if (immediateTarget != null) {
                                  _setActiveController(immediateTarget);
                                }
                                widget.onEnter?.call();
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  final target = widget.enterController?.call();
                                  if (mounted && target != null) {
                                    _setActiveController(target);
                                  }
                                });
                                return;
                              }
                              _appendKey(key);
                              _scheduleValueChanged();
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MatkaKey extends StatelessWidget {
  const _MatkaKey({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNavigation = label == 'back' || label == 'next';
    final isJackpot = label == 'Jackpot';
    final isRemove = label == 'remove';
    final isAction = isNavigation ||
        isJackpot ||
        isRemove ||
        label == '*' ||
        label == 'Enter';
    final isSpecial = label == 'SP' ||
        label == 'DP' ||
        label == 'CP' ||
        label == 'CM' ||
        label == 'CT' ||
        label == 'F' ||
        label == 'BZ';

    final backgroundColor = isAction
        ? const Color(0xFFE7F0FF)
        : isSpecial
            ? const Color(0xFFE8F7EE)
            : const Color(0xFFFFFFFF);

    final foregroundColor = isAction
        ? label == 'Enter'
            ? Colors.white
            : isJackpot
                ? const Color(0xFF108438)
                : const Color(0xFF064DB5)
        : isSpecial
            ? const Color(0xFF108438)
            : const Color(0xFF111820);

    final borderColor = isAction
        ? label == 'Enter'
            ? const Color(0xFF064DB5)
            : isJackpot
                ? const Color(0xFFBFE8CA)
                : const Color(0xFFBFD5FF)
        : isSpecial
            ? const Color(0xFFBFE8CA)
            : const Color(0xFFD8E0EA);

    return SizedBox(
      height: 38,
      child: Material(
        color: label == 'Enter' ? const Color(0xFF064DB5) : backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: 1.1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: isNavigation || isJackpot || isRemove
                ? Icon(
                    label == 'back'
                        ? Icons.arrow_back
                        : label == 'next'
                            ? Icons.arrow_forward
                            : label == 'Jackpot'
                                ? Icons.stars
                                : Icons.close,
                    color: foregroundColor,
                    size: 20,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: label.length > 2 ? 14 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class MatkaEntryTextField extends StatelessWidget {
  const MatkaEntryTextField({
    required this.controller,
    required this.compact,
    required this.maxLength,
    required this.onChanged,
    this.focusNode,
    this.errorText,
    this.showErrorText = true,
    this.allowDecimal = false,
    this.prefixText,
    this.suffixText,
    this.textInputAction,
    this.keypadBackController,
    this.keypadNextController,
    this.keypadOnChanged,
    this.keypadBackOnChanged,
    this.keypadNextOnChanged,
    this.keypadOnBack,
    this.keypadOnNext,
    this.keypadOnJackpot,
    this.keypadOnEnter,
    this.nextEntryNumberController,
    this.keypadBackTargetFor,
    this.keypadNextTargetFor,
    this.keypadEnterTargetFor,
    this.keypadOnActiveControllerChanged,
    this.keypadOnActiveValueChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool compact;
  final int maxLength;
  final VoidCallback onChanged;
  final String? errorText;
  final bool showErrorText;
  final bool allowDecimal;
  final String? prefixText;
  final String? suffixText;
  final TextInputAction? textInputAction;
  final TextEditingController? keypadBackController;
  final TextEditingController? keypadNextController;
  final VoidCallback? keypadOnChanged;
  final VoidCallback? keypadBackOnChanged;
  final VoidCallback? keypadNextOnChanged;
  final VoidCallback? keypadOnBack;
  final VoidCallback? keypadOnNext;
  final TextEditingController? Function()? keypadOnJackpot;
  final VoidCallback? keypadOnEnter;
  final TextEditingController? Function()? nextEntryNumberController;
  final TextEditingController? Function(TextEditingController controller)?
      keypadBackTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      keypadNextTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      keypadEnterTargetFor;
  final ValueChanged<TextEditingController>? keypadOnActiveControllerChanged;
  final ValueChanged<TextEditingController>? keypadOnActiveValueChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return _EntryTextField(
      controller: controller,
      compact: compact,
      maxLength: maxLength,
      onChanged: onChanged,
      fieldKey: key ?? const Key('matka_entry_keypad_trigger'),
      focusNode: focusNode,
      errorText: errorText,
      showErrorText: showErrorText,
      allowDecimal: allowDecimal,
      prefixText: prefixText,
      suffixText: suffixText,
      textInputAction: textInputAction,
      keypadBackController: keypadBackController,
      keypadNextController: keypadNextController,
      keypadOnChanged: keypadOnChanged,
      keypadBackOnChanged: keypadBackOnChanged,
      keypadNextOnChanged: keypadNextOnChanged,
      keypadOnBack: keypadOnBack,
      keypadOnNext: keypadOnNext,
      keypadOnJackpot: keypadOnJackpot,
      keypadOnEnter: keypadOnEnter,
      nextEntryNumberController: nextEntryNumberController,
      keypadBackTargetFor: keypadBackTargetFor,
      keypadNextTargetFor: keypadNextTargetFor,
      keypadEnterTargetFor: keypadEnterTargetFor,
      keypadOnActiveControllerChanged: keypadOnActiveControllerChanged,
      keypadOnActiveValueChanged: keypadOnActiveValueChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _EntryTextField extends StatelessWidget {
  const _EntryTextField({
    required this.controller,
    required this.compact,
    required this.maxLength,
    required this.onChanged,
    this.fieldKey,
    this.focusNode,
    this.errorText,
    this.showErrorText = true,
    this.allowDecimal = false,
    this.prefixText,
    this.suffixText,
    this.textInputAction,
    this.keypadOnChanged,
    this.keypadBackOnChanged,
    this.keypadNextOnChanged,
    this.keypadBackController,
    this.keypadNextController,
    this.keypadOnBack,
    this.keypadOnNext,
    this.keypadOnJackpot,
    this.keypadOnEnter,
    this.nextEntryNumberController,
    this.keypadBackTargetFor,
    this.keypadNextTargetFor,
    this.keypadEnterTargetFor,
    this.keypadOnActiveControllerChanged,
    this.keypadOnActiveValueChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final bool compact;
  final int maxLength;
  final VoidCallback onChanged;
  final String? errorText;
  final bool showErrorText;
  final bool allowDecimal;
  final String? prefixText;
  final String? suffixText;
  final TextInputAction? textInputAction;
  final TextEditingController? keypadBackController;
  final TextEditingController? keypadNextController;
  final VoidCallback? keypadOnChanged;
  final VoidCallback? keypadBackOnChanged;
  final VoidCallback? keypadNextOnChanged;
  final VoidCallback? keypadOnBack;
  final VoidCallback? keypadOnNext;
  final TextEditingController? Function()? keypadOnJackpot;
  final VoidCallback? keypadOnEnter;
  final TextEditingController? Function()? nextEntryNumberController;
  final TextEditingController? Function(TextEditingController controller)?
      keypadBackTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      keypadNextTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      keypadEnterTargetFor;
  final ValueChanged<TextEditingController>? keypadOnActiveControllerChanged;
  final ValueChanged<TextEditingController>? keypadOnActiveValueChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return TextField(
      key: fieldKey ?? ValueKey<TextEditingController>(controller),
      controller: controller,
      focusNode: focusNode,
      readOnly: true,
      onTap: () async {
        await Scrollable.ensureVisible(
          context,
          alignment: 0.2,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        if (!context.mounted) return;
        Scaffold.of(context).showBottomSheet(
          (_) => MatkaNumberKeypadSheet(
            controller: controller,
            backController: keypadBackController,
            nextController: keypadNextController,
            onChanged: keypadOnChanged,
            backOnChanged: keypadBackOnChanged,
            nextOnChanged: keypadNextOnChanged,
            onBack: keypadOnBack,
            onNext: keypadOnNext,
            onJackpot: keypadOnJackpot,
            onEnter: keypadOnEnter ?? onSubmitted,
            enterController: nextEntryNumberController,
            backTargetFor: keypadBackTargetFor,
            nextTargetFor: keypadNextTargetFor,
            enterTargetFor: keypadEnterTargetFor,
            onActiveControllerChanged: keypadOnActiveControllerChanged,
            onActiveValueChanged: keypadOnActiveValueChanged,
          ),
          backgroundColor: Colors.transparent,
        );
      },
      textAlign: TextAlign.center,
      textInputAction: textInputAction,
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : maxLength > 5
              ? TextInputType.text
              : TextInputType.number,
      inputFormatters: [
        if (allowDecimal)
          const _DecimalAmountInputFormatter()
        else if (maxLength > 5)
          const _ManualNumberInputFormatter()
        else
          const _LocalizedDigitsOnlyInputFormatter(),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted?.call(),
      style: TextStyle(
        fontSize: compact ? 12 : 14,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        errorText:
            hasError && showErrorText ? context.trMaybe(errorText!) : null,
        errorMaxLines: 2,
        counterText: '',
        filled: true,
        fillColor: hasError ? Colors.red.shade100 : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: hasError
              ? const BorderSide(color: Colors.red, width: 2)
              : const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: hasError
              ? const BorderSide(color: Colors.red, width: 2)
              : const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        isDense: true,
        prefixIcon: prefixText == null
            ? null
            : _SessionArrowMarker(
                text: prefixText!,
                compact: compact,
                separatorBefore: false,
              ),
        prefixIconConstraints: prefixText == null
            ? null
            : BoxConstraints(
                minWidth: compact ? 24 : 30,
                minHeight: compact ? 26 : 34,
              ),
        suffixIcon: suffixText == null
            ? null
            : _SessionArrowMarker(
                text: suffixText!,
                compact: compact,
                separatorBefore: true,
              ),
        suffixIconConstraints: suffixText == null
            ? null
            : BoxConstraints(
                minWidth: compact ? 24 : 30,
                minHeight: compact ? 26 : 34,
              ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 6,
          vertical: compact ? 4 : 8,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

class _SessionArrowMarker extends StatelessWidget {
  const _SessionArrowMarker({
    required this.text,
    required this.compact,
    required this.separatorBefore,
  });

  final String text;
  final bool compact;
  final bool separatorBefore;

  @override
  Widget build(BuildContext context) {
    const separatorSide = BorderSide(color: Color(0xFFCCCCCC), width: 1);
    final markerBorder = separatorBefore
        ? const Border(left: separatorSide)
        : const Border(right: separatorSide);

    return Container(
      width: compact ? 24 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: markerBorder),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF111820),
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _AmountFillField extends StatelessWidget {
  const _AmountFillField({
    required this.controller,
    required this.focusNode,
    required this.compact,
    required this.highlighted,
    required this.isSource,
    required this.onFillStart,
    required this.onFillHover,
    required this.onFillEnd,
    required this.onMobileFill,
    required this.onChanged,
    required this.onSubmitted,
    this.keypadBackController,
    this.keypadNextController,
    this.keypadOnChanged,
    this.keypadBackOnChanged,
    this.keypadNextOnChanged,
    this.keypadOnBack,
    this.keypadOnNext,
    this.keypadOnJackpot,
    this.keypadOnEnter,
    this.keypadBackTargetFor,
    this.keypadNextTargetFor,
    this.keypadEnterTargetFor,
    this.keypadOnActiveControllerChanged,
    this.keypadOnActiveValueChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool compact;
  final bool highlighted;
  final bool isSource;
  final VoidCallback onFillStart;
  final VoidCallback onFillHover;
  final VoidCallback onFillEnd;
  final VoidCallback onMobileFill;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final TextEditingController? keypadBackController;
  final TextEditingController? keypadNextController;
  final VoidCallback? keypadOnChanged;
  final VoidCallback? keypadBackOnChanged;
  final VoidCallback? keypadNextOnChanged;
  final VoidCallback? keypadOnBack;
  final VoidCallback? keypadOnNext;
  final TextEditingController? Function()? keypadOnJackpot;
  final VoidCallback? keypadOnEnter;
  final TextEditingController? Function(TextEditingController controller)?
      keypadBackTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      keypadNextTargetFor;
  final TextEditingController? Function(TextEditingController controller)?
      keypadEnterTargetFor;
  final ValueChanged<TextEditingController>? keypadOnActiveControllerChanged;
  final ValueChanged<TextEditingController>? keypadOnActiveValueChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onFillHover(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted
              ? _NewEntryPageState._blue.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _EntryTextField(
              controller: controller,
              focusNode: focusNode,
              compact: compact,
              maxLength: 8,
              allowDecimal: true,
              textInputAction: TextInputAction.done,
              keypadBackController: keypadBackController,
              keypadNextController: keypadNextController,
              keypadOnChanged: keypadOnChanged,
              keypadBackOnChanged: keypadBackOnChanged,
              keypadNextOnChanged: keypadNextOnChanged,
              keypadOnBack: keypadOnBack,
              keypadOnNext: keypadOnNext,
              keypadOnJackpot: keypadOnJackpot,
              keypadOnEnter: keypadOnEnter,
              keypadBackTargetFor: keypadBackTargetFor,
              keypadNextTargetFor: keypadNextTargetFor,
              keypadEnterTargetFor: keypadEnterTargetFor,
              keypadOnActiveControllerChanged: keypadOnActiveControllerChanged,
              keypadOnActiveValueChanged: keypadOnActiveValueChanged,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
            ),
            Positioned(
              right: compact ? 1 : 2,
              bottom: compact ? 1 : 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: compact ? onMobileFill : null,
                onPanStart: (_) => onFillStart(),
                onPanEnd: (_) => onFillEnd(),
                onPanCancel: onFillEnd,
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: Container(
                    width: compact ? 28 : 10,
                    height: compact ? 28 : 10,
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: compact ? 8 : 6,
                      height: compact ? 8 : 6,
                      decoration: BoxDecoration(
                        color: isSource
                            ? _NewEntryPageState._blue
                            : const Color(0xFF111820),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecimalAmountInputFormatter extends TextInputFormatter {
  const _DecimalAmountInputFormatter();

  static final _draftPattern = RegExp(r'^\d{0,6}(?:\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = AppLocalizations.normalizeDigits(newValue.text);
    if (text.isEmpty) return newValue;
    return _draftPattern.hasMatch(text)
        ? newValue.copyWith(
            text: AppLocalizations.normalizeDigits(text),
          )
        : oldValue;
  }
}

class _LocalizedDigitsOnlyInputFormatter extends TextInputFormatter {
  const _LocalizedDigitsOnlyInputFormatter();

  static final _digitsPattern = RegExp(r'^[0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = AppLocalizations.normalizeDigits(newValue.text);
    if (!_digitsPattern.hasMatch(text)) return oldValue;
    return newValue.copyWith(
      text: AppLocalizations.normalizeDigits(text),
    );
  }
}

class _ManualNumberInputFormatter extends TextInputFormatter {
  const _ManualNumberInputFormatter();

  static final _numericPattern = RegExp(r'^[0-9> \-*]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = AppLocalizations.normalizeDigits(newValue.text);
    if (text.isEmpty) return newValue;
    if (_letterPattern.hasMatch(text)) {
      return _singleSpDpDraftPattern.hasMatch(text) ||
              _singleCutPDraftPattern.hasMatch(text) ||
              _commonDraftPattern.hasMatch(text) ||
              _bazarSangamDraftPattern.hasMatch(text) ||
              _familyDraftPattern.hasMatch(text) ||
              _cpJodiDraftPattern.hasMatch(text)
          ? newValue.copyWith(
              text: AppLocalizations.normalizeDigits(text),
            )
          : oldValue;
    }
    return _numericPattern.hasMatch(text)
        ? newValue.copyWith(
            text: AppLocalizations.normalizeDigits(text),
          )
        : oldValue;
  }
}

class _AutoConfigPanel extends StatelessWidget {
  const _AutoConfigPanel({
    required this.configs,
    required this.selectedType,
    required this.selectedSubtype,
    required this.numberOptions,
    required this.hasConfiguredNumbers,
    required this.showNumberTable,
    required this.availableColumns,
    required this.selectedColumn,
    required this.searchController,
    required this.entries,
    required this.compact,
    required this.onTypeSelected,
    required this.onSubtypeSelected,
    required this.onColumnSelected,
    required this.onSearchChanged,
    required this.onNumberSelected,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onAddRow,
    required this.onAddTenRows,
    required this.onDelete,
    this.autoSearchError,
    this.onClearError,
  });

  final List<GameBetTypeConfig> configs;
  final GameBetTypeConfig? selectedType;
  final GameBetSubtypeConfig? selectedSubtype;
  final List<GameNumberOption> numberOptions;
  final bool hasConfiguredNumbers;
  final bool showNumberTable;
  final List<int> availableColumns;
  final int? selectedColumn;
  final TextEditingController searchController;
  final List<_AutoBetEntry> entries;
  final bool compact;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String> onSubtypeSelected;
  final ValueChanged<int?> onColumnSelected;
  final VoidCallback onSearchChanged;
  final ValueChanged<GameNumberOption> onNumberSelected;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final VoidCallback onAddTenRows;
  final ValueChanged<_AutoBetEntry> onDelete;
  final String? autoSearchError;
  final VoidCallback? onClearError;

  @override
  Widget build(BuildContext context) {
    if (configs.isEmpty) {
      return _AutoConfigNotice(
        text: 'Business rule not currently defined.',
        compact: compact,
      );
    }

    final content = Padding(
      padding: EdgeInsets.all(compact ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
            autoSearchError: autoSearchError,
            onClearError: onClearError,
          ),
          const SizedBox(height: 12),
          _AutoConfigRows(
            options: numberOptions,
            hasConfiguredNumbers: hasConfiguredNumbers,
            searchText: searchController.text,
            entries: entries,
            compact: compact,
            onNumberSelected: onNumberSelected,
            numberError: numberError,
            amountError: amountError,
            onChanged: onChanged,
            onAddRow: onAddRow,
            onAddTenRows: onAddTenRows,
            onDelete: onDelete,
            emptyText: selectedSubtype?.missingRule ??
                selectedType?.missingRule ??
                'Business rule not currently defined.',
          ),
          const SizedBox(height: 10),
          _ValidationHint(
            text: selectedSubtype?.helperText ??
                selectedType?.helperText ??
                'Business rule not currently defined.',
          ),
        ],
      ),
    );

    if (compact) return content;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewEntryPageState._line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: _AutoConfigTypeSelector(
              configs: configs,
              selectedId: selectedType?.id ?? '',
              compact: false,
              onSelected: onTypeSelected,
            ),
          ),
          Container(width: 1, color: _NewEntryPageState._line),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _AutoConfigTypeSelector extends StatelessWidget {
  const _AutoConfigTypeSelector({
    required this.configs,
    required this.selectedId,
    required this.compact,
    required this.onSelected,
  });

  final List<GameBetTypeConfig> configs;
  final String selectedId;
  final bool compact;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: configs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final config = configs[index];
            return _AutoConfigButton(
              label: config.label,
              selected: config.id == selectedId,
              compact: true,
              onPressed: () => onSelected(config.id),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final config in configs)
          _AutoConfigButton(
            label: config.label,
            selected: config.id == selectedId,
            compact: false,
            onPressed: () => onSelected(config.id),
          ),
      ],
    );
  }
}

class _AutoConfigButton extends StatelessWidget {
  const _AutoConfigButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 38 : 44,
      width: compact ? 112 : double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected ? _NewEntryPageState._blue : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        child: Text(
          context.trMaybe(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

bool _isMotorAutoType(GameBetTypeConfig? type) {
  return type?.id == 'sp_motor' || type?.id == 'dp_motor';
}

bool _matchesAutoNumberSearch(String value, String search) {
  final query = search.trim();
  if (query.isEmpty) return true;
  if (value.contains(query)) return true;
  final normalizedQuery = _digitsOnly(query);
  if (normalizedQuery.isEmpty) return false;
  return _digitsOnly(value).contains(normalizedQuery);
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

bool _hasRepeatedDigit(String value) {
  final digits = _digitsOnly(value);
  final seen = <String>{};
  for (final digit in digits.split('')) {
    if (!seen.add(digit)) return true;
  }
  return false;
}

class _AutoConfigSearchBar extends StatelessWidget {
  const _AutoConfigSearchBar({
    required this.searchController,
    required this.columns,
    required this.selectedColumn,
    required this.compact,
    required this.onSearchChanged,
    required this.onColumnSelected,
    this.autoSearchError,
    this.onClearError,
  });

  final TextEditingController searchController;
  final List<int> columns;
  final int? selectedColumn;
  final bool compact;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onColumnSelected;
  final String? autoSearchError;
  final VoidCallback? onClearError;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchController,
      keyboardType: TextInputType.text,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(7),
      ],
      onChanged: (_) {
        if (autoSearchError != null) onClearError?.call();
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: context.tr('Search Number'),
        errorText:
            autoSearchError == null ? null : context.trMaybe(autoSearchError!),
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );

    final columnFilter = DropdownButtonFormField<int?>(
      initialValue: selectedColumn,
      decoration: InputDecoration(
        labelText: context.tr('Column'),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(context.tr('All')),
        ),
        for (final column in columns)
          DropdownMenuItem<int?>(
            value: column,
            child: Text(
              context.tr('Column {column}', params: {'column': column}),
            ),
          ),
      ],
      onChanged: onColumnSelected,
    );

    if (compact) {
      return Column(
        children: [
          search,
          if (columns.isNotEmpty) ...[
            const SizedBox(height: 8),
            columnFilter,
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: search),
        if (columns.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(child: columnFilter),
        ],
      ],
    );
  }
}

class _AutoNumberTable extends StatefulWidget {
  const _AutoNumberTable({
    required this.options,
    required this.compact,
    required this.onSelected,
  });

  final List<GameNumberOption> options;
  final bool compact;
  final ValueChanged<GameNumberOption> onSelected;

  @override
  State<_AutoNumberTable> createState() => _AutoNumberTableState();
}

class _AutoNumberTableState extends State<_AutoNumberTable> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasConfiguredColumns =
        widget.options.any((option) => option.column != null);

    final hasSp = widget.options.any((o) => o.pannaType?.toUpperCase() == 'SP');
    final hasDpTp = widget.options.any((o) =>
        o.pannaType?.toUpperCase() == 'DP' ||
        o.pannaType?.toUpperCase() == 'TP');
    final isSplit = hasSp && hasDpTp;

    List<TableRow> buildRows(List<GameNumberOption> subsetOptions) {
      final columns = <int, List<GameNumberOption>>{
        for (var column = 1; column <= 10; column++)
          column: <GameNumberOption>[],
      };
      for (final option in subsetOptions) {
        final column = _columnForOption(option, hasConfiguredColumns);
        columns[column]!.add(option);
      }
      final rowCount = columns.values.fold<int>(
        0,
        (max, values) => values.length > max ? values.length : max,
      );
      return [
        for (var row = 0; row < rowCount; row++)
          TableRow(
            children: [
              for (var column = 1; column <= 10; column++)
                _PanaTableNumberCell(
                  option: row < columns[column]!.length
                      ? columns[column]![row]
                      : null,
                  compact: widget.compact,
                  onSelected: widget.onSelected,
                ),
            ],
          ),
      ];
    }

    if (widget.options.isEmpty) {
      return _AutoConfigNotice(
        text: 'No numbers match current filter.',
        compact: widget.compact,
      );
    }

    final List<TableRow> tableRows = [];
    if (isSplit) {
      final spOptions = widget.options
          .where((o) => o.pannaType?.toUpperCase() == 'SP')
          .toList();
      final dpTpOptions = widget.options
          .where((o) =>
              o.pannaType?.toUpperCase() == 'DP' ||
              o.pannaType?.toUpperCase() == 'TP')
          .toList();

      tableRows.addAll(buildRows(spOptions));
      tableRows.add(
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFD1D5DB),
          ),
          children: [
            for (var i = 0; i < 10; i++) const SizedBox(height: 6),
          ],
        ),
      );
      tableRows.addAll(buildRows(dpTpOptions));
    } else {
      tableRows.addAll(buildRows(widget.options));
    }

    final minWidth = widget.compact ? 640.0 : 720.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF111827), width: 1.2),
      ),
      child: SizedBox(
        height: widget.compact ? 360 : 520,
        child: Scrollbar(
          controller: _horizontalController,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalController,
            primary: false,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minWidth,
              child: Scrollbar(
                controller: _verticalController,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  primary: false,
                  child: Table(
                    border: TableBorder.all(
                      color: const Color(0xFF111827),
                      width: 1,
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration:
                            const BoxDecoration(color: Color(0xFFEAF2FF)),
                        children: [
                          for (var column = 1; column <= 10; column++)
                            _PanaTableHeaderCell(text: '$column'),
                        ],
                      ),
                      ...tableRows,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _columnForOption(GameNumberOption option, bool hasConfiguredColumns) {
    final configuredColumn = option.column;
    if (configuredColumn != null) {
      return configuredColumn.clamp(1, 10).toInt();
    }
    if (!hasConfiguredColumns && option.value.isNotEmpty) {
      final lastDigit = int.tryParse(option.value[option.value.length - 1]);
      if (lastDigit != null) return lastDigit == 0 ? 10 : lastDigit;
    }
    return 10;
  }
}

class _NumberPickerDialog extends StatelessWidget {
  const _NumberPickerDialog({
    required this.options,
    required this.compact,
  });

  final List<GameNumberOption> options;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40,
        vertical: compact ? 18 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? 720 : 920,
          maxHeight: compact ? 520 : 680,
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.table_chart_outlined,
                    color: _NewEntryPageState._blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Select Number'),
                      style: const TextStyle(
                        color: _NewEntryPageState._blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _AutoNumberTable(
                  options: options,
                  compact: compact,
                  onSelected: (option) => Navigator.of(context).pop(option),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanaTableHeaderCell extends StatelessWidget {
  const _PanaTableHeaderCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: _NewEntryPageState._blue,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PanaTableNumberCell extends StatelessWidget {
  const _PanaTableNumberCell({
    required this.option,
    required this.compact,
    required this.onSelected,
  });

  final GameNumberOption? option;
  final bool compact;
  final ValueChanged<GameNumberOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final value = option?.value ?? '';
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: option == null ? null : () => onSelected(option!),
        child: SizedBox(
          height: compact ? 28 : 30,
          child: Center(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF111827),
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoSearchResultsGrid extends StatelessWidget {
  const _AutoSearchResultsGrid({
    required this.options,
    required this.compact,
    required this.onSelected,
  });

  final List<GameNumberOption> options;
  final bool compact;
  final ValueChanged<GameNumberOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final columnCount = compact ? 4 : 8;
    final rowCount = (options.length / columnCount).ceil();
    final cappedRows = rowCount > 4 ? 4 : rowCount;
    final cellHeight = compact ? 34.0 : 38.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewEntryPageState._line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: SizedBox(
        height: cappedRows * cellHeight,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisExtent: cellHeight,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => onSelected(option),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: _NewEntryPageState._line),
                      bottom: BorderSide(color: _NewEntryPageState._line),
                    ),
                  ),
                  child: Text(
                    option.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF111827),
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AutoConfigRows extends StatelessWidget {
  const _AutoConfigRows({
    required this.options,
    required this.hasConfiguredNumbers,
    required this.searchText,
    required this.entries,
    required this.compact,
    required this.onNumberSelected,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onAddRow,
    required this.onAddTenRows,
    required this.onDelete,
    required this.emptyText,
  });

  final List<GameNumberOption> options;
  final bool hasConfiguredNumbers;
  final String searchText;
  final List<_AutoBetEntry> entries;
  final bool compact;
  final ValueChanged<GameNumberOption> onNumberSelected;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final VoidCallback onAddTenRows;
  final ValueChanged<_AutoBetEntry> onDelete;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (!hasConfiguredNumbers) {
      return _AutoConfigNotice(text: emptyText, compact: compact);
    }
    if (options.isEmpty && entries.every((entry) => !entry.hasAnyValue)) {
      return _AutoConfigNotice(
        text: 'No numbers match current filter.',
        compact: compact,
      );
    }
    final showSearchResults = searchText.trim().isNotEmpty;

    if (compact) {
      return Column(
        children: [
          if (showSearchResults && options.isEmpty) ...[
            _AutoConfigNotice(
              text: 'No numbers match current filter.',
              compact: true,
            ),
            const SizedBox(height: 8),
          ],
          if (showSearchResults && options.isNotEmpty) ...[
            _AutoSearchResultsGrid(
              options: options,
              compact: true,
              onSelected: onNumberSelected,
            ),
            const SizedBox(height: 8),
          ],
          for (var index = 0; index < entries.length; index++)
            _AutoConfigMobileRow(
              index: index,
              entry: entries[index],
              options: options,
              numberError: entries[index].hasAnyValue
                  ? numberError(entries[index])
                  : null,
              amountError: entries[index].hasAnyValue
                  ? amountError(entries[index])
                  : null,
              onChanged: onChanged,
              onDelete: onDelete,
            ),
          const SizedBox(height: 8),
          _AutoRowsFooter(
            compact: true,
            canAdd: options.isNotEmpty,
            onAddRow: onAddRow,
            onAddTenRows: onAddTenRows,
          ),
        ],
      );
    }

    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w900);
    return Column(
      children: [
        if (showSearchResults && options.isEmpty) ...[
          _AutoConfigNotice(
            text: 'No numbers match current filter.',
            compact: false,
          ),
          const SizedBox(height: 10),
        ],
        if (showSearchResults && options.isNotEmpty) ...[
          _AutoSearchResultsGrid(
            options: options,
            compact: false,
            onSelected: onNumberSelected,
          ),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: const Color(0xFFF6F8FB),
          child: const Row(
            children: [
              _HeaderCell('#', flex: 7, style: headerStyle),
              _HeaderCell('NUMBER', flex: 28, style: headerStyle),
              _HeaderCell('AMOUNT ($_rs)', flex: 24, style: headerStyle),
              _HeaderCell('OPEN MKT.', flex: 16, style: headerStyle),
              _HeaderCell('ACTION', flex: 13, style: headerStyle),
            ],
          ),
        ),
        for (var index = 0; index < entries.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _NewEntryPageState._line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DataCell(Text('${index + 1}'), flex: 7),
                _DataCell(
                  _AutoNumberDropdown(
                    controller: entries[index].number,
                    options: options,
                    errorText: entries[index].hasAnyValue
                        ? numberError(entries[index])
                        : null,
                    onChanged: onChanged,
                  ),
                  flex: 28,
                ),
                _DataCell(
                  _AutoAmountField(
                    controller: entries[index].amount,
                    errorText: entries[index].hasAnyValue
                        ? amountError(entries[index])
                        : null,
                    onChanged: onChanged,
                  ),
                  flex: 24,
                ),
                const _DataCell(
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Icon(Icons.lock,
                        color: _NewEntryPageState._green, size: 18),
                  ),
                  flex: 16,
                ),
                _DataCell(
                  IconButton(
                    tooltip: context.tr('Delete row'),
                    onPressed: () => onDelete(entries[index]),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: _NewEntryPageState._red,
                    ),
                  ),
                  flex: 13,
                ),
              ],
            ),
          ),
        _AutoRowsFooter(
          compact: false,
          canAdd: options.isNotEmpty,
          onAddRow: onAddRow,
          onAddTenRows: onAddTenRows,
        ),
      ],
    );
  }
}

class _AutoConfigMobileRow extends StatelessWidget {
  const _AutoConfigMobileRow({
    required this.index,
    required this.entry,
    required this.options,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _AutoBetEntry entry;
  final List<GameNumberOption> options;
  final String? numberError;
  final String? amountError;
  final VoidCallback onChanged;
  final ValueChanged<_AutoBetEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewEntryPageState._line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              const Icon(Icons.lock,
                  color: _NewEntryPageState._green, size: 17),
              IconButton(
                tooltip: context.tr('Delete row'),
                onPressed: () => onDelete(entry),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline,
                  color: _NewEntryPageState._red,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _AutoNumberDropdown(
                  controller: entry.number,
                  options: options,
                  labelText: 'Number',
                  errorText: numberError,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AutoAmountField(
                  controller: entry.amount,
                  labelText: 'Amount',
                  errorText: amountError,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoRowsFooter extends StatelessWidget {
  const _AutoRowsFooter({
    required this.compact,
    required this.canAdd,
    required this.onAddRow,
    required this.onAddTenRows,
  });

  final bool compact;
  final bool canAdd;
  final VoidCallback onAddRow;
  final VoidCallback onAddTenRows;

  @override
  Widget build(BuildContext context) {
    final addOne = OutlinedButton.icon(
      onPressed: canAdd ? onAddRow : null,
      icon: const Icon(Icons.add),
      label: Text(context.tr('Add More')),
      style: OutlinedButton.styleFrom(
        foregroundColor: _NewEntryPageState._blue,
        side:
            BorderSide(color: _NewEntryPageState._blue.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
    final addTen = OutlinedButton.icon(
      onPressed: canAdd ? onAddTenRows : null,
      icon: const Icon(Icons.playlist_add),
      label: Text(context.tr('10 Rows')),
      style: OutlinedButton.styleFrom(
        foregroundColor: _NewEntryPageState._green,
        side: BorderSide(
            color: _NewEntryPageState._green.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(child: addOne),
          const SizedBox(width: 8),
          Expanded(child: addTen),
        ],
      );
    }

    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        border: Border(top: BorderSide(color: _NewEntryPageState._line)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [addOne, addTen],
      ),
    );
  }
}

class _AutoNumberDropdown extends StatelessWidget {
  const _AutoNumberDropdown({
    required this.controller,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.labelText,
  });

  final TextEditingController controller;
  final List<GameNumberOption> options;
  final VoidCallback onChanged;
  final String? errorText;
  final String? labelText;

  Future<void> _openPicker(BuildContext context) async {
    final selectedOption = await showDialog<GameNumberOption>(
      context: context,
      builder: (context) => _NumberPickerDialog(
        options: options,
        compact: MediaQuery.sizeOf(context).width < 720,
      ),
    );
    if (selectedOption == null) return;
    controller.text = selectedOption.value;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final canPick = options.isNotEmpty;
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        readOnly: true,
        textAlign: TextAlign.center,
        onTap: canPick ? () => _openPicker(context) : null,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        decoration: InputDecoration(
          labelText: labelText == null ? null : context.trMaybe(labelText!),
          errorText: errorText == null ? null : context.trMaybe(errorText!),
          hintText: context.tr('Select'),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          suffixIconConstraints: const BoxConstraints(maxHeight: 30),
          suffixIcon: IconButton(
            padding: EdgeInsets.zero,
            tooltip: context.tr('Open number table'),
            onPressed: canPick ? () => _openPicker(context) : null,
            icon: const Icon(Icons.table_chart_outlined, size: 18),
          ),
        ),
      ),
    );
  }
}

class _AutoAmountField extends StatelessWidget {
  const _AutoAmountField({
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.labelText,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? errorText;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          const _DecimalAmountInputFormatter(),
          LengthLimitingTextInputFormatter(8),
        ],
        onChanged: (_) => onChanged(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        decoration: InputDecoration(
          labelText: labelText == null ? null : context.trMaybe(labelText!),
          errorText: errorText == null ? null : context.trMaybe(errorText!),
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

class _AutoConfigNotice extends StatelessWidget {
  const _AutoConfigNotice({required this.text, required this.compact});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        border: Border.all(color: const Color(0xFFF2B84B)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        context.trMaybe(text),
        style: const TextStyle(
          color: Color(0xFF7A4B00),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AutoEntryPanel extends StatelessWidget {
  const _AutoEntryPanel({
    required this.configs,
    required this.selectedType,
    required this.entries,
    required this.compact,
    required this.numberError,
    required this.amountError,
    required this.onTypeSelected,
    required this.onChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final List<EntryTypeConfig> configs;
  final EntryTypeConfig selectedType;
  final List<_AutoBetEntry> entries;
  final bool compact;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final ValueChanged<String> onTypeSelected;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<_AutoBetEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AutoTypeSelector(
            configs: configs,
            selectedId: selectedType.id,
            compact: true,
            onSelected: onTypeSelected,
          ),
          const SizedBox(height: 10),
          _SelectedTypeHeader(type: selectedType, compact: true),
          const SizedBox(height: 8),
          _AutoMobileRows(
            selectedType: selectedType,
            entries: entries,
            numberError: numberError,
            amountError: amountError,
            onChanged: onChanged,
            onAdd: onAdd,
            onDelete: onDelete,
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewEntryPageState._line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: _AutoTypeSelector(
              configs: configs,
              selectedId: selectedType.id,
              compact: false,
              onSelected: onTypeSelected,
            ),
          ),
          Container(width: 1, color: _NewEntryPageState._line),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SelectedTypeHeader(type: selectedType, compact: false),
                  const SizedBox(height: 12),
                  _AutoRowsTable(
                    selectedType: selectedType,
                    entries: entries,
                    numberError: numberError,
                    amountError: amountError,
                    onChanged: onChanged,
                    onAdd: onAdd,
                    onDelete: onDelete,
                  ),
                  const SizedBox(height: 10),
                  _ValidationHint(text: selectedType.helperText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoTypeSelector extends StatelessWidget {
  const _AutoTypeSelector({
    required this.configs,
    required this.selectedId,
    required this.compact,
    required this.onSelected,
  });

  final List<EntryTypeConfig> configs;
  final String selectedId;
  final bool compact;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: configs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final config = configs[index];
            final selected = config.id == selectedId;
            return _AutoTypeButton(
              label: config.name,
              selected: selected,
              compact: true,
              onPressed: () => onSelected(config.id),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final config in configs)
          _AutoTypeButton(
            label: config.name,
            selected: config.id == selectedId,
            compact: false,
            onPressed: () => onSelected(config.id),
          ),
      ],
    );
  }
}

class _AutoTypeButton extends StatelessWidget {
  const _AutoTypeButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 38 : 44,
      width: compact ? 112 : double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected ? _NewEntryPageState._blue : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        child: Text(
          context.trMaybe(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SelectedTypeHeader extends StatelessWidget {
  const _SelectedTypeHeader({required this.type, required this.compact});

  final EntryTypeConfig type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text(
          context.tr('Selected Type :'),
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          context.trMaybe(type.name),
          style: TextStyle(
            color: _NewEntryPageState._blue,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            context.tr(
              '{length}-digit only',
              params: {'length': type.allowedLength},
            ),
            style: const TextStyle(
              color: _NewEntryPageState._blue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoRowsTable extends StatelessWidget {
  const _AutoRowsTable({
    required this.selectedType,
    required this.entries,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final EntryTypeConfig selectedType;
  final List<_AutoBetEntry> entries;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<_AutoBetEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w900);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: const Color(0xFFF6F8FB),
          child: const Row(
            children: [
              _HeaderCell('#', flex: 7, style: headerStyle),
              _HeaderCell('NUMBER', flex: 24, style: headerStyle),
              _HeaderCell('AMOUNT ($_rs)', flex: 24, style: headerStyle),
              _HeaderCell('OPEN MKT.', flex: 16, style: headerStyle),
              _HeaderCell('ACTION', flex: 13, style: headerStyle),
            ],
          ),
        ),
        for (var index = 0; index < entries.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _NewEntryPageState._line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DataCell(Text('${index + 1}'), flex: 7),
                _DataCell(
                  _AutoTextField(
                    controller: entries[index].number,
                    maxLength: selectedType.allowedLength,
                    errorText: entries[index].hasAnyValue
                        ? numberError(entries[index])
                        : null,
                    onChanged: onChanged,
                  ),
                  flex: 24,
                ),
                _DataCell(
                  _AutoTextField(
                    controller: entries[index].amount,
                    maxLength: 8,
                    allowDecimal: true,
                    errorText: entries[index].hasAnyValue
                        ? amountError(entries[index])
                        : null,
                    onChanged: onChanged,
                  ),
                  flex: 24,
                ),
                const _DataCell(
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Icon(Icons.lock,
                        color: _NewEntryPageState._green, size: 18),
                  ),
                  flex: 16,
                ),
                _DataCell(
                  IconButton(
                    tooltip: context.tr('Delete row'),
                    onPressed: () => onDelete(entries[index]),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: _NewEntryPageState._red,
                    ),
                  ),
                  flex: 13,
                ),
              ],
            ),
          ),
        Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFF),
            border: Border(top: BorderSide(color: _NewEntryPageState._line)),
          ),
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Add More')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _NewEntryPageState._blue,
              side: BorderSide(
                  color: _NewEntryPageState._blue.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoMobileRows extends StatelessWidget {
  const _AutoMobileRows({
    required this.selectedType,
    required this.entries,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final EntryTypeConfig selectedType;
  final List<_AutoBetEntry> entries;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<_AutoBetEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _NewEntryPageState._line),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    const Icon(Icons.lock,
                        color: _NewEntryPageState._green, size: 17),
                    IconButton(
                      tooltip: context.tr('Delete row'),
                      onPressed: () => onDelete(entries[index]),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: _NewEntryPageState._red,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AutoTextField(
                        controller: entries[index].number,
                        labelText: 'Number',
                        maxLength: selectedType.allowedLength,
                        errorText: entries[index].hasAnyValue
                            ? numberError(entries[index])
                            : null,
                        onChanged: onChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AutoTextField(
                        controller: entries[index].amount,
                        labelText: 'Amount',
                        maxLength: 8,
                        allowDecimal: true,
                        errorText: entries[index].hasAnyValue
                            ? amountError(entries[index])
                            : null,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Add More')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _NewEntryPageState._blue,
              side: BorderSide(
                  color: _NewEntryPageState._blue.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ValidationHint(text: selectedType.helperText),
      ],
    );
  }
}

class _AutoTextField extends StatelessWidget {
  const _AutoTextField({
    required this.controller,
    required this.maxLength,
    required this.onChanged,
    this.errorText,
    this.labelText,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onChanged;
  final String? errorText;
  final String? labelText;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: allowDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: [
          allowDecimal
              ? const _DecimalAmountInputFormatter()
              : FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        onChanged: (_) => onChanged(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        decoration: InputDecoration(
          labelText: labelText == null ? null : context.trMaybe(labelText!),
          errorText: errorText == null ? null : context.trMaybe(errorText!),
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

class _ValidationHint extends StatelessWidget {
  const _ValidationHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info, color: _NewEntryPageState._blue, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.trMaybe(text),
            style: const TextStyle(
              color: _NewEntryPageState._blue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.parchiNo,
    required this.marketSession,
    required this.session,
    required this.lines,
    required this.otcPages,
    required this.compact,
  });

  final String parchiNo;
  final String marketSession;
  final String session;
  final List<_ReceiptLine> lines;
  final Set<int> otcPages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pages = _receiptLinePages(lines);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var pageIndex = 0; pageIndex < pages.length; pageIndex++)
            Padding(
              padding: EdgeInsets.only(
                bottom: pageIndex == pages.length - 1 ? 0 : (compact ? 12 : 18),
              ),
              child: _ReceiptPreviewTicket(
                parchiNo: _parchiNoForPage(parchiNo, pageIndex),
                marketSession: marketSession,
                session: session,
                lines: pages[pageIndex],
                pageTotalAmount: _receiptPageTotal(
                  pages[pageIndex],
                  isOtc: otcPages.contains(pageIndex),
                ),
                isOtc: otcPages.contains(pageIndex),
                compact: compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptPreviewTicket extends StatelessWidget {
  const _ReceiptPreviewTicket({
    required this.parchiNo,
    required this.marketSession,
    required this.session,
    required this.lines,
    required this.pageTotalAmount,
    required this.isOtc,
    required this.compact,
  });

  final String parchiNo;
  final String marketSession;
  final String session;
  final List<_ReceiptLine> lines;
  final num pageTotalAmount;
  final bool isOtc;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final amountTotal = AppLocalizations.localizeDigits(
      _formatAmount(pageTotalAmount),
    );
    final columnMetrics = _previewColumnMetrics(
      context,
      lines,
      session,
      amountTotal,
      compact,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 220 : 230),
      child: CustomPaint(
        painter: _ReceiptBorderPainter(),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 12 : 14,
            compact ? 10 : 12,
            compact ? 12 : 14,
          ),
          color: Colors.white.withValues(alpha: 0.96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: context.tr('PARCHI NO. '),
                                style: TextStyle(
                                  fontSize: compact ? 10 : 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: AppLocalizations.localizeDigits(parchiNo),
                                style: TextStyle(
                                  fontSize: compact ? 11 : 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF111820),
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 3),
                        Text(
                          context.trMaybe(session.toUpperCase()),
                          style: TextStyle(
                            color: const Color(0xFF111820),
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocalizations.localizeDigits(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                        ),
                        style: TextStyle(
                          color: const Color(0xFF111820),
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.localizeDigits(
                          DateFormat('hh:mm a').format(DateTime.now()),
                        ),
                        style: TextStyle(
                          color: const Color(0xFF111820),
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                AppLocalizations.localizeMarketName(
                  _previewMarketTitle(marketSession),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF111820),
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              const _PreviewRule(),
              SizedBox(height: compact ? 8 : 10),
              _PreviewHeader(compact: compact, metrics: columnMetrics),
              for (final line in lines)
                _PreviewParchiRow(
                  number: line.number,
                  amount: line.effectiveDisplayAmount,
                  session: line.sessionOverride ?? session,
                  compact: compact,
                  metrics: columnMetrics,
                  showMainEntry: line.showMainEntry,
                  isJackpot: line.isJackpot,
                  isBazarSangam: line.isBazarSangam,
                  isFamily: line.isFamily,
                  isCpJodi: line.isCpJodi,
                  isCommon: line.isCommon,
                  isSimpleJodi: line.isSimpleJodi,
                  isMotorPana: line.isMotorPana,
                  jackpotEntries: line.jackpotEntries,
                ),
              if (lines.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 10),
                if (isOtc) ...[
                  Text(
                    'OTC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _NewEntryPageState._green,
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      shadows: _receiptGreenAlphabetShadow,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                ],
                const _PreviewRule(),
                const SizedBox(height: 12),
                _PreviewTotalRow(
                  amount: amountTotal,
                  compact: compact,
                  metrics: columnMetrics,
                ),
              ] else ...[
                SizedBox(height: compact ? 36 : 48),
                const _PreviewRule(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewColumnMetrics {
  const _PreviewColumnMetrics({
    required this.numberWidth,
    required this.amountWidth,
    required this.gap,
  });

  final double numberWidth;
  final double amountWidth;
  final double gap;

  double get totalWidth => numberWidth + gap + amountWidth;
}

_PreviewColumnMetrics _previewColumnMetrics(
  BuildContext context,
  List<_ReceiptLine> lines,
  String session,
  String totalAmount,
  bool compact,
) {
  final gap = _previewColumnGap(compact);
  final headerStyle = _previewHeaderTextStyle(compact);
  final numberStyle = _previewNumberTextStyle(compact);
  final labelStyle = _previewLabelTextStyle(compact);
  final amountStyle = _previewAmountTextStyle(compact);
  final jackpotStyle = _previewJackpotTextStyle(compact);
  var numberWidth = _measurePreviewText(
    context.tr('NUMBER'),
    headerStyle,
    context,
  );
  var amountWidth = _measurePreviewText(
    context.tr('AMT'),
    headerStyle,
    context,
  );
  numberWidth = math.max(
    numberWidth,
    _measurePreviewText(
      context.tr('TOTAL'),
      _previewTotalTextStyle(compact),
      context,
    ),
  );
  amountWidth = math.max(
    amountWidth,
    _measurePreviewText(
      totalAmount,
      _previewTotalAmountTextStyle(compact),
      context,
    ),
  );

  for (final line in lines) {
    final lineSession = line.sessionOverride ?? session;
    final formattedNumber = _formatPreviewParchiNumber(
      number: line.number,
      session: lineSession,
      isFamily: line.isFamily,
      isCpJodi: line.isCpJodi,
      isCommon: line.isCommon,
      isSimpleJodi: line.isSimpleJodi,
    );
    if (line.showMainEntry) {
      final parts = NumberDisplayParts.fromDisplay(formattedNumber);
      numberWidth = math.max(
        numberWidth,
        _measurePreviewTextSpan(
          _previewNumberSpan(parts, numberStyle, labelStyle),
          context,
        ),
      );
      amountWidth = math.max(
        amountWidth,
        _measurePreviewText(
          AppLocalizations.localizeDigits(line.effectiveDisplayAmount),
          amountStyle,
          context,
        ),
      );
    }
    if (line.isJackpot) {
      for (final entry in line.jackpotEntries.where(
        (entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty,
      )) {
        numberWidth = math.max(
          numberWidth,
          _measurePreviewText(
              formattedNumber.trimRight(), numberStyle, context),
        );
        amountWidth = math.max(
          amountWidth,
          _measurePreviewText(
            AppLocalizations.localizeDigits(entry.amount),
            jackpotStyle,
            context,
          ),
        );
      }
    }
  }

  final maxNumberWidth =
      math.max(1.0, _previewMaxRowWidth(compact) - gap - amountWidth);
  return _PreviewColumnMetrics(
    numberWidth: math.min(numberWidth, maxNumberWidth),
    amountWidth: amountWidth,
    gap: gap,
  );
}

String _formatPreviewParchiNumber({
  required String number,
  required String session,
  required bool isFamily,
  required bool isCpJodi,
  required bool isCommon,
  required bool isSimpleJodi,
}) {
  var formattedNumber = number.replaceAll('*', ' * ').replaceAll('-', ' * ');
  if (isCpJodi) {
    final cpNumber = formattedNumber
        .replaceFirst(RegExp(r'^[cC][pP]\s*'), '')
        .replaceFirst(RegExp(r'\s*[cC][pP]$'), '')
        .trim();
    if (session == 'Open') {
      formattedNumber = '$cpNumber CP >';
    } else if (session == 'Close') {
      formattedNumber = '>$cpNumber CP';
    } else {
      formattedNumber = '$cpNumber CP';
    }
  } else if (isSimpleJodi) {
    formattedNumber = formattedNumber.trim();
  } else if (session == 'Open') {
    if (isFamily) {
      formattedNumber = formattedNumber
          .replaceFirst(RegExp(r'^[fF]\s*'), '')
          .replaceFirst(RegExp(r'\s*[fF]$'), '')
          .trim();
      formattedNumber = '${formattedNumber}F';
    }
    if (isCommon && !formattedNumber.trim().toUpperCase().endsWith('COMMON')) {
      formattedNumber = '$formattedNumber COMMON';
    }
    final isFamilyPair = RegExp(
      r'^[0-9]{2}\s*F$',
      caseSensitive: false,
    ).hasMatch(formattedNumber.trim());
    if (!isFamily || !isFamilyPair) {
      formattedNumber = '$formattedNumber >';
    }
  } else if (session == 'Close') {
    if (isFamily) {
      formattedNumber = formattedNumber
          .replaceFirst(RegExp(r'^[fF]\s*'), '')
          .replaceFirst(RegExp(r'\s*[fF]$'), '')
          .trim();
      formattedNumber = '${formattedNumber}F';
    }
    if (isCommon && !formattedNumber.trim().toUpperCase().endsWith('COMMON')) {
      formattedNumber = '$formattedNumber COMMON';
    }
    final isFamilyPair = RegExp(
      r'^[0-9]{2}\s*F$',
      caseSensitive: false,
    ).hasMatch(formattedNumber.trim());
    if (!isFamily || !isFamilyPair) {
      formattedNumber = '> $formattedNumber';
    }
  } else if (isFamily) {
    formattedNumber = formattedNumber
        .replaceFirst(RegExp(r'^[fF]\s*'), '')
        .replaceFirst(RegExp(r'\s*[fF]$'), '')
        .trim();
    formattedNumber = '${formattedNumber}F';
  } else if (isCommon &&
      !formattedNumber.trim().toUpperCase().endsWith('COMMON')) {
    formattedNumber = '$formattedNumber COMMON';
  }
  return formattedNumber;
}

TextSpan _previewNumberSpan(
  NumberDisplayParts parts,
  TextStyle numberTextStyle,
  TextStyle labelTextStyle,
) {
  return TextSpan(
    children: [
      if (parts.leadingArrow.isNotEmpty)
        TextSpan(text: '${parts.leadingArrow} ', style: labelTextStyle),
      if (parts.beforeSuffix.isNotEmpty)
        TextSpan(
          text: AppLocalizations.localizeDigits(parts.beforeSuffix),
          style: numberTextStyle,
        ),
      if (parts.suffix.isNotEmpty)
        TextSpan(
          text: AppLocalizations.localizeDigits(
            '${parts.beforeSuffix.isEmpty ? '' : ' '}${parts.suffix}',
          ),
          style: labelTextStyle,
        ),
      if (parts.trailingArrow.isNotEmpty)
        TextSpan(text: ' ${parts.trailingArrow}', style: labelTextStyle),
    ],
  );
}

TextStyle _previewHeaderTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 10 : 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

TextStyle _previewNumberTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 9 : 11,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: 0,
  );
}

TextStyle _previewLabelTextStyle(bool compact) {
  return _previewNumberTextStyle(compact).copyWith(
    color: Colors.black,
    fontWeight: FontWeight.w900,
    shadows: _receiptAlphabetShadow,
  );
}

TextStyle _previewAmountTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 9 : 11,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
  );
}

TextStyle _previewJackpotTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 9 : 11,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
  );
}

TextStyle _previewTotalTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 12 : 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

TextStyle _previewTotalAmountTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 12 : 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

double _previewColumnGap(bool compact) => compact ? 10 : 12;

double _previewMaxRowWidth(bool compact) => compact ? 186 : 192;

double _measurePreviewText(
  String value,
  TextStyle style,
  BuildContext context,
) {
  return _measurePreviewTextSpan(TextSpan(text: value, style: style), context);
}

double _measurePreviewTextSpan(InlineSpan span, BuildContext context) {
  final painter = TextPainter(
    text: span,
    maxLines: 1,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  )..layout();
  return painter.width;
}

class _PreviewTotalRow extends StatelessWidget {
  const _PreviewTotalRow({
    required this.amount,
    required this.compact,
    required this.metrics,
  });

  final String amount;
  final bool compact;
  final _PreviewColumnMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 0),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: metrics.numberWidth,
              child: Text(
                context.tr('TOTAL'),
                style: _previewTotalTextStyle(compact),
              ),
            ),
            SizedBox(width: metrics.gap),
            SizedBox(
              width: metrics.amountWidth,
              child: Text(
                amount,
                textAlign: TextAlign.right,
                style: _previewTotalAmountTextStyle(compact),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.compact, required this.metrics});

  final bool compact;
  final _PreviewColumnMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(7, 0, 7, compact ? 6 : 8),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: metrics.numberWidth,
              child: Text(
                context.tr('NUMBER'),
                style: _previewHeaderTextStyle(compact),
              ),
            ),
            SizedBox(width: metrics.gap),
            SizedBox(
              width: metrics.amountWidth,
              child: Text(
                context.tr('AMT'),
                textAlign: TextAlign.right,
                style: _previewHeaderTextStyle(compact),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewParchiRow extends StatelessWidget {
  const _PreviewParchiRow({
    required this.number,
    required this.amount,
    required this.session,
    required this.compact,
    required this.metrics,
    this.isJackpot = false,
    this.isBazarSangam = false,
    this.isFamily = false,
    this.isCpJodi = false,
    this.isCommon = false,
    this.isSimpleJodi = false,
    this.isMotorPana = false,
    this.jackpotEntries = const [],
    this.showMainEntry = true,
  });

  final String number;
  final String amount;
  final String session;
  final bool compact;
  final _PreviewColumnMetrics metrics;
  final bool isJackpot;
  final bool isBazarSangam;
  final bool isFamily;
  final bool isCpJodi;
  final bool isCommon;
  final bool isSimpleJodi;
  final bool isMotorPana;
  final List<_JackpotLine> jackpotEntries;
  final bool showMainEntry;

  @override
  Widget build(BuildContext context) {
    final formattedNumber = _formatPreviewParchiNumber(
      number: number,
      session: session,
      isFamily: isFamily,
      isCpJodi: isCpJodi,
      isCommon: isCommon,
      isSimpleJodi: isSimpleJodi,
    );

    final visibleJackpotEntries = isJackpot
        ? jackpotEntries.where(
            (entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty,
          )
        : const Iterable<_JackpotLine>.empty();
    final topLabel = !showMainEntry
        ? null
        : isBazarSangam
            ? 'BAZAR'
            : isMotorPana
                ? 'MP'
                : null;
    final numberParts = NumberDisplayParts.fromDisplay(formattedNumber);
    final numberTextStyle = _previewNumberTextStyle(compact);
    final labelTextStyle = _previewLabelTextStyle(compact);
    final amountTextStyle = _previewAmountTextStyle(compact);
    final jackpotTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: compact ? 9 : 11,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
    );
    final jackpotArrowStyle = jackpotTextStyle.copyWith(
      fontSize: compact ? 13 : 16,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(7, compact ? 3 : 4, 7, compact ? 3 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topLabel != null)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 2 : 3),
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: metrics.totalWidth,
                  child: Text(
                    context.trMaybe(topLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelTextStyle,
                  ),
                ),
              ),
            ),
          if (showMainEntry)
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: metrics.numberWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text.rich(
                        _previewNumberSpan(
                          numberParts,
                          numberTextStyle,
                          labelTextStyle,
                        ),
                        maxLines: 1,
                        textWidthBasis: TextWidthBasis.longestLine,
                        style: numberTextStyle,
                      ),
                    ),
                  ),
                  SizedBox(width: metrics.gap),
                  SizedBox(
                    width: metrics.amountWidth,
                    child: Text(
                      AppLocalizations.localizeDigits(amount),
                      textAlign: TextAlign.right,
                      style: amountTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          for (final entry in visibleJackpotEntries)
            Padding(
              padding: EdgeInsets.only(top: compact ? 2 : 3),
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: metrics.numberWidth,
                      child: AlignedJackpotMarker(
                        parentText: formattedNumber,
                        childText: AppLocalizations.localizeDigits(
                          '${entry.number} >',
                        ),
                        parentStyle: numberTextStyle,
                        arrowStyle: jackpotArrowStyle,
                        childStyle: jackpotTextStyle,
                      ),
                    ),
                    SizedBox(width: metrics.gap),
                    SizedBox(
                      width: metrics.amountWidth,
                      child: Text(
                        AppLocalizations.localizeDigits(entry.amount),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: const Color(0xFF111820),
                          fontSize: compact ? 9 : 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewRule extends StatelessWidget {
  const _PreviewRule();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: const Color(0xFF111820));
  }
}

String _previewMarketTitle(String marketSession) {
  final title = marketSession.split(' - ').first.trim();
  return (title.isEmpty ? '-' : title).toUpperCase();
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.totalBets,
    required this.totalAmount,
    required this.isOtc,
    required this.marketSession,
  });

  final int totalBets;
  final num totalAmount;
  final bool isOtc;
  final String marketSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewEntryPageState._line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          _TotalTile(
            icon: Icons.shopping_bag_outlined,
            title: 'TOTAL BETS',
            value: AppLocalizations.localizeDigits('$totalBets'),
          ),
          const VerticalDivider(width: 1),
          _TotalTile(
            icon: Icons.currency_rupee,
            title: 'TOTAL AMOUNT',
            value: AppLocalizations.localizeDigits(
              '$_rs ${_formatAmount(totalAmount)}${isOtc ? ' OTC' : ''}',
            ),
            valueColor: _NewEntryPageState._green,
          ),
          const VerticalDivider(width: 1),
          _TotalTile(
            title: 'SELECTED MARKET',
            value: marketSession,
            valueColor: _NewEntryPageState._green,
          ),
        ],
      ),
    );
  }
}

class _MobileTotalsBar extends StatelessWidget {
  const _MobileTotalsBar({
    required this.totalBets,
    required this.totalAmount,
    required this.isOtc,
    required this.marketSession,
  });

  final int totalBets;
  final num totalAmount;
  final bool isOtc;
  final String marketSession;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MobileTotalTile(
            title: 'TOTAL BETS',
            value: AppLocalizations.localizeDigits('$totalBets'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MobileTotalTile(
            title: 'TOTAL AMOUNT',
            value: AppLocalizations.localizeDigits(
              '$_rs ${_formatAmount(totalAmount)}${isOtc ? ' OTC' : ''}',
            ),
            valueColor: _NewEntryPageState._green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MobileTotalTile(
            title: 'MKT & SESSION',
            value: marketSession,
            valueColor: _NewEntryPageState._green,
          ),
        ),
      ],
    );
  }
}

class _MobileTotalTile extends StatelessWidget {
  const _MobileTotalTile({
    required this.title,
    required this.value,
    this.valueColor = Colors.black,
  });

  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewEntryPageState._line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.trMaybe(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.title,
    required this.value,
    this.icon,
    this.valueColor = Colors.black,
  });

  final IconData? icon;
  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _NewEntryPageState._blue, size: 20),
                const SizedBox(width: 14),
              ],
              Text(
                context.trMaybe(title),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onClear,
    required this.onSaveAndPrint,
    required this.canSave,
    required this.compact,
    required this.isLoading,
  });

  final VoidCallback onClear;
  final VoidCallback onSaveAndPrint;
  final bool canSave;
  final bool compact;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'CLEAR ALL',
              icon: Icons.delete_outline,
              background: Colors.white,
              foreground: _NewEntryPageState._red,
              onPressed: onClear,
              compact: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: isLoading ? 'SAVING...' : 'PRINT RECEIPT (F6)',
              icon: Icons.print_outlined,
              background: _NewEntryPageState._green,
              foreground: Colors.white,
              onPressed: !isLoading ? onSaveAndPrint : null,
              compact: true,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'CLEAR ALL',
            icon: Icons.delete_outline,
            background: Colors.white,
            foreground: _NewEntryPageState._red,
            onPressed: onClear,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _ActionButton(
            label: 'PRINT RECEIPT (F6)',
            icon: Icons.print_outlined,
            background: _NewEntryPageState._green,
            foreground: Colors.white,
            onPressed: !isLoading ? onSaveAndPrint : null,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 74 : 58,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: compact ? 24 : 26),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            context.trMaybe(label),
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : 1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor:
              onPressed == null ? const Color(0xFFE5E7EB) : background,
          foregroundColor:
              onPressed == null ? const Color(0xFF6B7280) : foreground,
          side: BorderSide(
            color: background == Colors.white
                ? _NewEntryPageState._line
                : background,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: TextStyle(
            fontSize: compact ? 11 : 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FF),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: _NewEntryPageState._blue, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(
                'Note : Please check all entries before saving. Once saved, a receipt will be generated and can be printed.',
              ),
              style: const TextStyle(color: _NewEntryPageState._blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtcToggleButton extends StatelessWidget {
  const _OtcToggleButton({
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const color = _NewEntryPageState._red;
    return Tooltip(
      message: enabled
          ? 'OTC'
          : context.tr('OTC not allowed in Close or with Bazar'),
      child: SizedBox(
        width: 64,
        height: 28,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? color : Colors.white,
            foregroundColor: selected ? Colors.white : color,
            disabledForegroundColor: Colors.black38,
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: enabled ? color : _NewEntryPageState._line,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          child: const Text('OTC'),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _NewEntryPageState._blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.flex, required this.style});

  final String text;
  final int flex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        context.trMaybe(text),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell(this.child, {required this.flex});

  final Widget child;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Center(child: child),
    );
  }
}

class _ReceiptBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF939AA3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 8.0;
    const depth = 3.0;

    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, depth), Offset(x + step / 2, 0), paint);
      canvas.drawLine(
        Offset(x + step / 2, 0),
        Offset(x + step, depth),
        paint,
      );
      canvas.drawLine(
        Offset(x, size.height - depth),
        Offset(x + step / 2, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x + step / 2, size.height),
        Offset(x + step, size.height - depth),
        paint,
      );
    }
    canvas.drawLine(
        const Offset(0, depth), Offset(0, size.height - depth), paint);
    canvas.drawLine(
      Offset(size.width, depth),
      Offset(size.width, size.height - depth),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _rs = '\u20B9';
