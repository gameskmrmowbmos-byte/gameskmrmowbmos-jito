import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/presentation/parchi_render_model.dart';

const _receiptImageWidth = 372.0;
const _receiptTicketWidth = 338.0;
const _receiptTicketX = (_receiptImageWidth - _receiptTicketWidth) / 2;
const _receiptPaddingX = _receiptTicketX + 17.0;
const _receiptPaddingTop = 22.0;
const _receiptPaddingBottom = 10.0;
const _receiptContentWidth = _receiptTicketWidth - 34.0;
const _receiptTableMaxWidth = 286.0;
const _receiptTableGap = 34.0;
const _receiptRuleHeight = 3.0;
const int _parchiEntriesPerPage = 10;
const int _receiptFeedBeforeCut = 1;
const _receiptInk = ui.Color(0xFF111820);
const _receiptWhite = ui.Color(0xFFFFFFFF);
const _receiptStrongTextShadow = <ui.Shadow>[
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0.45, 0), blurRadius: 0),
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0, 0.45), blurRadius: 0),
];
const _receiptHeaderTextShadow = <ui.Shadow>[
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0.32, 0), blurRadius: 0),
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0, 0.32), blurRadius: 0),
];
const _receiptIndicTextShadow = <ui.Shadow>[
  ui.Shadow(color: _receiptInk, offset: ui.Offset(0.12, 0), blurRadius: 0),
];
const _receiptIndicFontFallback = <String>[
  'Noto Sans Devanagari',
  'Nirmala UI',
  'Mangal',
];

const _topLabelStyle = TextStyle(
  color: _receiptInk,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  height: 1.15,
);
const _topNumberStyle = TextStyle(
  color: _receiptInk,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  height: 1.15,
);
const _sessionStyle = TextStyle(
  color: _receiptInk,
  fontSize: 16,
  fontWeight: FontWeight.w900,
  height: 1,
);
const _dateStyle = TextStyle(
  color: _receiptInk,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.15,
);
const _marketStyle = TextStyle(
  color: _receiptInk,
  fontSize: 28,
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
  fontWeight: FontWeight.w500,
  height: 1,
  shadows: _receiptStrongTextShadow,
);
const _jackpotStyle = TextStyle(
  color: _receiptInk,
  fontSize: 22,
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
const _totalAmountStyle = TextStyle(
  color: _receiptInk,
  fontSize: 27,
  fontWeight: FontWeight.w500,
  height: 1.1,
  shadows: _receiptStrongTextShadow,
);
const _instructionStyle = TextStyle(
  color: _receiptInk,
  fontSize: 19,
  fontWeight: FontWeight.w700,
  height: 1.12,
  shadows: _receiptIndicTextShadow,
);

bool get _isIndicReceiptLanguage {
  final code = AppLanguageStore.current.code;
  return code == AppLanguage.hindi.code || code == AppLanguage.marathi.code;
}

TextStyle get _receiptTopLabelStyle => _isIndicReceiptLanguage
    ? _topLabelStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1.18,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _topLabelStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptTopNumberStyle => _isIndicReceiptLanguage
    ? _topNumberStyle.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        height: 1.18,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _topNumberStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptSessionStyle => _isIndicReceiptLanguage
    ? _sessionStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _sessionStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptDateStyle => _isIndicReceiptLanguage
    ? _dateStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        height: 1.18,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _dateStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptMarketStyle => _isIndicReceiptLanguage
    ? _marketStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        height: 1.18,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _marketStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptOwnerStyle => _isIndicReceiptLanguage
    ? _ownerStyle.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _ownerStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptTableHeaderStyle => _isIndicReceiptLanguage
    ? _headerStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _headerStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptTotalAmountStyle => _isIndicReceiptLanguage
    ? _totalAmountStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.15,
        shadows: _receiptIndicTextShadow,
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _totalAmountStyle.copyWith(shadows: _receiptHeaderTextShadow);

TextStyle get _receiptInstructionStyle => _isIndicReceiptLanguage
    ? _instructionStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.18,
        shadows: const <ui.Shadow>[],
        fontFamilyFallback: _receiptIndicFontFallback,
      )
    : _instructionStyle;

TextStyle get _receiptEntryMarkerStyle => _entryStyle.copyWith(
      fontWeight: FontWeight.w900,
      shadows: _receiptStrongTextShadow,
    );

List<List<_EscPosReceiptRow>> _buildRowPages(
  List<ReceiptItemModel> items,
  String receiptSession,
) {
  if (items.isEmpty) return [const <_EscPosReceiptRow>[]];

  final pages = <List<_EscPosReceiptRow>>[];
  var currentPage = <_EscPosReceiptRow>[];
  var currentEntryCount = 0;
  var previousMainEntryWasMotor = false;

  void pushCurrentPage() {
    if (currentPage.isEmpty) return;
    pages.add(currentPage);
    currentPage = <_EscPosReceiptRow>[];
    currentEntryCount = 0;
  }

  void ensurePageSpace() {
    if (currentEntryCount >= _parchiEntriesPerPage) {
      pushCurrentPage();
    }
  }

  for (final item in items) {
    final jackpotEntries = _visibleJackpotEntries(item)
        .where((entry) =>
            entry.number.isNotEmpty || entry.displayAmount.isNotEmpty)
        .toList(growable: false);
    final requiredEntryCount = 1 + jackpotEntries.length;

    if (currentEntryCount > 0 &&
        currentEntryCount + requiredEntryCount > _parchiEntriesPerPage) {
      pushCurrentPage();
    }

    ensurePageSpace();

    final jackpotSpaceOnMainPage =
        _parchiEntriesPerPage - currentEntryCount - 1;
    final mainJackpotCount = jackpotEntries.length < jackpotSpaceOnMainPage
        ? jackpotEntries.length
        : jackpotSpaceOnMainPage;
    final mainJackpotEntries = jackpotEntries.sublist(0, mainJackpotCount);

    final parentNumber = AppLocalizations.localizeDigits(
      formatParchiNumber(item, item.sessionOverride ?? receiptSession),
    );
    final showMotorLabel = item.isMotorPana && !previousMainEntryWasMotor;

    currentPage.add(_EscPosReceiptRow(
      number: parentNumber,
      amount: AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
      showMainEntry: true,
      topLabel: item.isBazarSangam
          ? 'BAZAR'
          : showMotorLabel
              ? 'MP'
              : null,
      jackpotEntries: [
        for (final jackpot in mainJackpotEntries)
          _EscPosJackpotRow(
            parentNumber: parentNumber,
            number: AppLocalizations.localizeDigits(
              jackpot.number,
            ),
            amount: AppLocalizations.localizeDigits(jackpot.displayAmount),
          ),
      ],
    ));
    previousMainEntryWasMotor = item.isMotorPana;
    currentEntryCount += 1 + mainJackpotCount;

    var jackpotIndex = mainJackpotCount;
    while (jackpotIndex < jackpotEntries.length) {
      ensurePageSpace();
      final available = _parchiEntriesPerPage - currentEntryCount;
      final nextIndex = jackpotIndex + available > jackpotEntries.length
          ? jackpotEntries.length
          : jackpotIndex + available;
      final continuationEntries =
          jackpotEntries.sublist(jackpotIndex, nextIndex);

      currentPage.add(_EscPosReceiptRow(
        number: '',
        amount: '',
        showMainEntry: false,
        jackpotEntries: [
          for (final jackpot in continuationEntries)
            _EscPosJackpotRow(
              parentNumber: parentNumber,
              number: AppLocalizations.localizeDigits(
                jackpot.number,
              ),
              amount: AppLocalizations.localizeDigits(jackpot.displayAmount),
            ),
        ],
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
    final pageTotals = computeReceiptPageTotals(
      detail.consolidatedItems,
      isOtc: receipt.isOtc,
    );

    for (var pageIndex = 0; pageIndex < rowPages.length; pageIndex++) {
      final pageParchiNo = _parchiNoForPage(parchi, pageIndex);
      final pageTotalText = AppLocalizations.localizeDigits(
        _formatAmount(pageTotals[pageIndex]),
      );
      final receiptImage = await _buildReceiptImage(
        parchi: pageParchiNo,
        createdAt: createdAt,
        session: session,
        market: AppLocalizations.localizeMarketName(market.toUpperCase()),
        ownerName: ownerName,
        rows: rowPages[pageIndex],
        totalText: pageTotalText,
        isOtc: receipt.isOtc,
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
    _receiptTopLabelStyle,
    _receiptPaddingX,
    y,
    width: leftWidth,
    maxLines: 1,
  );
  _paintText(
    canvas,
    dateText,
    _receiptDateStyle,
    _receiptImageWidth - _receiptPaddingX - rightTextWidth,
    y,
    width: rightTextWidth,
    textAlign: TextAlign.right,
  );
  y += 25;
  _paintText(
    canvas,
    AppLocalizations.localizeDigits(parchi),
    _receiptTopNumberStyle,
    _receiptPaddingX,
    y,
    width: leftWidth,
    maxLines: 1,
  );
  _paintText(
    canvas,
    timeText,
    _receiptDateStyle,
    _receiptImageWidth - _receiptPaddingX - rightTextWidth,
    y,
    width: rightTextWidth,
    textAlign: TextAlign.right,
  );
  y += 28;
  _paintText(
    canvas,
    session.toUpperCase(),
    _receiptSessionStyle,
    _receiptPaddingX,
    y,
  );
  y += 28;

  final owner = ownerName?.trim() ?? '';
  if (owner.isNotEmpty) {
    y += _paintText(
      canvas,
      owner.toUpperCase(),
      _receiptOwnerStyle,
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
    _receiptMarketStyle,
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
    _receiptTableHeaderStyle,
    tableX,
    y,
    metrics.numberWidth,
  );
  _paintTableText(
    canvas,
    AppLocalizations.trCurrent('AMT'),
    _receiptTableHeaderStyle,
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
        _receiptEntryMarkerStyle,
        tableX,
        y,
        metrics.totalWidth,
      );
      y += 9;
    }
    if (row.showMainEntry) {
      _paintReceiptNumber(
        canvas,
        row.number,
        tableX,
        y,
        metrics.numberWidth,
      );
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
      _paintJackpotNumber(canvas, jackpot, tableX, y, metrics.numberWidth);
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
    _receiptTotalAmountStyle,
    tableX,
    y,
    metrics.numberWidth,
  );
  y += _paintTableText(
    canvas,
    totalText,
    _receiptTotalAmountStyle,
    tableX + metrics.numberWidth + _receiptTableGap,
    y,
    metrics.amountWidth,
    textAlign: TextAlign.right,
  );
  y += 18;
  _paintRule(canvas, y);
  y += _receiptRuleHeight + 22;
  y += _paintText(
    canvas,
    AppLocalizations.trCurrent(
      'Please check the receipt. No complaints will be accepted later.',
    ),
    _receiptInstructionStyle,
    _receiptPaddingX,
    y,
    width: _receiptContentWidth,
    textAlign: TextAlign.center,
    maxLines: 4,
  );
  y += _receiptPaddingBottom;

  return y;
}

_ReceiptImageMetrics _imageTableMetrics(
  List<_EscPosReceiptRow> rows,
  String totalText,
) {
  var numberWidth = _measureText(
      AppLocalizations.trCurrent('NUMBER'), _receiptTableHeaderStyle);
  var amountWidth =
      _measureText(AppLocalizations.trCurrent('AMT'), _receiptTableHeaderStyle);
  numberWidth = _maxDouble(
    numberWidth,
    _measureText(AppLocalizations.trCurrent('TOTAL'), _totalStyle),
  );
  amountWidth = _maxDouble(amountWidth, _measureText(totalText, _totalStyle));

  for (final row in rows) {
    if (row.topLabel != null) {
      numberWidth = _maxDouble(
        numberWidth,
        _measureText(row.topLabel!, _receiptEntryMarkerStyle),
      );
    }
    if (row.showMainEntry) {
      numberWidth = _maxDouble(numberWidth, _measureReceiptNumber(row.number));
      amountWidth =
          _maxDouble(amountWidth, _measureText(row.amount, _entryStyle));
    }
    for (final jackpot in row.jackpotEntries) {
      numberWidth = _maxDouble(
        numberWidth,
        _measureReceiptNumber(jackpot.parentNumber),
      );
      numberWidth = _maxDouble(
        numberWidth,
        _measureText('${jackpot.number} >', _jackpotStyle),
      );
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

double _paintReceiptNumber(
  ui.Canvas? canvas,
  String text,
  double x,
  double y,
  double width,
) {
  return _paintTextSpan(
    canvas,
    _receiptNumberSpan(text),
    x,
    y,
    maxWidth: width,
    maxLines: 1,
  );
}

TextSpan _receiptNumberSpan(String text) {
  final parts = NumberDisplayParts.fromDisplay(text);
  final markerStyle = _receiptEntryMarkerStyle;
  return TextSpan(
    children: [
      if (parts.leadingArrow.isNotEmpty)
        TextSpan(text: '${parts.leadingArrow} ', style: markerStyle),
      if (parts.beforeSuffix.isNotEmpty)
        TextSpan(text: parts.beforeSuffix, style: _entryStyle),
      if (parts.suffix.isNotEmpty)
        TextSpan(
          text: '${parts.beforeSuffix.isEmpty ? '' : ' '}${parts.suffix}',
          style: markerStyle,
        ),
      if (parts.trailingArrow.isNotEmpty)
        TextSpan(text: ' ${parts.trailingArrow}', style: markerStyle),
    ],
  );
}

double _paintJackpotNumber(
  ui.Canvas? canvas,
  _EscPosJackpotRow jackpot,
  double x,
  double y,
  double width,
) {
  final parentWidth = _measureReceiptNumber(jackpot.parentNumber.trimRight())
      .clamp(1.0, width)
      .toDouble();
  final endingWidth = _measureText('>', _jackpotStyle);
  final gapWidth = _measureText(' ', _jackpotStyle);
  final maxNumberWidth = (parentWidth - endingWidth - gapWidth * 2)
      .clamp(0.0, parentWidth)
      .toDouble();
  final childNumberWidth = _measureText(jackpot.number, _jackpotStyle)
      .clamp(0.0, maxNumberWidth)
      .toDouble();
  final arrowWidth = (parentWidth - childNumberWidth - endingWidth - gapWidth)
      .clamp(0.0, parentWidth)
      .toDouble();

  if (canvas != null && arrowWidth > 0) {
    _paintJoinedArrow(
      canvas,
      x,
      y + ((_jackpotStyle.fontSize ?? 22) * 0.42),
      arrowWidth,
    );
  }

  final textX = x + arrowWidth + gapWidth;
  final textHeight = _paintText(
    canvas,
    jackpot.number,
    _jackpotStyle,
    textX,
    y,
    width: childNumberWidth,
    textAlign: TextAlign.right,
    maxLines: 1,
  );
  _paintText(
    canvas,
    '>',
    _jackpotStyle,
    textX + childNumberWidth + gapWidth,
    y,
    width: endingWidth,
    maxLines: 1,
  );
  return textHeight;
}

void _paintJoinedArrow(
  ui.Canvas canvas,
  double x,
  double centerY,
  double width,
) {
  final headLength = width < 7 ? width : 7.0;
  final shaftEnd = x + width - headLength;
  final paint = ui.Paint()
    ..color = _receiptInk
    ..strokeWidth = 2.0
    ..strokeCap = ui.StrokeCap.square
    ..strokeJoin = ui.StrokeJoin.miter
    ..style = ui.PaintingStyle.stroke;

  final tip = ui.Offset(x + width, centerY);
  canvas
    ..drawLine(ui.Offset(x, centerY), tip, paint)
    ..drawLine(ui.Offset(shaftEnd, centerY - headLength / 2), tip, paint)
    ..drawLine(ui.Offset(shaftEnd, centerY + headLength / 2), tip, paint);
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

double _measureReceiptNumber(String text) {
  return _measureTextSpan(_receiptNumberSpan(text));
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

String _sessionLabel(String session) {
  final value = session.trim();
  return value.isEmpty ? '-' : value.toUpperCase();
}

List<num> computeReceiptPageTotals(
  List<ReceiptItemModel> items, {
  required bool isOtc,
}) {
  return computeParchiPageTotals(items, isOtc: isOtc);
}

List<JackpotEntryModel> _visibleJackpotEntries(ReceiptItemModel item) {
  if (!item.isJackpot && item.jackpotEntries.isEmpty) {
    return const <JackpotEntryModel>[];
  }
  return item.jackpotEntries;
}
