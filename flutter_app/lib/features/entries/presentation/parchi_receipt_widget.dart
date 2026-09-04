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
    final amountTotal = AppLocalizations.localizeDigits(
      formatParchiAmount(page.totalAmount),
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
                                  fontSize: compact ? 10 : 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: AppLocalizations.localizeDigits(
                                  page.parchiNo,
                                ),
                                style: TextStyle(
                                  fontSize: compact ? 11 : 13,
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
                        SizedBox(height: compact ? 2 : 3),
                        Text(
                          context.trMaybe(model.session),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          formatParchiDate(model.date),
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
                          formatParchiTime(model.date),
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
                AppLocalizations.localizeMarketName(model.marketName),
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
              const _ParchiRule(),
              SizedBox(height: compact ? 8 : 10),
              _ParchiHeader(compact: compact),
              for (final line in page.lines)
                _ParchiItemRow(line: line, compact: compact),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('TOTAL'),
                        style: const TextStyle(
                          color: Color(0xFF111820),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      amountTotal,
                      style: TextStyle(
                        color: const Color(0xFF111820),
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
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

class _ParchiHeader extends StatelessWidget {
  const _ParchiHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(7, 0, 7, compact ? 6 : 8),
      child: Row(
        children: [
          Text(
            context.tr('NUMBER'),
            style: TextStyle(
              color: const Color(0xFF111820),
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          Text(
            context.tr('AMT'),
            style: TextStyle(
              color: const Color(0xFF111820),
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParchiItemRow extends StatelessWidget {
  const _ParchiItemRow({required this.line, required this.compact});

  final ParchiRenderLine line;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final numberParts = NumberDisplayParts.fromDisplay(line.number);
    final numberTextStyle = TextStyle(
      color: const Color(0xFF111820),
      fontSize: compact ? 9 : 11,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: 0,
    );
    final labelTextStyle = numberTextStyle.copyWith(
      color: Colors.black,
      fontWeight: FontWeight.w900,
      shadows: _receiptAlphabetShadow,
    );
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
          if (line.topLabel != null)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 2 : 3),
              child: Text(
                context.trMaybe(line.topLabel!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelTextStyle,
              ),
            ),
          if (line.showMainEntry)
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
                Text(
                  AppLocalizations.localizeDigits(line.amount),
                  textAlign: TextAlign.right,
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
          for (final entry in line.jackpotEntries)
            Padding(
              padding: EdgeInsets.only(top: compact ? 2 : 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
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
                  Text(
                    AppLocalizations.localizeDigits(entry.amount),
                    textAlign: TextAlign.right,
                    style: jackpotTextStyle,
                  ),
                ],
              ),
            ),
        ],
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
