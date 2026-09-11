import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

const _parchiEntriesPerPage = 10;
const _receiptFeedBeforeCut = 6;
const _receiptImageWidth = 372.0;
const _receiptTicketWidth = 368.0;
const _receiptTicketX = (_receiptImageWidth - _receiptTicketWidth) / 2;
const _receiptPaddingX = _receiptTicketX + 3.0;
const _receiptPaddingTop = 18.0;
const _receiptPaddingBottom = 22.0;
const _receiptContentWidth = _receiptTicketWidth - 6.0;
const _receiptTableMaxWidth = 320.0;
const _receiptTableGap = 36.0;
const _receiptRuleHeight = 3.0;
const _receiptInk = ui.Color(0xFF111820);
const _receiptWhite = ui.Color(0xFFFFFFFF);
const _receiptStrongTextShadow = <ui.Shadow>[
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0.45, 0), blurRadius: 0),
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0, 0.45), blurRadius: 0),
];

const _topLabelStyle = TextStyle(
  color: _receiptInk,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.15,
);
const _topNumberStyle = TextStyle(
  color: _receiptInk,
  fontSize: 23,
  fontWeight: FontWeight.w900,
  height: 1.15,
);
const _sessionStyle = TextStyle(
  color: _receiptInk,
  fontSize: 17,
  fontWeight: FontWeight.w900,
  height: 1,
);
const _dateStyle = TextStyle(
  color: _receiptInk,
  fontSize: 20,
  fontWeight: FontWeight.w800,
  height: 1.15,
);
const _marketStyle = TextStyle(
  color: _receiptInk,
  fontSize: 29,
  fontWeight: FontWeight.w900,
  height: 1.1,
);
const _ownerStyle = TextStyle(
  color: _receiptInk,
  fontSize: 23,
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
  fontSize: 27,
  fontWeight: FontWeight.w900,
  height: 1,
  shadows: _receiptStrongTextShadow,
);
const _entryNumberStyle = TextStyle(
  color: _receiptInk,
  fontSize: 30,
  fontWeight: FontWeight.w600,
  height: 1,
);
const _entryMarkerStyle = TextStyle(
  color: _receiptInk,
  fontSize: 29,
  fontWeight: FontWeight.w900,
  height: 1,
  shadows: _receiptStrongTextShadow,
);
const _entryAmountStyle = TextStyle(
  color: _receiptInk,
  fontSize: 27,
  fontWeight: FontWeight.w500,
  height: 1,
);
const _jackpotNumberStyle = TextStyle(
  color: _receiptInk,
  fontSize: 28,
  fontWeight: FontWeight.w600,
  height: 1,
);
const _jackpotMarkerStyle = TextStyle(
  color: _receiptInk,
  fontSize: 27,
  fontWeight: FontWeight.w900,
  height: 1,
  shadows: _receiptStrongTextShadow,
);
const _jackpotAmountStyle = TextStyle(
  color: _receiptInk,
  fontSize: 25,
  fontWeight: FontWeight.w500,
  height: 1,
);
const _totalStyle = TextStyle(
  color: _receiptInk,
  fontSize: 27,
  fontWeight: FontWeight.w900,
  height: 1.1,
  shadows: _receiptStrongTextShadow,
);
const _instructionStyle = TextStyle(
  color: _receiptInk,
  fontSize: 20,
  fontWeight: FontWeight.w800,
  height: 1.15,
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
    final rowPages = _buildRowPages(detail.consolidatedItems, receipt.session);
    final total = detail.consolidatedItems.fold<num>(
          0,
          (sum, item) => sum + item.amount,
        ) *
        (receipt.isOtc ? 2 : 1);
    final totalText = AppLocalizations.localizeDigits(_formatAmount(total));

    for (var pageIndex = 0; pageIndex < rowPages.length; pageIndex++) {
      final pageParchiNo = _parchiNoForPage(parchi, pageIndex);
      final receiptImage = await _buildReceiptImage(
        parchi: pageParchiNo,
        createdAt: createdAt,
        session: session,
        market: AppLocalizations.localizeMarketName(market.toUpperCase()),
        ownerName: ownerName,
        rows: rowPages[pageIndex],
        totalText: totalText,
        isOtc: receipt.isOtc,
        showTotal: pageIndex == rowPages.length - 1,
      );
      bytes.addAll(generator.imageRaster(receiptImage, align: PosAlign.center));
      bytes.addAll(generator.feed(_receiptFeedBeforeCut));
      if (pageIndex != rowPages.length - 1) {
        bytes.addAll(generator.cut(mode: PosCutMode.full));
      }
    }
    bytes.addAll(generator.cut(mode: PosCutMode.full));
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
      ...generator.feed(_receiptFeedBeforeCut),
      ...generator.cut(mode: PosCutMode.full),
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
  const _EscPosJackpotRow({
    required this.parentNumber,
    required this.number,
    required this.amount,
  });

  final String parentNumber;
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
  required bool showTotal,
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
    showTotal: showTotal,
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
    showTotal: showTotal,
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
  required bool showTotal,
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
  y += 28;
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
  y += 28;
  _paintText(canvas, session.toUpperCase(), _sessionStyle, _receiptPaddingX, y);
  y += 28;

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
  y += 39;

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
      y += 13;
    }
    if (row.showMainEntry) {
      _paintEntryNumber(
        canvas,
        row.number,
        tableX,
        y,
        metrics.numberWidth,
      );
      y += _paintTableText(
        canvas,
        row.amount,
        _entryAmountStyle,
        tableX + metrics.numberWidth + _receiptTableGap,
        y,
        metrics.amountWidth,
        textAlign: TextAlign.right,
      );
      y += 15;
    }
    for (final jackpot in row.jackpotEntries) {
      _paintJackpotNumber(
        canvas,
        jackpot.parentNumber,
        jackpot.number,
        tableX,
        y,
        metrics.numberWidth,
      );
      y += _paintTableText(
        canvas,
        jackpot.amount,
        _jackpotAmountStyle,
        tableX + metrics.numberWidth + _receiptTableGap,
        y,
        metrics.amountWidth,
        textAlign: TextAlign.right,
      );
      y += 14;
    }
  }

  y += rows.isEmpty ? 50 : 18;
  if (showTotal && isOtc) {
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
  if (showTotal) {
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
  }
  y += _receiptRuleHeight + 12;
  y += _paintText(
    canvas,
    AppLocalizations.trCurrent(
      'Please check the receipt. No complaints will be accepted later.',
    ),
    _instructionStyle,
    _receiptPaddingX,
    y,
    width: _receiptContentWidth,
    textAlign: TextAlign.center,
    maxLines: 3,
  );
  y += _receiptPaddingBottom;

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
      numberWidth = _maxDouble(
        numberWidth,
        _measureText(row.topLabel!, _entryStyle),
      );
    }
    if (row.showMainEntry) {
      numberWidth = _maxDouble(
        numberWidth,
        _measureTextSpan(_entryNumberSpan(row.number)),
      );
      amountWidth =
          _maxDouble(amountWidth, _measureText(row.amount, _entryAmountStyle));
    }
    for (final jackpot in row.jackpotEntries) {
      numberWidth = _maxDouble(
        numberWidth,
        _measureTextSpan(_entryNumberSpan(jackpot.parentNumber)),
      );
      amountWidth = _maxDouble(
          amountWidth, _measureText(jackpot.amount, _jackpotAmountStyle));
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

double _paintEntryNumber(
  ui.Canvas? canvas,
  String text,
  double x,
  double y,
  double width,
) {
  return _paintTextSpan(
    canvas,
    _entryNumberSpan(text),
    x,
    y,
    maxWidth: width,
    maxLines: 1,
  );
}

TextSpan _entryNumberSpan(String text) {
  final parts = NumberDisplayParts.fromDisplay(text);
  return TextSpan(
    children: [
      if (parts.leadingArrow.isNotEmpty)
        TextSpan(text: '${parts.leadingArrow} ', style: _entryMarkerStyle),
      if (parts.beforeSuffix.isNotEmpty)
        TextSpan(text: parts.beforeSuffix, style: _entryNumberStyle),
      if (parts.suffix.isNotEmpty)
        TextSpan(
          text: '${parts.beforeSuffix.isEmpty ? '' : ' '}${parts.suffix}',
          style: _entryMarkerStyle,
        ),
      if (parts.trailingArrow.isNotEmpty)
        TextSpan(text: ' ${parts.trailingArrow}', style: _entryMarkerStyle),
    ],
  );
}

double _paintJackpotNumber(
  ui.Canvas? canvas,
  String parentText,
  String text,
  double x,
  double y,
  double width,
) {
  final boundaryWidth = _measureTextSpan(_entryNumberSpan(parentText))
      .clamp(1.0, width)
      .toDouble();
  final childText = text.trim();
  final childWidth = _measureText(childText, _jackpotNumberStyle)
      .clamp(0.0, boundaryWidth)
      .toDouble();
  final endingWidth = _measureText('>', _jackpotMarkerStyle);
  final gapWidth = _measureText(' ', _jackpotNumberStyle);
  final fixedWidth = childWidth + gapWidth + endingWidth;
  final arrowWidth =
      (boundaryWidth - fixedWidth - gapWidth).clamp(0.0, boundaryWidth);
  final textHeight = _measureTextHeight(childText, _jackpotNumberStyle);

  if (canvas != null) {
    _paintJackpotArrow(canvas, x, y, arrowWidth.toDouble(), textHeight);
    _paintText(
      canvas,
      childText,
      _jackpotNumberStyle,
      x + arrowWidth + gapWidth,
      y,
      width: childWidth,
      maxLines: 1,
    );
    _paintText(
      canvas,
      '>',
      _jackpotMarkerStyle,
      x + arrowWidth + gapWidth + childWidth + gapWidth,
      y,
      width: endingWidth,
      maxLines: 1,
    );
  }

  return textHeight;
}

void _paintJackpotArrow(
  ui.Canvas canvas,
  double x,
  double y,
  double width,
  double height,
) {
  if (width <= 0 || height <= 0) return;
  final paint = ui.Paint()
    ..color = _receiptInk
    ..strokeWidth = 2.0
    ..strokeCap = ui.StrokeCap.square
    ..strokeJoin = ui.StrokeJoin.miter
    ..style = ui.PaintingStyle.stroke;
  final centerY = y + height / 2;
  final headLength = width < 9 ? width : 9.0;
  final shaftEnd = x + width - headLength;
  final tip = ui.Offset(x + width, centerY);
  canvas.drawLine(ui.Offset(x, centerY), tip, paint);
  canvas.drawLine(
    ui.Offset(shaftEnd, centerY - headLength / 2),
    tip,
    paint,
  );
  canvas.drawLine(
    ui.Offset(shaftEnd, centerY + headLength / 2),
    tip,
    paint,
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
  return _measureTextSpan(TextSpan(text: text, style: style));
}

double _measureTextSpan(InlineSpan span) {
  final painter = TextPainter(
    text: span,
    maxLines: 1,
    textDirection: ui.TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  return painter.width;
}

double _measureTextHeight(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: ui.TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  return painter.height;
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

List<List<_EscPosReceiptRow>> _buildRowPages(
  List<ReceiptItemModel> items,
  String receiptSession,
) {
  if (items.isEmpty) return const [<_EscPosReceiptRow>[]];
  final pages = <List<_EscPosReceiptRow>>[];
  var currentPage = <_EscPosReceiptRow>[];
  var currentEntryCount = 0;

  void pushCurrentPage() {
    if (currentPage.isEmpty) return;
    pages.add(currentPage);
    currentPage = <_EscPosReceiptRow>[];
    currentEntryCount = 0;
  }

  void ensurePageSpace() {
    if (currentEntryCount >= _parchiEntriesPerPage) pushCurrentPage();
  }

  for (final item in items) {
    final number = AppLocalizations.localizeDigits(
      formatParchiNumber(
        item,
        item.sessionOverride ?? receiptSession,
      ),
    );
    final jackpotEntries = [
      for (final jackpot in item.jackpotEntries)
        if (jackpot.number.isNotEmpty || jackpot.amount.isNotEmpty)
          _EscPosJackpotRow(
            parentNumber: number,
            number: AppLocalizations.localizeDigits(jackpot.number),
            amount: AppLocalizations.localizeDigits(jackpot.amount),
          ),
    ];

    ensurePageSpace();
    final jackpotSpaceOnMainPage =
        _parchiEntriesPerPage - currentEntryCount - 1;
    final mainJackpotCount = jackpotEntries.length < jackpotSpaceOnMainPage
        ? jackpotEntries.length
        : jackpotSpaceOnMainPage;

    currentPage.add(_EscPosReceiptRow(
      number: number,
      amount: AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
      showMainEntry: true,
      topLabel: item.isBazarSangam
          ? 'BAZAR'
          : item.isMotorPana
              ? 'MP'
              : null,
      jackpotEntries: jackpotEntries.sublist(0, mainJackpotCount),
    ));
    currentEntryCount += 1 + mainJackpotCount;

    var jackpotIndex = mainJackpotCount;
    while (jackpotIndex < jackpotEntries.length) {
      ensurePageSpace();
      final available = _parchiEntriesPerPage - currentEntryCount;
      final nextIndex = jackpotIndex + available > jackpotEntries.length
          ? jackpotEntries.length
          : jackpotIndex + available;
      currentPage.add(_EscPosReceiptRow(
        number: number,
        amount: AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
        showMainEntry: false,
        jackpotEntries: jackpotEntries.sublist(jackpotIndex, nextIndex),
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
  return '$prefix${(number + pageIndex).toString().padLeft(
        numberText.length,
        '0',
      )}';
}

String _sessionLabel(String session) {
  final value = session.trim();
  return value.isEmpty ? '-' : value.toUpperCase();
}
