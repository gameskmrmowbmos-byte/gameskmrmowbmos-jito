import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/presentation/parchi_render_model.dart';
import 'package:matka_management/shared/widgets/aligned_jackpot_marker.dart';

const _entryGreen = Color(0xFF108438);
const _receiptAlphabetShadow = <Shadow>[
  Shadow(color: Colors.black, offset: Offset(0.18, 0), blurRadius: 0),
];
const _receiptGreenAlphabetShadow = <Shadow>[
  Shadow(color: _entryGreen, offset: Offset(0.18, 0), blurRadius: 0),
];
const _parchiIndicFontFallback = <String>[
  'Noto Sans Devanagari',
  'Nirmala UI',
  'Mangal',
];

class ParchiReceiptPreview extends StatelessWidget {
  const ParchiReceiptPreview({
    required this.detail,
    this.overrideParchiNo,
    this.compact = false,
    super.key,
  });

  final ReceiptDetail detail;
  final String? overrideParchiNo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final model = buildParchiRenderModel(
      detail,
      overrideParchiNo: overrideParchiNo,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var pageIndex = 0; pageIndex < model.pages.length; pageIndex++)
            Padding(
              padding: EdgeInsets.only(
                bottom: pageIndex == model.pages.length - 1
                    ? 0
                    : compact
                        ? 12
                        : 18,
              ),
              child: ParchiTicketWidget(
                model: model,
                page: model.pages[pageIndex],
                compact: compact,
              ),
            ),
        ],
      ),
    );
  }
}

class ParchiTicketWidget extends StatelessWidget {
  const ParchiTicketWidget({
    required this.model,
    required this.page,
    this.compact = false,
    super.key,
  });

  final ParchiRenderModel model;
  final ParchiRenderPage page;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isIndic = _isIndicParchiLanguage(context);
    final amountTotal = AppLocalizations.localizeDigits(
      formatParchiAmount(page.totalAmount),
    );
    final columnMetrics = _parchiColumnMetrics(
      context,
      page.lines,
      amountTotal,
      compact,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 220 : 230),
      child: CustomPaint(
        painter: const ParchiReceiptBorderPainter(),
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
                                  fontSize: compact
                                      ? isIndic
                                          ? 11
                                          : 10
                                      : isIndic
                                          ? 13
                                          : 12,
                                  fontWeight: isIndic
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                  height: isIndic ? 1.25 : null,
                                  fontFamilyFallback:
                                      _parchiFontFallback(isIndic),
                                ),
                              ),
                              TextSpan(
                                text: AppLocalizations.localizeDigits(
                                  page.parchiNo,
                                ),
                                style: TextStyle(
                                  fontSize: compact ? 11 : 13,
                                  fontWeight: isIndic
                                      ? FontWeight.w800
                                      : FontWeight.w900,
                                  height: isIndic ? 1.2 : null,
                                  fontFamilyFallback:
                                      _parchiFontFallback(isIndic),
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
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocalizations.localizeDigits(
                          formatParchiDate(model.date),
                        ),
                        style: TextStyle(
                          color: const Color(0xFF111820),
                          fontSize: compact
                              ? isIndic
                                  ? 11
                                  : 10
                              : isIndic
                                  ? 12
                                  : 11,
                          fontWeight:
                              isIndic ? FontWeight.w700 : FontWeight.w800,
                          height: isIndic ? 1.25 : null,
                          fontFamilyFallback: _parchiFontFallback(isIndic),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.localizeDigits(
                          formatParchiTime(model.date),
                        ),
                        style: TextStyle(
                          color: const Color(0xFF111820),
                          fontSize: compact
                              ? isIndic
                                  ? 11
                                  : 10
                              : isIndic
                                  ? 12
                                  : 11,
                          fontWeight:
                              isIndic ? FontWeight.w700 : FontWeight.w800,
                          height: isIndic ? 1.25 : null,
                          fontFamilyFallback: _parchiFontFallback(isIndic),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                AppLocalizations.localizeMarketName(model.marketName),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF111820),
                  fontSize: compact
                      ? isIndic
                          ? 15
                          : 16
                      : isIndic
                          ? 17
                          : 18,
                  fontWeight: isIndic ? FontWeight.w800 : FontWeight.w900,
                  height: isIndic ? 1.25 : null,
                  fontFamilyFallback: _parchiFontFallback(isIndic),
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              const _ParchiRule(),
              SizedBox(height: compact ? 8 : 10),
              _ParchiHeader(compact: compact, metrics: columnMetrics),
              for (final line in page.lines)
                _ParchiItemRow(
                  line: line,
                  compact: compact,
                  metrics: columnMetrics,
                ),
              if (page.lines.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 10),
                if (page.isOtc) ...[
                  Text(
                    'OTC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _entryGreen,
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      shadows: _receiptGreenAlphabetShadow,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                ],
                const _ParchiRule(),
                const SizedBox(height: 12),
                _ParchiTotalRow(
                  amount: amountTotal,
                  compact: compact,
                  metrics: columnMetrics,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Please check the receipt. No complaints will be accepted later.',
                  ),
                  maxLines: isIndic ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF111820),
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w900,
                    height: isIndic ? 1.25 : 1.1,
                    fontFamilyFallback: _parchiFontFallback(isIndic),
                  ),
                ),
              ] else ...[
                SizedBox(height: compact ? 36 : 48),
                const _ParchiRule(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _isIndicParchiLanguage(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return code == AppLanguage.hindi.code || code == AppLanguage.marathi.code;
}

List<String>? _parchiFontFallback(bool isIndic) {
  return isIndic ? _parchiIndicFontFallback : null;
}

class _ParchiHeader extends StatelessWidget {
  const _ParchiHeader({required this.compact, required this.metrics});

  final bool compact;
  final _ParchiColumnMetrics metrics;

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
                style: _parchiHeaderTextStyle(compact),
              ),
            ),
            SizedBox(width: metrics.gap),
            SizedBox(
              width: metrics.amountWidth,
              child: Text(
                context.tr('AMT'),
                textAlign: TextAlign.right,
                style: _parchiHeaderTextStyle(compact),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParchiItemRow extends StatelessWidget {
  const _ParchiItemRow({
    required this.line,
    required this.compact,
    required this.metrics,
  });

  final ParchiRenderLine line;
  final bool compact;
  final _ParchiColumnMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final numberParts = NumberDisplayParts.fromDisplay(line.number);
    final numberTextStyle = _parchiNumberTextStyle(compact);
    final labelTextStyle = _parchiLabelTextStyle(compact);
    final amountTextStyle = _parchiAmountTextStyle(compact);
    final jackpotTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: compact ? 9 : 11,
      fontWeight: FontWeight.w500,
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
          if (line.topLabel != null)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 2 : 3),
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: metrics.totalWidth,
                  child: Text(
                    context.trMaybe(line.topLabel!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelTextStyle,
                  ),
                ),
              ),
            ),
          if (line.showMainEntry)
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
                        _parchiNumberSpan(
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
                      AppLocalizations.localizeDigits(line.amount),
                      textAlign: TextAlign.right,
                      style: amountTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          for (final entry in line.jackpotEntries)
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
                        parentText: line.number,
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
                        style: jackpotTextStyle,
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

class _ParchiColumnMetrics {
  const _ParchiColumnMetrics({
    required this.numberWidth,
    required this.amountWidth,
    required this.gap,
  });

  final double numberWidth;
  final double amountWidth;
  final double gap;

  double get totalWidth => numberWidth + gap + amountWidth;
}

_ParchiColumnMetrics _parchiColumnMetrics(
  BuildContext context,
  List<ParchiRenderLine> lines,
  String totalAmount,
  bool compact,
) {
  final gap = _parchiColumnGap(compact);
  final headerStyle = _parchiHeaderTextStyle(compact);
  final numberStyle = _parchiNumberTextStyle(compact);
  final labelStyle = _parchiLabelTextStyle(compact);
  final amountStyle = _parchiAmountTextStyle(compact);
  final jackpotStyle = _parchiJackpotTextStyle(compact);
  var numberWidth = _measureText(context.tr('NUMBER'), headerStyle, context);
  var amountWidth = _measureText(context.tr('AMT'), headerStyle, context);
  numberWidth = math.max(
    numberWidth,
    _measureText('12345678 >', numberStyle, context),
  );
  numberWidth = math.max(
    numberWidth,
    _measureText(context.tr('TOTAL'), _parchiTotalTextStyle(compact), context),
  );
  amountWidth = math.max(
    amountWidth,
    _measureText(totalAmount, _parchiTotalAmountTextStyle(compact), context),
  );

  for (final line in lines) {
    if (line.showMainEntry) {
      final parts = NumberDisplayParts.fromDisplay(line.number);
      numberWidth = math.max(
        numberWidth,
        _measureTextSpan(
          _parchiNumberSpan(parts, numberStyle, labelStyle),
          context,
        ),
      );
      amountWidth = math.max(
        amountWidth,
        _measureText(
          AppLocalizations.localizeDigits(line.amount),
          amountStyle,
          context,
        ),
      );
    }
    for (final entry in line.jackpotEntries) {
      numberWidth = math.max(
        numberWidth,
        _measureText(line.number.trimRight(), numberStyle, context),
      );
      amountWidth = math.max(
        amountWidth,
        _measureText(
          AppLocalizations.localizeDigits(entry.amount),
          jackpotStyle,
          context,
        ),
      );
    }
  }

  final maxNumberWidth =
      math.max(1.0, _parchiMaxRowWidth(compact) - gap - amountWidth);
  return _ParchiColumnMetrics(
    numberWidth: math.min(numberWidth, maxNumberWidth),
    amountWidth: amountWidth,
    gap: gap,
  );
}

TextSpan _parchiNumberSpan(
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

TextStyle _parchiHeaderTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 10 : 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

TextStyle _parchiNumberTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 9 : 11,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );
}

TextStyle _parchiLabelTextStyle(bool compact) {
  return _parchiNumberTextStyle(compact).copyWith(
    color: Colors.black,
    fontWeight: FontWeight.w900,
    shadows: _receiptAlphabetShadow,
  );
}

TextStyle _parchiAmountTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 9 : 11,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );
}

TextStyle _parchiJackpotTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 9 : 11,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );
}

TextStyle _parchiTotalTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 12 : 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

TextStyle _parchiTotalAmountTextStyle(bool compact) {
  return TextStyle(
    color: const Color(0xFF111820),
    fontSize: compact ? 12 : 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
}

double _parchiColumnGap(bool compact) => compact ? 10 : 12;

double _parchiMaxRowWidth(bool compact) => compact ? 186 : 192;

double _measureText(String value, TextStyle style, BuildContext context) {
  return _measureTextSpan(TextSpan(text: value, style: style), context);
}

double _measureTextSpan(InlineSpan span, BuildContext context) {
  final painter = TextPainter(
    text: span,
    maxLines: 1,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  )..layout();
  return painter.width;
}

class _ParchiTotalRow extends StatelessWidget {
  const _ParchiTotalRow({
    required this.amount,
    required this.compact,
    required this.metrics,
  });

  final String amount;
  final bool compact;
  final _ParchiColumnMetrics metrics;

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
                style: _parchiTotalTextStyle(compact),
              ),
            ),
            SizedBox(width: metrics.gap),
            SizedBox(
              width: metrics.amountWidth,
              child: Text(
                amount,
                textAlign: TextAlign.right,
                style: _parchiTotalAmountTextStyle(compact),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParchiRule extends StatelessWidget {
  const _ParchiRule();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: const Color(0xFF111820));
  }
}

class ParchiReceiptBorderPainter extends CustomPainter {
  const ParchiReceiptBorderPainter();

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
