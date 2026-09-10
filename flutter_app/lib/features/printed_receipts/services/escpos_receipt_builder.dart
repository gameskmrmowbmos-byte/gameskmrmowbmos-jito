import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

const _receiptPaperSize = PaperSize.mm58;
const _receiptCharsPerLine = 32;
const _receiptColumnGap = 3;

class EscPosReceiptBuilder {
  Future<List<int>> buildReceipt(
    ReceiptDetail detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_receiptPaperSize, profile);
    final receipt = detail.receipt;
    final bytes = <int>[];
    final centeredBold = const PosStyles(align: PosAlign.center, bold: true);
    final parchi = canonicalParchiNumber(
      overrideParchiNo ?? receipt.receiptNumber,
    );
    final columns = _ReceiptColumns.fromDetail(detail);
    final createdAt = receipt.createdAt ?? receipt.date ?? DateTime.now();

    bytes.addAll(generator.text(
      _headerLine(
        AppLocalizations.trCurrent('PARCHI NO. ').trim(),
        DateFormat('dd/MM/yyyy').format(createdAt),
      ),
      styles: centeredBold,
    ));
    bytes.addAll(generator.text(
      _headerLine(
        AppLocalizations.localizeDigits(parchi),
        DateFormat('hh:mm a').format(createdAt),
      ),
      styles: centeredBold,
    ));
    bytes.addAll(generator.text(
      _fixedWidth(
        AppLocalizations.trCurrent(receipt.session.trim().toUpperCase()),
      ),
      styles: centeredBold,
    ));
    if (ownerName?.trim().isNotEmpty == true) {
      bytes.addAll(generator.text(
        ownerName!.trim().toUpperCase(),
        styles: centeredBold,
      ));
    }

    final suppliedMarket = marketName?.trim();
    final storedMarket = receipt.market?.name.trim();
    final market = suppliedMarket?.isNotEmpty == true
        ? suppliedMarket!
        : storedMarket?.isNotEmpty == true
            ? storedMarket!
            : '-';
    bytes.addAll(generator.text(
      '${AppLocalizations.localizeMarketName(market.toUpperCase())} - '
      '${AppLocalizations.trCurrent(receipt.session.trim().toUpperCase())}',
      styles: centeredBold,
    ));
    _addRule(generator, bytes);
    _addCompactRow(
      generator,
      bytes,
      columns,
      AppLocalizations.trCurrent('NUMBER'),
      AppLocalizations.trCurrent('AMT'),
    );

    for (final item in detail.consolidatedItems) {
      if (item.isBazarSangam) {
        _addCompactLabel(generator, bytes, columns, 'BAZAR');
      } else if (item.isMotorPana) {
        _addCompactLabel(generator, bytes, columns, 'MP');
      }
      _addCompactRow(
        generator,
        bytes,
        columns,
        AppLocalizations.localizeDigits(
          formatParchiNumber(item, item.sessionOverride ?? receipt.session),
        ),
        AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
      );
      for (final jackpot in item.jackpotEntries) {
        _addCompactRow(
          generator,
          bytes,
          columns,
          AppLocalizations.localizeDigits('->${jackpot.number} >'),
          AppLocalizations.localizeDigits(jackpot.amount),
        );
      }
    }

    if (receipt.isOtc) {
      bytes.addAll(generator.text('OTC', styles: centeredBold));
    }
    _addRule(generator, bytes);
    _addCompactRow(
      generator,
      bytes,
      columns,
      AppLocalizations.trCurrent('TOTAL'),
      AppLocalizations.localizeDigits(_formatAmount(receipt.totalAmount)),
    );
    _addRule(generator, bytes);
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> buildTestPrint(String printerName) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_receiptPaperSize, profile);
    return [
      ...generator.text(
        'TEST PRINT',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...generator.text(
        printerName,
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...generator.feed(1),
      ...generator.cut(),
    ];
  }
}

void _addCompactLabel(
  Generator generator,
  List<int> bytes,
  _ReceiptColumns columns,
  String label,
) {
  bytes.addAll(generator.text(
    columns.label(label),
    styles: const PosStyles(align: PosAlign.center, bold: true),
  ));
}

void _addCompactRow(
  Generator generator,
  List<int> bytes,
  _ReceiptColumns columns,
  String number,
  String amount,
) {
  bytes.addAll(generator.text(
    columns.row(number, amount),
    styles: const PosStyles(align: PosAlign.center, bold: true),
  ));
}

void _addRule(Generator generator, List<int> bytes) {
  bytes.addAll(generator.text(
    '-' * _receiptCharsPerLine,
    styles: const PosStyles(align: PosAlign.center),
  ));
}

String _headerLine(String left, String right) {
  final availableLeft = _receiptCharsPerLine - right.length - 2;
  final fittedLeft = _fit(left, availableLeft);
  final gap = _receiptCharsPerLine - fittedLeft.length - right.length;
  return '$fittedLeft${' ' * gap}$right';
}

String _fixedWidth(String value) => _fit(value, _receiptCharsPerLine);

class _ReceiptColumns {
  const _ReceiptColumns({
    required this.numberWidth,
    required this.amountWidth,
  });

  final int numberWidth;
  final int amountWidth;

  factory _ReceiptColumns.fromDetail(ReceiptDetail detail) {
    final receipt = detail.receipt;
    var numberWidth = AppLocalizations.trCurrent('NUMBER').length;
    var amountWidth = AppLocalizations.trCurrent('AMT').length;

    void include(String number, String amount) {
      if (number.length > numberWidth) numberWidth = number.length;
      if (amount.length > amountWidth) amountWidth = amount.length;
    }

    include(
      AppLocalizations.trCurrent('TOTAL'),
      AppLocalizations.localizeDigits(_formatAmount(receipt.totalAmount)),
    );
    for (final item in detail.consolidatedItems) {
      include(
        AppLocalizations.localizeDigits(
          formatParchiNumber(item, item.sessionOverride ?? receipt.session),
        ),
        AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
      );
      for (final jackpot in item.jackpotEntries) {
        include(
          AppLocalizations.localizeDigits('->${jackpot.number} >'),
          AppLocalizations.localizeDigits(jackpot.amount),
        );
      }
    }

    final availableWidth = _receiptCharsPerLine - _receiptColumnGap;
    if (amountWidth >= availableWidth) amountWidth = availableWidth - 1;
    final maxNumberWidth = availableWidth - amountWidth;
    if (numberWidth > maxNumberWidth) numberWidth = maxNumberWidth;
    return _ReceiptColumns(
      numberWidth: numberWidth < 1 ? 1 : numberWidth,
      amountWidth: amountWidth,
    );
  }

  String row(String number, String amount) {
    return '${_fit(number, numberWidth)}'
        '${' ' * _receiptColumnGap}'
        '${_fit(amount, amountWidth, alignRight: true)}';
  }

  String label(String value) {
    return '${_fit(value, numberWidth)}'
        '${' ' * (_receiptColumnGap + amountWidth)}';
  }
}

String _fit(String value, int width, {bool alignRight = false}) {
  if (width <= 0) return '';
  final trimmed = value.trim();
  final clipped = trimmed.length <= width ? trimmed : trimmed.substring(0, width);
  final padding = ' ' * (width - clipped.length);
  return alignRight ? '$padding$clipped' : '$clipped$padding';
}

String _formatAmount(num amount) {
  return amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
