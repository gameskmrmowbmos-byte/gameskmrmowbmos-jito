class ShareRecordItem {
  const ShareRecordItem({
    required this.id,
    required this.type,
    required this.number,
    required this.amount,
    this.betType = '',
    this.betSubtype = '',
    this.isJackpot = false,
    this.isBazarSangam = false,
    this.isFamily = false,
    this.isCpJodi = false,
    this.isCommon = false,
    this.displayAmount,
    this.jackpotEntries = const [],
    this.showMainEntry = true,
  });

  final String id;
  final String type;
  final String number;
  final num amount;
  final String betType;
  final String betSubtype;
  final bool isJackpot;
  final bool isBazarSangam;
  final bool isFamily;
  final bool isCpJodi;
  final bool isCommon;
  final String? displayAmount;
  final List<ShareRecordJackpotEntry> jackpotEntries;
  final bool showMainEntry;

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

  bool get isMotorPana =>
      _isMotorPanaCode(type) ||
      _isMotorPanaCode(betType) ||
      _isMotorPanaCode(betSubtype);

  factory ShareRecordItem.fromJson(Map<String, dynamic> json) {
    return ShareRecordItem(
      id: _stringValue(json['_id'] ?? json['id']),
      type: _stringValue(json['type']),
      number: _stringValue(json['number']),
      amount: _numValue(json['amount']),
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
    );
  }

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
    return '$familyNumber F';
  }

  ShareRecordItem copyForParchi({
    required bool showMainEntry,
    required List<ShareRecordJackpotEntry> jackpotEntries,
    required num amount,
    String? displayAmount,
  }) {
    return ShareRecordItem(
      id: id,
      type: type,
      number: number,
      amount: amount,
      betType: betType,
      betSubtype: betSubtype,
      isJackpot: isJackpot,
      isBazarSangam: isBazarSangam,
      isFamily: isFamily,
      isCpJodi: isCpJodi,
      displayAmount: displayAmount,
      jackpotEntries: jackpotEntries,
      showMainEntry: showMainEntry,
    );
  }
}

class ShareRecordJackpotEntry {
  const ShareRecordJackpotEntry({required this.number, required this.amount});

  final String number;
  final String amount;
}

class ShareRecordMarket {
  const ShareRecordMarket({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  factory ShareRecordMarket.fromJson(Map<String, dynamic> json) {
    return ShareRecordMarket(
      id: _stringValue(json['_id'] ?? json['id']),
      name: _stringValue(json['name'], fallback: 'ALL MARKETS'),
      code: _stringValue(json['code']),
    );
  }
}

class ShareRecordOperator {
  const ShareRecordOperator({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory ShareRecordOperator.fromJson(Map<String, dynamic> json) {
    return ShareRecordOperator(
      id: _stringValue(json['_id'] ?? json['id']),
      name: _stringValue(json['fullName'] ?? json['username'] ?? json['name'],
          fallback: 'Operator 01'),
    );
  }
}

class ShareRecordEntry {
  const ShareRecordEntry({
    required this.receiptId,
    required this.receiptNumber,
    this.customerName,
    this.customerMobile,
    required this.market,
    required this.session,
    this.isOtc = false,
    required this.operator,
    required this.createdAt,
    required this.date,
    required this.totalAmount,
    required this.totalItems,
    required this.items,
  });

  final String receiptId;
  final String receiptNumber;
  final String? customerName;
  final String? customerMobile;
  final ShareRecordMarket market;
  final String session;
  final bool isOtc;
  final ShareRecordOperator operator;
  final DateTime? createdAt;
  final DateTime? date;
  final num totalAmount;
  final int totalItems;
  final List<ShareRecordItem> items;

  factory ShareRecordEntry.fromJson(Map<String, dynamic> json) {
    final marketMap = _objectValue(json['market']);
    final operatorMap = _objectValue(json['operator']);

    return ShareRecordEntry(
      receiptId: _stringValue(json['receiptId'] ?? json['_id']),
      receiptNumber: _stringValue(json['receiptNumber']),
      customerName: _nullableString(json['customerName']),
      customerMobile: _nullableString(json['customerMobile']),
      market: marketMap != null
          ? ShareRecordMarket.fromJson(marketMap)
          : const ShareRecordMarket(id: '', name: 'ALL MARKETS', code: ''),
      session: _stringValue(json['session'], fallback: 'OPEN'),
      isOtc: json['isOtc'] == true,
      operator: operatorMap != null
          ? ShareRecordOperator.fromJson(operatorMap)
          : const ShareRecordOperator(id: '', name: 'Operator 01'),
      createdAt: _dateValue(json['createdAt']),
      date: _dateValue(json['date']),
      totalAmount: _numValue(json['totalAmount']),
      totalItems: _intValue(json['totalItems']),
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShareRecordItem.fromJson)
          .toList(),
    );
  }

  String get totalAmountText => _formatAmount(totalAmount);
}

class ShareRecordSummary {
  const ShareRecordSummary({
    required this.totalReceipts,
    required this.totalItems,
    required this.totalAmount,
  });

  final int totalReceipts;
  final int totalItems;
  final num totalAmount;

  factory ShareRecordSummary.fromJson(Map<String, dynamic> json) {
    return ShareRecordSummary(
      totalReceipts: _intValue(json['totalReceipts']),
      totalItems: _intValue(json['totalItems']),
      totalAmount: _numValue(json['totalAmount']),
    );
  }

  String get totalAmountText => _formatAmount(totalAmount);
}

class ShareRecordResponse {
  const ShareRecordResponse({
    required this.summary,
    required this.records,
  });

  final ShareRecordSummary summary;
  final List<ShareRecordEntry> records;

  factory ShareRecordResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final summaryMap = data['summary'] as Map<String, dynamic>? ?? const {};
    final recordsList = (data['records'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShareRecordEntry.fromJson)
        .toList();

    return ShareRecordResponse(
      summary: ShareRecordSummary.fromJson(summaryMap),
      records: recordsList,
    );
  }
}

class RecordBoxData {
  const RecordBoxData({
    required this.sequenceNumber,
    required this.receiptId,
    required this.receiptNumber,
    this.customerName,
    required this.marketName,
    required this.session,
    this.isOtc = false,
    this.createdAt,
    this.date,
    required this.totalReceiptAmount,
    required this.partIndex,
    required this.totalParts,
    required this.boxSubtotal,
    required this.items,
  });

  final int sequenceNumber;
  final String receiptId;
  final String receiptNumber;
  final String? customerName;
  final String marketName;
  final String session;
  final bool isOtc;
  final DateTime? createdAt;
  final DateTime? date;
  final num totalReceiptAmount;
  final int partIndex;
  final int totalParts;
  final List<ShareRecordItem> items;
  final num boxSubtotal;

  bool get isContinuation => partIndex > 1;

  String get boxSubtotalText => _formatAmount(boxSubtotal);

  String get displayName {
    if (customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    if (receiptNumber.trim().isNotEmpty) {
      return receiptNumber.trim();
    }
    return 'Record $sequenceNumber';
  }
}

class A4RecordPageData {
  const A4RecordPageData({
    required this.pageIndex,
    required this.totalPages,
    required this.dateStr,
    required this.marketName,
    required this.sessionName,
    required this.totalPeople,
    required this.totalBets,
    required this.totalAmount,
    required this.operatorName,
    required this.timeStr,
    required this.boxes,
  });

  final int pageIndex;
  final int totalPages;
  final String dateStr;
  final String marketName;
  final String sessionName;
  final int totalPeople;
  final int totalBets;
  final num totalAmount;
  final String operatorName;
  final String timeStr;
  final List<RecordBoxData> boxes;

  int get pageNumber => pageIndex + 1;

  String get totalAmountText => _formatAmount(totalAmount);
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<ShareRecordJackpotEntry> _jackpotEntries(Object? components) {
  final map = _objectValue(components);
  final entries = map?['jackpotEntries'];
  if (entries is List) {
    return entries
        .map((value) {
          final entry = _objectValue(value);
          return ShareRecordJackpotEntry(
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
      .map((value) => ShareRecordJackpotEntry(
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
