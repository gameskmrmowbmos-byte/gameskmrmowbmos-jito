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

class RecordBoxWidget extends StatelessWidget {
  const RecordBoxWidget({
    required this.box,
    this.compact = false,
    super.key,
  });

  final RecordBoxData box;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final receiptTitle = box.receiptNumber.trim().isNotEmpty
        ? box.receiptNumber.trim()
        : box.displayName;
    final parchiNo = receiptTitle;
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
        final visualLineCount = box.items.fold<int>(0, (total, item) {
          final labelLines =
              item.showMainEntry && (item.isBazarSangam || item.isMotorPana)
                  ? 1
                  : 0;
          final jackpotLines = item.jackpotEntries.length;
          return total + 1 + labelLines + jackpotLines;
        });
        final densityScale =
            visualLineCount > 10 ? 1.6 * 10 / visualLineCount : 1.6;
        final maxScale = box.items.length >= 9
            ? densityScale.clamp(0.75, 1.6).toDouble()
            : 1.85;
        final scale = heightScale < widthScale
            ? heightScale.clamp(0.42, maxScale).toDouble()
            : widthScale.clamp(0.42, maxScale).toDouble();
        final compactScale = compact ? 0.92 : 1.0;
        final tinySize = 9 * scale * compactScale;
        final headerSize = 10 * scale * compactScale;
        final titleSize = 15 * scale * compactScale;
        final rowSize = 12.5 * scale * compactScale;
        final amountColumnWidth =
            (40 * scale * compactScale).clamp(28.0, 44.0).toDouble();
        final dateColumnWidth =
            (58 * scale * compactScale).clamp(42.0, 62.0).toDouble();
        final totalAmount = box.isOtc ? box.boxSubtotal * 2 : box.boxSubtotal;
        final contentWidth = boxWidth - (16 * scale);
        final itemList = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in box.items)
              _ShareReceiptItemRow(
                item: item,
                session: box.session,
                fontSize: rowSize,
                verticalPadding: 2.5 * scale,
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
                              Text.rich(
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111820),
                                  height: 1.2,
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
                    Text(
                      marketTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF111820),
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    const _PreviewRule(),
                    SizedBox(height: 5 * scale),
                    Padding(
                      padding: EdgeInsets.fromLTRB(5 * scale, 0, 5 * scale, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _BoxText(
                              context.tr('NUMBER'),
                              fontSize: headerSize,
                              color: const Color(0xFF111820),
                              weight: FontWeight.w900,
                            ),
                          ),
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
                    Row(
                      children: [
                        Expanded(
                          child: _BoxText(
                            context.tr('TOTAL'),
                            fontSize: headerSize,
                            color: const Color(0xFF111820),
                            weight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(
                          width: amountColumnWidth,
                          child: _BoxText(
                            AppLocalizations.localizeDigits(
                              _formatAmount(totalAmount),
                            ),
                            textAlign: TextAlign.right,
                            fontSize: headerSize,
                            color: const Color(0xFF111820),
                            weight: FontWeight.w900,
                          ),
                        ),
                      ],
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

class _ShareReceiptItemRow extends StatelessWidget {
  const _ShareReceiptItemRow({
    required this.item,
    required this.session,
    required this.fontSize,
    required this.verticalPadding,
    required this.amountColumnWidth,
  });

  final ShareRecordItem item;
  final String session;
  final double fontSize;
  final double verticalPadding;
  final double amountColumnWidth;

  @override
  Widget build(BuildContext context) {
    final visibleJackpotEntries = item.isJackpot
        ? item.jackpotEntries.where(
            (entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty,
          )
        : const Iterable<ShareRecordJackpotEntry>.empty();
    final topLabel = !item.showMainEntry
        ? null
        : item.isBazarSangam
            ? 'BAZAR'
            : item.isMotorPana
                ? 'MP'
                : null;
    final numberText = _formatShareReceiptNumber(item, session);
    final numberParts = NumberDisplayParts.fromDisplay(numberText);
    final numberTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: 0,
    );
    final labelTextStyle = _receiptAlphabetTextStyle(fontSize);
    final jackpotTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
    );
    final jackpotArrowStyle = jackpotTextStyle.copyWith(
      fontSize: fontSize * 1.45,
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
                    if (topLabel != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: verticalPadding),
                        child: Text(
                          context.trMaybe(topLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _receiptAlphabetTextStyle(fontSize),
                        ),
                      ),
                    if (item.showMainEntry)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
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
                              overflow: TextOverflow.ellipsis,
                              style: numberTextStyle,
                            ),
                          ),
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
                    for (final entry in visibleJackpotEntries)
                      Padding(
                        padding: EdgeInsets.only(top: verticalPadding),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
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
                            SizedBox(
                              width: amountColumnWidth,
                              child: _BoxText(
                                AppLocalizations.localizeDigits(entry.amount),
                                textAlign: TextAlign.right,
                                fontSize: fontSize,
                                color: const Color(0xFF111820),
                                weight: FontWeight.w900,
                              ),
                            ),
                          ],
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
    if (item.isFamily) {
      formattedNumber = _familyNumberWithSuffix(formattedNumber);
    }
    formattedNumber = '$formattedNumber >';
  } else if (normalizedSession == 'close') {
    if (item.isFamily) {
      formattedNumber = _familyNumberWithSuffix(formattedNumber);
    }
    formattedNumber = '> $formattedNumber';
  } else if (item.isFamily) {
    formattedNumber = _familyNumberWithSuffix(formattedNumber);
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
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
