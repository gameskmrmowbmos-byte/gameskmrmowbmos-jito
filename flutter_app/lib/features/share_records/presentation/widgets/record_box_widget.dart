import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/share_records/data/share_records_models.dart';
import 'package:matka_management/shared/widgets/aligned_jackpot_marker.dart';

const _receiptAlphabetShadow = <Shadow>[
  Shadow(color: Colors.black, offset: Offset(0.18, 0), blurRadius: 0),
];
const _receiptGreenAlphabetShadow = <Shadow>[
  Shadow(color: Color(0xFF16A34A), offset: Offset(0.18, 0), blurRadius: 0),
];
const _shareReceiptNumberScale = 1.3;

class RecordBoxWidget extends StatelessWidget {
  const RecordBoxWidget({
    required this.box,
    this.compact = false,
    this.ownerName,
    super.key,
  });

  final RecordBoxData box;
  final bool compact;
  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    final receiptTitle = box.receiptNumber.trim().isNotEmpty
        ? box.receiptNumber.trim()
        : box.displayName;
    final parchiNo = _parchiNoForPage(receiptTitle, box.partIndex - 1);
    final marketTitle = box.marketName.trim().isEmpty
        ? '-'
        : AppLocalizations.localizeMarketName(box.marketName.trim())
            .toUpperCase();
    final sessionLabel = box.session.trim().isEmpty
        ? '-'
        : context.trMaybe(box.session.trim().toUpperCase());
    final printedAt = box.createdAt ?? box.date ?? DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 260.0;
        final boxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 160.0;
        final heightScale = height / 260;
        final widthScale = boxWidth / 170;
        var visualLineCount = 0;
        for (var index = 0; index < box.items.length; index++) {
          final item = box.items[index];
          final mainLine = item.showMainEntry ? 1 : 0;
          final labelLines =
              _shareReceiptTopLabelForItem(box.items, index) == null ? 0 : 1;
          final jackpotLines = item.jackpotEntries.length;
          visualLineCount += mainLine + labelLines + jackpotLines;
        }
        final densityScale =
            visualLineCount > 8 ? 2.05 * 8 / visualLineCount : 2.05;
        final maxScale = visualLineCount >= 8
            ? densityScale.clamp(1.05, 2.05).toDouble()
            : 2.2;
        final scale = heightScale < widthScale
            ? heightScale.clamp(0.42, maxScale).toDouble()
            : widthScale.clamp(0.42, maxScale).toDouble();
        final compactScale = compact ? 0.92 : 1.0;
        final tinySize = 9 * scale * compactScale;
        final headerSize = 10 * scale * compactScale;
        final titleSize = 15 * scale * compactScale;
        final rowSize = 12.5 * scale * compactScale;
        final numberRowSize = rowSize * _shareReceiptNumberScale;
        final columnGap = 8 * scale;
        final dateColumnWidth =
            (58 * scale * compactScale).clamp(42.0, 62.0).toDouble();
        final totalAmount = box.isOtc ? box.boxSubtotal * 2 : box.boxSubtotal;
        final totalText = _formatAmount(totalAmount);
        final totalRowSize = numberRowSize;
        final contentWidth = boxWidth - (16 * scale);
        final numberColumnWidth = _shareNumberColumnWidth(
          context,
          box,
          numberRowSize,
          headerSize,
          totalRowSize,
        );
        final amountColumnWidth = _shareAmountColumnWidth(
          context,
          box,
          rowSize,
          headerSize,
          totalRowSize,
          totalText,
          scale,
          compactScale,
        );
        final itemList = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < box.items.length; index++)
              _ShareReceiptItemRow(
                item: box.items[index],
                session: box.session,
                topLabel: _shareReceiptTopLabelForItem(box.items, index),
                fontSize: rowSize,
                numberFontSize: numberRowSize,
                verticalPadding: 2.5 * scale,
                numberColumnWidth: numberColumnWidth,
                columnGap: columnGap,
                amountColumnWidth: amountColumnWidth,
              ),
          ],
        );
        return CustomPaint(
          painter: _ReceiptBorderPainter(),
          child: Container(
            clipBehavior: Clip.hardEdge,
            padding: EdgeInsets.fromLTRB(
              8 * scale,
              10 * scale,
              8 * scale,
              9 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: context.tr('PARCHI NO. '),
                                        style: TextStyle(
                                          fontSize: tinySize,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(
                                        text: parchiNo,
                                        style: TextStyle(
                                          fontSize: headerSize,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Color(0xFF111820),
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2 * scale),
                              _BoxText(
                                sessionLabel,
                                fontSize: tinySize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 4 * scale),
                        SizedBox(
                          width: dateColumnWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _BoxText(
                                AppLocalizations.localizeDigits(
                                  DateFormat('dd/MM/yyyy').format(printedAt),
                                ),
                                textAlign: TextAlign.right,
                                fontSize: tinySize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w800,
                              ),
                              SizedBox(height: 3 * scale),
                              _BoxText(
                                AppLocalizations.localizeDigits(
                                  DateFormat('hh:mm a').format(printedAt),
                                ),
                                textAlign: TextAlign.right,
                                fontSize: tinySize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w800,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7 * scale),
                    if (ownerName != null && ownerName!.trim().isNotEmpty) ...[
                      _BoxText(
                        ownerName!.trim().toUpperCase(),
                        textAlign: TextAlign.center,
                        fontSize: 13 * scale,
                        color: const Color(0xFF111820),
                        weight: FontWeight.w900,
                      ),
                      SizedBox(height: 3 * scale),
                    ],
                    _BoxText(
                      marketTitle,
                      textAlign: TextAlign.center,
                      fontSize: titleSize,
                      color: const Color(0xFF111820),
                      weight: FontWeight.w900,
                    ),
                    SizedBox(height: 6 * scale),
                    const _PreviewRule(),
                    SizedBox(height: 5 * scale),
                    Padding(
                      padding: EdgeInsets.fromLTRB(5 * scale, 0, 5 * scale, 0),
                      child: Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: numberColumnWidth,
                              child: _BoxText(
                                context.tr('NUMBER'),
                                fontSize: headerSize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: columnGap),
                            SizedBox(
                              width: amountColumnWidth,
                              child: _BoxText(
                                context.tr('AMT'),
                                textAlign: TextAlign.right,
                                fontSize: headerSize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    itemList,
                    if (box.isOtc) ...[
                      _BoxText(
                        'OTC',
                        textAlign: TextAlign.center,
                        fontSize: headerSize,
                        color: const Color(0xFF16A34A),
                        weight: FontWeight.w900,
                        shadows: _receiptGreenAlphabetShadow,
                      ),
                      SizedBox(height: 5 * scale),
                    ],
                    const _PreviewRule(),
                    SizedBox(height: 7 * scale),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                      child: Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: numberColumnWidth,
                              child: _BoxText(
                                context.tr('TOTAL'),
                                fontSize: totalRowSize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: columnGap),
                            SizedBox(
                              width: amountColumnWidth,
                              child: _BoxText(
                                AppLocalizations.localizeDigits(
                                  totalText,
                                ),
                                textAlign: TextAlign.right,
                                fontSize: totalRowSize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _shareNumberColumnWidth(
  BuildContext context,
  RecordBoxData box,
  double numberFontSize,
  double headerSize,
  double totalFontSize,
) {
  final textDirection = Directionality.of(context);
  var width = _measureShareText(
    context.tr('NUMBER'),
    TextStyle(fontSize: headerSize, fontWeight: FontWeight.w900),
    textDirection,
  );
  width = math.max(
    width,
    _measureShareText(
      context.tr('TOTAL'),
      TextStyle(fontSize: totalFontSize, fontWeight: FontWeight.w900),
      textDirection,
    ),
  );

  for (final item in box.items) {
    width = math.max(
      width,
      _measureShareText(
        _formatShareReceiptNumber(item, box.session),
        TextStyle(fontSize: numberFontSize, fontWeight: FontWeight.w800),
        textDirection,
      ),
    );
    for (final entry in item.jackpotEntries) {
      width = math.max(
        width,
        _measureShareText(
          '${entry.number} >',
          TextStyle(fontSize: numberFontSize, fontWeight: FontWeight.w900),
          textDirection,
        ),
      );
    }
  }

  return width;
}

double _shareAmountColumnWidth(
  BuildContext context,
  RecordBoxData box,
  double rowSize,
  double headerSize,
  double totalFontSize,
  String totalText,
  double scale,
  double compactScale,
) {
  final textDirection = Directionality.of(context);
  var width = (56 * scale * compactScale).clamp(36.0, 96.0).toDouble();
  width = math.max(
    width,
    _measureShareText(
      context.tr('AMT'),
      TextStyle(fontSize: headerSize, fontWeight: FontWeight.w900),
      textDirection,
    ),
  );
  width = math.max(
    width,
    _measureShareText(
      AppLocalizations.localizeDigits(totalText),
      TextStyle(fontSize: totalFontSize, fontWeight: FontWeight.w900),
      textDirection,
    ),
  );

  for (final item in box.items) {
    if (item.showMainEntry) {
      width = math.max(
        width,
        _measureShareText(
          AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
          TextStyle(fontSize: rowSize, fontWeight: FontWeight.w900),
          textDirection,
        ),
      );
    }
    for (final entry in item.jackpotEntries) {
      width = math.max(
        width,
        _measureShareText(
          AppLocalizations.localizeDigits(entry.amount),
          TextStyle(fontSize: rowSize, fontWeight: FontWeight.w500),
          textDirection,
        ),
      );
    }
  }

  return width.clamp(36.0, 120.0).toDouble();
}

String? _shareReceiptTopLabelForItem(List<ShareRecordItem> items, int index) {
  final item = items[index];
  if (!item.showMainEntry) return null;
  if (item.isBazarSangam) return 'BAZAR';
  if (!item.isMotorPana) return null;

  final previousIsMotorPana = index > 0 && items[index - 1].isMotorPana;
  return previousIsMotorPana ? null : 'MP';
}

double _measureShareText(
  String text,
  TextStyle style,
  ui.TextDirection textDirection,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    maxLines: 1,
  )..layout();
  return painter.width;
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

class _ShareReceiptItemRow extends StatelessWidget {
  const _ShareReceiptItemRow({
    required this.item,
    required this.session,
    required this.topLabel,
    required this.fontSize,
    required this.numberFontSize,
    required this.verticalPadding,
    required this.numberColumnWidth,
    required this.columnGap,
    required this.amountColumnWidth,
  });

  final ShareRecordItem item;
  final String session;
  final String? topLabel;
  final double fontSize;
  final double numberFontSize;
  final double verticalPadding;
  final double numberColumnWidth;
  final double columnGap;
  final double amountColumnWidth;

  @override
  Widget build(BuildContext context) {
    final receiptTopLabel = topLabel;
    final visibleJackpotEntries = item.isJackpot
        ? item.jackpotEntries.where(
            (entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty,
          )
        : const Iterable<ShareRecordJackpotEntry>.empty();
    final numberText = _formatShareReceiptNumber(item, session);
    final numberParts = NumberDisplayParts.fromDisplay(numberText);
    final numberTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: numberFontSize,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: 0,
    );
    final labelTextStyle = _receiptAlphabetTextStyle(numberFontSize);
    final jackpotTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: numberFontSize,
      fontWeight: FontWeight.w500,
      height: 1,
      letterSpacing: 0,
    );
    final jackpotArrowStyle = jackpotTextStyle.copyWith(
      fontSize: numberFontSize * 1.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fontSize * 18;
        return Padding(
          padding: EdgeInsets.fromLTRB(5, verticalPadding, 5, verticalPadding),
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (receiptTopLabel != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: verticalPadding),
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: numberColumnWidth +
                                columnGap +
                                amountColumnWidth,
                            child: _BoxText(
                              context.trMaybe(receiptTopLabel),
                              textAlign: TextAlign.left,
                              fontSize: fontSize,
                              color: Colors.black,
                              weight: FontWeight.w900,
                              shadows: _receiptAlphabetShadow,
                            ),
                          ),
                        ),
                      ),
                    if (item.showMainEntry)
                      Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            SizedBox(
                              width: numberColumnWidth,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      if (numberParts.leadingArrow.isNotEmpty)
                                        TextSpan(
                                          text: '${numberParts.leadingArrow} ',
                                          style: labelTextStyle,
                                        ),
                                      if (numberParts.beforeSuffix.isNotEmpty)
                                        TextSpan(
                                          text: AppLocalizations.localizeDigits(
                                            numberParts.beforeSuffix,
                                          ),
                                          style: numberTextStyle,
                                        ),
                                      if (numberParts.suffix.isNotEmpty)
                                        TextSpan(
                                          text: AppLocalizations.localizeDigits(
                                            '${numberParts.beforeSuffix.isEmpty ? '' : ' '}${numberParts.suffix}',
                                          ),
                                          style: labelTextStyle,
                                        ),
                                      if (numberParts.trailingArrow.isNotEmpty)
                                        TextSpan(
                                          text: ' ${numberParts.trailingArrow}',
                                          style: labelTextStyle,
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  style: numberTextStyle,
                                ),
                              ),
                            ),
                            SizedBox(width: columnGap),
                            SizedBox(
                              width: amountColumnWidth,
                              child: _BoxText(
                                AppLocalizations.localizeDigits(
                                  item.effectiveDisplayAmount,
                                ),
                                textAlign: TextAlign.right,
                                fontSize: fontSize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final entry in visibleJackpotEntries)
                      Padding(
                        padding: EdgeInsets.only(top: verticalPadding),
                        child: Align(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: numberColumnWidth,
                                child: AlignedJackpotMarker(
                                  parentText: numberText,
                                  childText: AppLocalizations.localizeDigits(
                                    '${entry.number} >',
                                  ),
                                  parentStyle: numberTextStyle,
                                  arrowStyle: jackpotArrowStyle,
                                  childStyle: jackpotTextStyle,
                                ),
                              ),
                              SizedBox(width: columnGap),
                              SizedBox(
                                width: amountColumnWidth,
                                child: _BoxText(
                                  AppLocalizations.localizeDigits(entry.amount),
                                  textAlign: TextAlign.right,
                                  fontSize: fontSize,
                                  color: const Color(0xFF111820),
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatShareReceiptNumber(ShareRecordItem item, String session) {
  var formattedNumber =
      item.displayNumber.replaceAll('*', ' * ').replaceAll('-', ' * ');
  final normalizedSession = session.trim().toLowerCase();
  final hasFamilyMarker = item.isFamily ||
      RegExp(r'^[fF]\s*').hasMatch(formattedNumber) ||
      RegExp(r'\s*[fF]$').hasMatch(formattedNumber);
  if (hasFamilyMarker) {
    formattedNumber = _familyNumberWithSuffix(formattedNumber);
  }
  if (item.isCpJodi) {
    final cpNumber = formattedNumber
        .replaceFirst(RegExp(r'^[cC][pP]\s*'), '')
        .replaceFirst(RegExp(r'\s*[cC][pP]$'), '')
        .trim();
    if (normalizedSession == 'open') {
      return '$cpNumber CP >';
    } else if (normalizedSession == 'close') {
      return '>$cpNumber CP';
    }
    return '$cpNumber CP';
  }
  if (_isSimpleJodi(item)) return formattedNumber.trim();
  if (normalizedSession == 'open') {
    formattedNumber = '$formattedNumber >';
  } else if (normalizedSession == 'close') {
    formattedNumber = '> $formattedNumber';
  }
  return formattedNumber;
}

String _familyNumberWithSuffix(String value) {
  final trimmed = value.trim();
  final withoutMarker = trimmed
      .replaceFirst(RegExp(r'^[fF]\s*'), '')
      .replaceFirst(RegExp(r'\s*[fF]$'), '')
      .trim();
  return '${withoutMarker}F';
}

bool _isSimpleJodi(ShareRecordItem item) {
  if (item.isCpJodi) return false;
  final type =
      item.type.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
  final betType =
      item.betType.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
  return type == 'JODI' || betType == 'JODI';
}

String _formatAmount(num amount) {
  final text = amount.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

TextStyle _receiptAlphabetTextStyle(double fontSize) {
  return TextStyle(
    color: Colors.black,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
    shadows: _receiptAlphabetShadow,
  );
}

class _PreviewRule extends StatelessWidget {
  const _PreviewRule();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: const Color(0xFF111820));
  }
}

class _BoxText extends StatelessWidget {
  const _BoxText(
    this.text, {
    required this.fontSize,
    required this.color,
    required this.weight,
    this.textAlign = TextAlign.left,
    this.shadows,
  });

  final String text;
  final double fontSize;
  final Color color;
  final FontWeight weight;
  final TextAlign textAlign;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.visible,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        height: 1,
        letterSpacing: 0,
        shadows: shadows,
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.right
          ? Alignment.centerRight
          : textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: textWidget,
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
      canvas.drawLine(Offset(x + step / 2, 0), Offset(x + step, depth), paint);
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
      const Offset(0, depth),
      Offset(0, size.height - depth),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, depth),
      Offset(size.width, size.height - depth),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
