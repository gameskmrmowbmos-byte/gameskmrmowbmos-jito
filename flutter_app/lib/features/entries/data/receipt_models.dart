class ReceiptMarket {
  const ReceiptMarket({
    required this.id,
    required this.name,
    required this.code,
    this.gameConfigCode = '',
    this.openingTime = '',
    this.closingTime = '',
    this.resultTime = '',
    this.isActive = true,
    this.displayOrder = 0,
    this.availabilityState = '',
    this.availabilityMessage = '',
    this.opensAt = '',
    this.closesAt = '',
    this.canEnter = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String code;
  final String gameConfigCode;
  final String openingTime;
  final String closingTime;
  final String resultTime;
  final bool isActive;
  final int displayOrder;
  final String availabilityState;
  final String availabilityMessage;
  final String opensAt;
  final String closesAt;
  final bool canEnter;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ReceiptMarket.fromJson(Map<String, dynamic> json) {
    return ReceiptMarket(
      id: _stringValue(json['_id'] ?? json['id']),
      name: _stringValue(json['name']),
      code: _stringValue(json['code']),
      gameConfigCode: _stringValue(json['gameConfigCode']),
      openingTime: _stringValue(json['openingTime']),
      closingTime: _stringValue(json['closingTime']),
      resultTime: _stringValue(json['resultTime']),
      isActive: json['isActive'] != false,
      displayOrder: _intValue(json['displayOrder']),
      availabilityState:
          _stringValue(_objectValue(json['availability'])?['state']),
      availabilityMessage:
          _stringValue(_objectValue(json['availability'])?['message']),
      opensAt: _stringValue(_objectValue(json['availability'])?['opensAt']),
      closesAt: _stringValue(_objectValue(json['availability'])?['closesAt']),
      canEnter: json['isActive'] != false,
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }
}

class ReceiptOperator {
  const ReceiptOperator({required this.id, required this.name});

  final String id;
  final String name;

  factory ReceiptOperator.fromJson(Map<String, dynamic> json) {
    return ReceiptOperator(
      id: _stringValue(json['_id'] ?? json['id']),
      name: _stringValue(json['fullName'] ?? json['username']),
    );
  }
}

class ReceiptSummary {
  const ReceiptSummary({
    required this.id,
    required this.receiptNumber,
    required this.date,
    required this.market,
    required this.session,
    required this.totalAmount,
    required this.totalItems,
    required this.operator,
    required this.status,
    required this.printStatus,
    this.isOtc = false,
    this.customerName,
    this.customerMobile,
    this.notes,
    this.createdAt,
    this.cancelledAt,
    this.cancellationReason,
    this.reprintCount = 0,
  });

  final String id;
  final String receiptNumber;
  final DateTime? date;
  final ReceiptMarket? market;
  final String session;
  final num totalAmount;
  final int totalItems;
  final ReceiptOperator? operator;
  final String status;
  final String printStatus;
  final bool isOtc;
  final String? customerName;
  final String? customerMobile;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final int reprintCount;

  bool get isCancelled => status.toLowerCase() == 'cancelled';

  factory ReceiptSummary.fromJson(Map<String, dynamic> json) {
    return ReceiptSummary(
      id: _stringValue(json['_id'] ?? json['id']),
      receiptNumber: _stringValue(json['receiptNumber']),
      date: _dateValue(json['date']),
      market: _objectValue(json['market']) == null
          ? null
          : ReceiptMarket.fromJson(_objectValue(json['market'])!),
      session: _stringValue(json['session']),
      totalAmount: _numValue(json['totalAmount']),
      totalItems: _intValue(json['totalItems']),
      operator: _objectValue(json['operator']) == null
          ? null
          : ReceiptOperator.fromJson(_objectValue(json['operator'])!),
      status: _stringValue(json['status'], fallback: 'Active'),
      printStatus: _stringValue(json['printStatus'], fallback: 'Not Printed'),
      isOtc: json['isOtc'] == true,
      customerName: _nullableString(json['customerName']),
      customerMobile: _nullableString(json['customerMobile']),
      notes: _nullableString(json['notes']),
      createdAt: _dateValue(json['createdAt']),
      cancelledAt: _dateValue(json['cancelledAt']),
      cancellationReason: _nullableString(json['cancellationReason']),
      reprintCount: _intValue(
        json['reprintCount'] ?? json['duplicatePrintCount'],
      ),
    );
  }

  String get totalAmountText => _formatAmount(totalAmount);
}

class NumberDisplayParts {
  const NumberDisplayParts({
    required this.beforeSuffix,
    required this.suffix,
    this.leadingArrow = '',
    this.trailingArrow = '',
  });

  final String beforeSuffix;
  final String suffix;
  final String leadingArrow;
  final String trailingArrow;

  static NumberDisplayParts fromDisplay(String rawText) {
    final trimmed = rawText.trim();
    var value = trimmed;
    var leadingArrow = '';
    var trailingArrow = '';

    if (value.startsWith('>')) {
      leadingArrow = '>';
      value = value.substring(1).trimLeft();
    }

    if (value.endsWith('>')) {
      trailingArrow = '>';
      value = value.substring(0, value.length - 1).trimRight();
    }

    const suffixLabels = {
      'CP',
      'SP',
      'DP',
      'CUT P',
      'F',
      'BAZAR',
      'MP',
      'COMMON',
      'CM',
    };
    String displaySuffix(String suffix) => suffix == 'CM' ? 'COMMON' : suffix;
    final suffixOnly = value.trim().toUpperCase();
    if (suffixLabels.contains(suffixOnly)) {
      return NumberDisplayParts(
        beforeSuffix: '',
        suffix: displaySuffix(suffixOnly),
        leadingArrow: leadingArrow,
        trailingArrow: trailingArrow,
      );
    }

    final match = RegExp(
      r'^(.*?)(\s*(?:COMMON|BAZAR|CUT\s+P|CP|SP|DP|MP|CM|F))$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      return NumberDisplayParts(
        beforeSuffix: value.trim(),
        suffix: '',
        leadingArrow: leadingArrow,
        trailingArrow: trailingArrow,
      );
    }

    return NumberDisplayParts(
      beforeSuffix: match.group(1)?.trim() ?? '',
      suffix: displaySuffix(match.group(2)?.trim().toUpperCase() ?? ''),
      leadingArrow: leadingArrow,
      trailingArrow: trailingArrow,
    );
  }
}

class ReceiptItemModel {
  const ReceiptItemModel({
    required this.id,
    required this.type,
    required this.number,
    required this.amount,
    this.mode = '',
    this.betType = '',
    this.betSubtype = '',
    this.isJackpot = false,
    this.isBazarSangam = false,
    this.isFamily = false,
    this.isCpJodi = false,
    this.isCommon = false,
    this.displayAmount,
    this.jackpotEntries = const [],
    this.sessionOverride,
  });

  final String id;
  final String type;
  final String number;
  final num amount;
  final String mode;
  final String betType;
  final String betSubtype;
  final bool isJackpot;
  final bool isBazarSangam;
  final bool isFamily;
  final bool isCpJodi;
  final bool isCommon;
  final String? displayAmount;
  final List<JackpotEntryModel> jackpotEntries;
  final String? sessionOverride;

  String get amountText => _formatAmount(amount);

  String get effectiveDisplayAmount => displayAmount ?? amountText;

  String get displayNumber {
    if (isCommon) {
      final commonNumber = number
          .trim()
          .replaceFirst(RegExp(r'^[cC][mM]\s*'), '')
          .replaceFirst(RegExp(r'^\s*[cC][oO][mM][mM][oO][nN]\s*'), '')
          .replaceFirst(RegExp(r'\s*[cC][mM]$'), '')
          .replaceFirst(RegExp(r'\s*[cC][oO][mM][mM][oO][nN]$'), '')
          .trim();
      return '$commonNumber COMMON';
    }
    if (isCpJodi) {
      final value = number.trim();
      final jodiNumber = value
          .replaceFirst(RegExp(r'^[cC][pP]\s*'), '')
          .replaceFirst(RegExp(r'\s*[cC][pP]$'), '');
      return '$jodiNumber CP';
    }
    if (!isFamily) return number;
    final value = number.trim();
    final familyNumber = value
        .replaceFirst(RegExp(r'^[fF]\s*'), '')
        .replaceFirst(RegExp(r'\s*[fF]$'), '');
    return '${familyNumber}F';
  }

  bool get isMotorPana =>
      _isMotorPanaCode(type) ||
      _isMotorPanaCode(betType) ||
      _isMotorPanaCode(betSubtype);

  bool get isSimpleJodi {
    if (isCpJodi) return false;
    final normalizedType = _normalizedGameCode(type);
    final normalizedBetType = _normalizedGameCode(betType);
    final normalizedSubtype = _normalizedGameCode(betSubtype);
    return normalizedType == 'JODI' &&
        (normalizedBetType.isEmpty || normalizedBetType == 'JODI') &&
        normalizedSubtype.isEmpty;
  }

  String get displayType {
    final dt = betSubtype.isNotEmpty ? betSubtype : type;
    final normalized = _normalizedGameCode(dt);
    if (isCpJodi) return 'CP';
    if (isCommon || normalized == 'COMMON') return 'Common';
    if (isFamily || normalized == 'FAMILY') return 'Family';
    if (_isMotorPanaCode(dt)) return 'MotorPana';
    if (normalized == 'DP_MOTOR') return 'DP Motor';
    return dt;
  }

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      id: _stringValue(json['_id'] ?? json['id']),
      type: _stringValue(json['type']),
      number: _stringValue(json['number']),
      amount: _numValue(json['amount']),
      mode: _stringValue(json['mode']),
      betType: _stringValue(json['betType']),
      betSubtype: _stringValue(json['betSubtype']),
      isJackpot: json['isJackpot'] == true,
      isBazarSangam: _isBazarSangam(json['components']),
      isFamily: _isFamily(json['components']),
      isCpJodi: _isCpJodi(
        json['components'],
        type: _stringValue(json['type']),
        betType: _stringValue(json['betType']),
        betSubtype: _stringValue(json['betSubtype']),
      ),
      isCommon: _isCommon(
        json['components'],
        type: _stringValue(json['type']),
        betType: _stringValue(json['betType']),
        betSubtype: _stringValue(json['betSubtype']),
      ),
      displayAmount: _displayAmount(json['components']),
      jackpotEntries: _jackpotEntries(json['components']),
      sessionOverride: json['sessionOverride'] as String?,
    );
  }
}

String canonicalParchiNumber(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String formatParchiNumber(ReceiptItemModel item, String session) {
  var formattedNumber =
      item.displayNumber.replaceAll('-', ' * ').replaceAll('*', ' * ');
  if (item.isCpJodi) {
    formattedNumber = formattedNumber.trim();
    if (session == 'Open') return '$formattedNumber >';
    if (session == 'Close') return '>$formattedNumber';
    return '$formattedNumber CP';
  }
  final hasFamilyMarker = RegExp(
    r'^(?:[fF]\s*\d{2,3}|\d{2,3}\s*[fF])$',
  ).hasMatch(formattedNumber.trim());
  if (item.isFamily || hasFamilyMarker) {
    final familyNumber = formattedNumber
        .replaceFirst(RegExp(r'^[fF]\s*'), '')
        .replaceFirst(RegExp(r'\s*[fF]$'), '')
        .trim();
    final familyDisplay = '${familyNumber}F';
    final isJodiFamily = RegExp(r'^\d{2}$').hasMatch(familyNumber);
    if (isJodiFamily) return familyDisplay;
    if (session == 'Open') return '$familyDisplay >';
    if (session == 'Close') return '> $familyDisplay';
    return familyDisplay;
  }
  if (item.isSimpleJodi) return formattedNumber.trim();
  if (session == 'Open') return '$formattedNumber >';
  if (session == 'Close') return '> $formattedNumber';
  return formattedNumber;
}

class JackpotEntryModel {
  const JackpotEntryModel({required this.number, required this.amount});

  final String number;
  final String amount;
}

class PrintLogModel {
  const PrintLogModel({
    required this.id,
    required this.printId,
    required this.printType,
    required this.printerName,
    required this.status,
    this.receipt,
    this.printNumber,
    this.printerType,
    this.paperSize,
    this.deviceId,
    this.operator,
    this.errorMessage,
    this.reprintReason,
    this.retryReason,
    this.printedAt,
    this.createdAt,
  });

  final String id;
  final String printId;
  final String printType;
  final String printerName;
  final String status;
  final ReceiptSummary? receipt;
  final int? printNumber;
  final String? printerType;
  final String? paperSize;
  final String? deviceId;
  final ReceiptOperator? operator;
  final String? errorMessage;
  final String? reprintReason;
  final String? retryReason;
  final DateTime? printedAt;
  final DateTime? createdAt;

  bool get isDuplicate => printType.toLowerCase() == 'duplicate';

  factory PrintLogModel.fromJson(Map<String, dynamic> json) {
    return PrintLogModel(
      id: _stringValue(json['_id'] ?? json['id']),
      printId: _stringValue(json['printId']),
      printType: _stringValue(json['printType']),
      printerName: _stringValue(json['printerName']),
      status: _stringValue(json['status'], fallback: 'Pending'),
      receipt: _objectValue(json['receipt']) == null
          ? null
          : ReceiptSummary.fromJson(_objectValue(json['receipt'])!),
      printNumber:
          json['printNumber'] == null ? null : _intValue(json['printNumber']),
      printerType: _nullableString(json['printerType']),
      paperSize: _nullableString(json['paperSize']),
      deviceId: _nullableString(json['deviceId']),
      operator: _objectValue(json['operator']) == null
          ? null
          : ReceiptOperator.fromJson(_objectValue(json['operator'])!),
      errorMessage: _nullableString(json['errorMessage']),
      reprintReason: _nullableString(json['reprintReason']),
      retryReason: _nullableString(json['retryReason']),
      printedAt: _dateValue(json['printedAt']),
      createdAt: _dateValue(json['createdAt']),
    );
  }
}

class ReceiptDetail {
  const ReceiptDetail({
    required this.receipt,
    required this.items,
    required this.printLogs,
    this.matchedPrintLog,
  });

  final ReceiptSummary receipt;
  final List<ReceiptItemModel> items;
  final List<PrintLogModel> printLogs;
  final PrintLogModel? matchedPrintLog;

  int get printCount =>
      printLogs.where((log) => log.status.toLowerCase() == 'success').length;

  bool get isDuplicateLookup => matchedPrintLog?.isDuplicate == true;

  List<PrintLogModel> get successfulReprintLogs => printLogs
      .where(
        (log) => log.isDuplicate && log.status.toLowerCase() == 'success',
      )
      .toList(growable: false);

  int get reprintCount {
    final count = successfulReprintLogs.length;
    return count == 0 ? receipt.reprintCount : count;
  }

  factory ReceiptDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return ReceiptDetail(
      receipt: ReceiptSummary.fromJson(
        data['receipt'] as Map<String, dynamic>? ?? const {},
      ),
      items: (data['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReceiptItemModel.fromJson)
          .toList(),
      printLogs: (data['printLogs'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PrintLogModel.fromJson)
          .toList(),
      matchedPrintLog: data['matchedPrintLog'] is Map<String, dynamic>
          ? PrintLogModel.fromJson(
              data['matchedPrintLog'] as Map<String, dynamic>)
          : null,
    );
  }

  List<ReceiptItemModel> get consolidatedItems {
    final consolidated = <ReceiptItemModel>[];
    final motorGroups = <String, num>{};
    final motorIds = <String, String>{};
    final pannaGroups = <String, num>{};
    final pannaIds = <String, String>{};

    for (final item in items) {
      final subtype = item.betSubtype.toUpperCase();
      if (subtype.startsWith('SP_MOTOR_')) {
        motorGroups[subtype] = (motorGroups[subtype] ?? 0) + item.amount;
        motorIds[subtype] = item.id;
      } else if (subtype.startsWith('SP_PANNA_') ||
          subtype.startsWith('DP_PANNA_')) {
        pannaGroups[subtype] = (pannaGroups[subtype] ?? 0) + item.amount;
        pannaIds[subtype] = item.id;
      } else {
        consolidated.add(item);
      }
    }

    for (final entry in motorGroups.entries) {
      final parts = entry.key.split(RegExp(r'[_ ]'));
      final motorDigits = parts.last;
      consolidated.add(ReceiptItemModel(
        id: motorIds[entry.key] ?? '',
        type: 'MotorPana',
        number: motorDigits,
        amount: entry.value,
        mode: 'Auto',
        betType: 'PANNA',
        betSubtype: entry.key,
      ));
    }

    for (final entry in pannaGroups.entries) {
      final parts = entry.key.split('_');
      final pannaType = parts[0];
      final digit = parts.last;
      consolidated.add(ReceiptItemModel(
        id: pannaIds[entry.key] ?? '',
        type: '$pannaType Panna',
        number: digit,
        amount: entry.value,
        mode: 'Auto',
        betType: 'PANNA',
        betSubtype: entry.key,
      ));
    }

    return consolidated;
  }
}

class ReceiptPageResult {
  const ReceiptPageResult({
    required this.receipts,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<ReceiptSummary> receipts;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<JackpotEntryModel> _jackpotEntries(Object? components) {
  final map = _objectValue(components);
  final entries = map?['jackpotEntries'];
  if (entries is List) {
    return entries
        .map((value) {
          final entry = _objectValue(value);
          return JackpotEntryModel(
            number: _stringValue(entry?['number']).trim(),
            amount: _stringValue(entry?['amount']).trim(),
          );
        })
        .where((entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty)
        .toList(growable: false);
  }

  final numbers = map?['jackpotNumbers'];
  if (numbers is! List) return const [];
  return numbers
      .map((value) => JackpotEntryModel(
            number: value.toString().trim(),
            amount: '',
          ))
      .where((entry) => entry.number.isNotEmpty)
      .toList(growable: false);
}

String _normalizedGameCode(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
}

bool _isMotorPanaCode(String value) {
  final normalized = _normalizedGameCode(value);
  return normalized == 'SP_MOTOR' ||
      normalized == 'MOTOR' ||
      normalized == 'MOTORPANA' ||
      normalized.startsWith('SP_MOTOR_');
}

bool _isBazarSangam(Object? components) {
  final map = _objectValue(components);
  return _truthyFlag(map?['bazar']) ||
      _truthyFlag(map?['bazarSangam']) ||
      _truthyFlag(map?['isBazar']);
}

bool _isFamily(Object? components) {
  final map = _objectValue(components);
  return _truthyFlag(map?['family']) || _truthyFlag(map?['isFamily']);
}

bool _isCpJodi(
  Object? components, {
  required String type,
  required String betType,
  required String betSubtype,
}) {
  final map = _objectValue(components);
  if (_truthyFlag(map?['cp']) ||
      _truthyFlag(map?['cpJodi']) ||
      _truthyFlag(map?['isCp'])) {
    return true;
  }
  final normalizedBetType = _normalizedGameCode(betType);
  return _normalizedGameCode(type) == 'JODI' &&
      (normalizedBetType.isEmpty || normalizedBetType == 'JODI') &&
      _normalizedGameCode(betSubtype) == 'CP';
}

bool _isCommon(
  Object? components, {
  required String type,
  required String betType,
  required String betSubtype,
}) {
  final map = _objectValue(components);
  if (_truthyFlag(map?['common']) ||
      _truthyFlag(map?['commonSingle']) ||
      _truthyFlag(map?['isCommon'])) {
    return true;
  }
  final normalizedBetType = _normalizedGameCode(betType);
  final normalizedSubtype = _normalizedGameCode(betSubtype);
  return _normalizedGameCode(type) == 'SINGLE' &&
      (normalizedBetType.isEmpty || normalizedBetType == 'SINGLE') &&
      (normalizedSubtype == 'COMMON' || normalizedSubtype == 'CM');
}

bool _truthyFlag(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes' || text == 'bz';
}

String? _displayAmount(Object? components) {
  final map = _objectValue(components);
  final text = map?['displayAmount']?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

num _numValue(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatAmount(num amount) {
  final text = amount.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateValue(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic>? _objectValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}
