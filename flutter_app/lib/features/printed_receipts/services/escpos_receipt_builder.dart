import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

const _receiptImageWidth = 372.0;
const _receiptTicketWidth = 338.0;
const _receiptTicketX = (_receiptImageWidth - _receiptTicketWidth) / 2;
const _receiptPaddingX = _receiptTicketX + 17.0;
const _receiptPaddingTop = 18.0;
const _receiptPaddingBottom = 22.0;
const _receiptContentWidth = _receiptTicketWidth - 34.0;
const _receiptTableMaxWidth = 286.0;
const _receiptTableGap = 34.0;
const _receiptRuleHeight = 3.0;
const _receiptInk = ui.Color(0xFF111820);
const _receiptWhite = ui.Color(0xFFFFFFFF);
const _receiptStrongTextShadow = <ui.Shadow>[
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0.45, 0), blurRadius: 0),
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0, 0.45), blurRadius: 0),
];

const _topLabelStyle = TextStyle(
  color: _receiptInk,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  height: 1.15,
);
const _topNumberStyle = TextStyle(
  color: _receiptInk,
  fontSize: 19,
  fontWeight: FontWeight.w900,
  height: 1.15,
);
const _sessionStyle = TextStyle(
  color: _receiptInk,
  fontSize: 15,
  fontWeight: FontWeight.w900,
  height: 1,
);
const _dateStyle = TextStyle(
  color: _receiptInk,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  height: 1.15,
);
const _marketStyle = TextStyle(
  color: _receiptInk,
  fontSize: 27,
  fontWeight: FontWeight.w900,
  height: 1.1,
);
const _ownerStyle = TextStyle(
  color: _receiptInk,
  fontSize: 19,
  fontWeight: FontWeight.w900,
  height: 1,
);
const _headerStyle = TextStyle(
  color: _receiptInk,
  fontSize: 20,
  fontWeight: FontWeight.w900,
  height: 1.1,
  shadows: _receiptStrongTextShadow,
);
const _entryStyle = TextStyle(
  color: _receiptInk,
  fontSize: 24,
  fontWeight: FontWeight.w900,
  height: 1,
  shadows: _receiptStrongTextShadow,
);
const _jackpotStyle = TextStyle(
  color: _receiptInk,
  fontSize: 22,
  fontWeight: FontWeight.w900,
  height: 1,
  shadows: _receiptStrongTextShadow,
);
const _totalStyle = TextStyle(
  color: _receiptInk,
  fontSize: 27,
  fontWeight: FontWeight.w900,
  height: 1.1,
  shadows: _receiptStrongTextShadow,
);

class EscPosReceiptBuilder {
  Future<List<int>> buildReceipt(
    ReceiptDetail detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final receipt = detail.receipt;
    final bytes = <int>[];
    final parchi = canonicalParchiNumber(
      overrideParchiNo ?? receipt.receiptNumber,
    );
    final createdAt = receipt.createdAt ?? DateTime.now();
    final session = AppLocalizations.trCurrent(_sessionLabel(receipt.session));
    final suppliedMarket = marketName?.trim();
    final storedMarket = receipt.market?.name.trim();
    final market = suppliedMarket?.isNotEmpty == true
        ? suppliedMarket!
        : storedMarket?.isNotEmpty == true
            ? storedMarket!
            : '-';
    final rows = _buildRows(detail.consolidatedItems, receipt.session);
    final total = detail.consolidatedItems.fold<num>(
          0,
          (sum, item) => sum + item.amount,
        ) *
        (receipt.isOtc ? 2 : 1);
    final totalText = AppLocalizations.localizeDigits(_formatAmount(total));

    final receiptImage = await _buildReceiptImage(
      parchi: parchi,
      createdAt: createdAt,
      session: session,
      market: AppLocalizations.localizeMarketName(market.toUpperCase()),
      ownerName: ownerName,
      rows: rows,
      totalText: totalText,
      isOtc: receipt.isOtc,
    );
    bytes.addAll(generator.imageRaster(receiptImage, align: PosAlign.center));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> buildTestPrint(String printerName) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    return [
      ...generator.text(
        'TEST PRINT',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...generator.text(
        printerName,
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...generator.feed(3),
      ...generator.cut(),
    ];
  }

  String _formatAmount(num amount) =>
      amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

class _EscPosReceiptRow {
  const _EscPosReceiptRow({
    required this.number,
    required this.amount,
    required this.showMainEntry,
    required this.jackpotEntries,
    this.topLabel,
  });

  final String number;
  final String amount;
  final bool showMainEntry;
  final List<_EscPosJackpotRow> jackpotEntries;
  final String? topLabel;
}

class _EscPosJackpotRow {
  const _EscPosJackpotRow({required this.number, required this.amount});

  final String number;
  final String amount;
}

class _ReceiptImageMetrics {
  const _ReceiptImageMetrics({
    required this.numberWidth,
    required this.amountWidth,
  });

  final double numberWidth;
  final double amountWidth;

  double get totalWidth => numberWidth + _receiptTableGap + amountWidth;
}

Future<image_lib.Image> _buildReceiptImage({
  required String parchi,
  required DateTime createdAt,
  required String session,
  required String market,
  required String? ownerName,
  required List<_EscPosReceiptRow> rows,
  required String totalText,
  required bool isOtc,
}) async {
  final metrics = _imageTableMetrics(rows, totalText);
  final height = _layoutReceiptImage(
    canvas: null,
    parchi: parchi,
    createdAt: createdAt,
    session: session,
    market: market,
    ownerName: ownerName,
    rows: rows,
    totalText: totalText,
    isOtc: isOtc,
    metrics: metrics,
  ).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  _layoutReceiptImage(
    canvas: canvas,
    parchi: parchi,
    createdAt: createdAt,
    session: session,
    market: market,
    ownerName: ownerName,
    rows: rows,
    totalText: totalText,
    isOtc: isOtc,
    metrics: metrics,
    height: height.toDouble(),
  );

  final picture = recorder.endRecording();
  final uiImage = await picture.toImage(_receiptImageWidth.round(), height);
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  uiImage.dispose();

  final pngBytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
  final image = image_lib.decodePng(pngBytes);
  if (image == null) {
    throw StateError('Receipt image could not be generated');
  }
  return image;
}

double _layoutReceiptImage({
  required ui.Canvas? canvas,
  required String parchi,
  required DateTime createdAt,
  required String session,
  required String market,
  required String? ownerName,
  required List<_EscPosReceiptRow> rows,
  required String totalText,
  required bool isOtc,
  required _ReceiptImageMetrics metrics,
  double? height,
}) {
  if (canvas != null) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _receiptImageWidth, height ?? 1),
      ui.Paint()..color = _receiptWhite,
    );
  }

  var y = _receiptPaddingTop;
  final rightTextWidth = 125.0;
  final leftWidth = _receiptContentWidth - rightTextWidth - 10;
  final dateText = AppLocalizations.localizeDigits(
    DateFormat('dd/MM/yyyy').format(createdAt),
  );
  final timeText = AppLocalizations.localizeDigits(
    DateFormat('hh:mm a').format(createdAt),
  );

  _paintText(
    canvas,
    AppLocalizations.trCurrent('PARCHI NO.'),
    _topLabelStyle,
    _receiptPaddingX,
    y,
    width: leftWidth,
    maxLines: 1,
  );
  _paintText(
    canvas,
    dateText,
    _dateStyle,
    _receiptImageWidth - _receiptPaddingX - rightTextWidth,
    y,
    width: rightTextWidth,
    textAlign: TextAlign.right,
  );
  y += 25;
  _paintText(
    canvas,
    AppLocalizations.localizeDigits(parchi),
    _topNumberStyle,
    _receiptPaddingX,
    y,
    width: leftWidth,
    maxLines: 1,
  );
  _paintText(
    canvas,
    timeText,
    _dateStyle,
    _receiptImageWidth - _receiptPaddingX - rightTextWidth,
    y,
    width: rightTextWidth,
    textAlign: TextAlign.right,
  );
  y += 25;
  _paintText(canvas, session.toUpperCase(), _sessionStyle, _receiptPaddingX, y);
  y += 39;

  final owner = ownerName?.trim() ?? '';
  if (owner.isNotEmpty) {
    y += _paintText(
      canvas,
      owner.toUpperCase(),
      _ownerStyle,
      _receiptPaddingX,
      y,
      width: _receiptContentWidth,
      textAlign: TextAlign.center,
    );
    y += 10;
  }

  y += _paintText(
    canvas,
    '$market - $session',
    _marketStyle,
    _receiptPaddingX,
    y,
    width: _receiptContentWidth,
    textAlign: TextAlign.center,
    maxLines: 2,
  );
  y += 17;
  _paintRule(canvas, y);
  y += _receiptRuleHeight + 17;

  final tableX = (_receiptImageWidth - metrics.totalWidth) / 2;
  _paintTableText(
    canvas,
    AppLocalizations.trCurrent('NUMBER'),
    _headerStyle,
    tableX,
    y,
    metrics.numberWidth,
  );
  _paintTableText(
    canvas,
    AppLocalizations.trCurrent('AMT'),
    _headerStyle,
    tableX + metrics.numberWidth + _receiptTableGap,
    y,
    metrics.amountWidth,
    textAlign: TextAlign.right,
  );
  y += 33;

  for (final row in rows) {
    if (row.topLabel != null) {
      y += _paintTableText(
        canvas,
        row.topLabel!,
        _entryStyle,
        tableX,
        y,
        metrics.totalWidth,
      );
      y += 9;
    }
    if (row.showMainEntry) {
      _paintTableText(
          canvas, row.number, _entryStyle, tableX, y, metrics.numberWidth);
      y += _paintTableText(
        canvas,
        row.amount,
        _entryStyle,
        tableX + metrics.numberWidth + _receiptTableGap,
        y,
        metrics.amountWidth,
        textAlign: TextAlign.right,
      );
      y += 10;
    }
    for (final jackpot in row.jackpotEntries) {
      _paintTableText(canvas, jackpot.number, _jackpotStyle, tableX, y,
          metrics.numberWidth);
      y += _paintTableText(
        canvas,
        jackpot.amount,
        _jackpotStyle,
        tableX + metrics.numberWidth + _receiptTableGap,
        y,
        metrics.amountWidth,
        textAlign: TextAlign.right,
      );
      y += 9;
    }
  }

  y += rows.isEmpty ? 50 : 18;
  if (isOtc) {
    y += _paintText(
      canvas,
      'OTC',
      _entryStyle,
      tableX,
      y,
      width: metrics.totalWidth,
      textAlign: TextAlign.center,
    );
    y += 10;
  }
  _paintRule(canvas, y);
  y += _receiptRuleHeight + 22;

  _paintTableText(
    canvas,
    AppLocalizations.trCurrent('TOTAL'),
    _totalStyle,
    tableX,
    y,
    metrics.numberWidth,
  );
  y += _paintTableText(
    canvas,
    totalText,
    _totalStyle,
    tableX + metrics.numberWidth + _receiptTableGap,
    y,
    metrics.amountWidth,
    textAlign: TextAlign.right,
  );
  y += 18;
  _paintRule(canvas, y);
  y += _receiptRuleHeight + _receiptPaddingBottom;

  return y;
}

_ReceiptImageMetrics _imageTableMetrics(
  List<_EscPosReceiptRow> rows,
  String totalText,
) {
  var numberWidth =
      _measureText(AppLocalizations.trCurrent('NUMBER'), _headerStyle);
  var amountWidth =
      _measureText(AppLocalizations.trCurrent('AMT'), _headerStyle);
  numberWidth = _maxDouble(
    numberWidth,
    _measureText(AppLocalizations.trCurrent('TOTAL'), _totalStyle),
  );
  amountWidth = _maxDouble(amountWidth, _measureText(totalText, _totalStyle));

  for (final row in rows) {
    if (row.topLabel != null) {
      numberWidth =
          _maxDouble(numberWidth, _measureText(row.topLabel!, _entryStyle));
    }
    if (row.showMainEntry) {
      numberWidth =
          _maxDouble(numberWidth, _measureText(row.number, _entryStyle));
      amountWidth =
          _maxDouble(amountWidth, _measureText(row.amount, _entryStyle));
    }
    for (final jackpot in row.jackpotEntries) {
      numberWidth =
          _maxDouble(numberWidth, _measureText(jackpot.number, _jackpotStyle));
      amountWidth =
          _maxDouble(amountWidth, _measureText(jackpot.amount, _jackpotStyle));
    }
  }

  final maxNumberWidth =
      (_receiptTableMaxWidth - _receiptTableGap - amountWidth)
          .clamp(1.0, _receiptTableMaxWidth)
          .toDouble();
  return _ReceiptImageMetrics(
    numberWidth: numberWidth.clamp(1.0, maxNumberWidth).toDouble(),
    amountWidth: amountWidth,
  );
}

double _paintText(
  ui.Canvas? canvas,
  String text,
  TextStyle style,
  double x,
  double y, {
  double? width,
  TextAlign textAlign = TextAlign.left,
  int? maxLines,
}) {
  return _paintTextSpan(
    canvas,
    TextSpan(text: text, style: style),
    x,
    y,
    maxWidth: width,
    textAlign: textAlign,
    maxLines: maxLines,
  );
}

double _paintTableText(
  ui.Canvas? canvas,
  String text,
  TextStyle style,
  double x,
  double y,
  double width, {
  TextAlign textAlign = TextAlign.left,
}) {
  return _paintText(
    canvas,
    text,
    style,
    x,
    y,
    width: width,
    textAlign: textAlign,
    maxLines: 1,
  );
}

double _paintTextSpan(
  ui.Canvas? canvas,
  InlineSpan span,
  double x,
  double y, {
  double? maxWidth,
  TextAlign textAlign = TextAlign.left,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: span,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '',
    textAlign: textAlign,
    textDirection: ui.TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(
      minWidth: maxWidth ?? 0,
      maxWidth: maxWidth ?? double.infinity,
    );
  if (canvas != null) {
    painter.paint(canvas, ui.Offset(x, y));
  }
  return painter.height;
}

double _measureText(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: ui.TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  return painter.width;
}

void _paintRule(ui.Canvas? canvas, double y) {
  if (canvas == null) return;
  canvas.drawRect(
    ui.Rect.fromLTWH(
      _receiptPaddingX,
      y,
      _receiptContentWidth,
      _receiptRuleHeight,
    ),
    ui.Paint()..color = _receiptInk,
  );
}

double _maxDouble(double first, double second) {
  return first > second ? first : second;
}

List<_EscPosReceiptRow> _buildRows(
  List<ReceiptItemModel> items,
  String receiptSession,
) {
  final rows = <_EscPosReceiptRow>[];
  for (final item in items) {
    final number = AppLocalizations.localizeDigits(
      formatParchiNumber(
        item,
        item.sessionOverride ?? receiptSession,
      ),
    );

    rows.add(_EscPosReceiptRow(
      number: number,
      amount: AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
      showMainEntry: true,
      topLabel: item.isBazarSangam
          ? 'BAZAR'
          : item.isMotorPana
              ? 'MP'
              : null,
      jackpotEntries: [
        for (final jackpot in item.jackpotEntries)
          if (jackpot.number.isNotEmpty || jackpot.amount.isNotEmpty)
            _EscPosJackpotRow(
              number: AppLocalizations.localizeDigits(
                '${_jackpotArrowFor(number, jackpot.number)}'
                '${jackpot.number} >',
              ),
              amount: AppLocalizations.localizeDigits(jackpot.amount),
            ),
      ],
    ));
  }
  return rows;
}

String _jackpotArrowFor(String parentNumber, String jackpotNumber) {
  final markerIndex = parentNumber.lastIndexOf('>');
  if (markerIndex == -1) return '->';
  final parentPrefixLength = parentNumber.substring(0, markerIndex).length;
  final dashCount = parentPrefixLength - jackpotNumber.trim().length - 2;
  return '${'-' * (dashCount < 1 ? 1 : dashCount)}>';
}

String _sessionLabel(String session) {
  final value = session.trim();
  return value.isEmpty ? '-' : value.toUpperCase();
}
