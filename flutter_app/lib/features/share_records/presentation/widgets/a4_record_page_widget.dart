import 'package:flutter/material.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/share_records/data/share_records_models.dart';
import 'package:matka_management/features/share_records/presentation/widgets/record_box_widget.dart';

class A4RecordPageWidget extends StatelessWidget {
  const A4RecordPageWidget({
    required this.pageData,
    this.width = exportWidth,
    this.ownerName,
    super.key,
  });

  static const double exportWidth = 2200.0;
  static const int columnsPerRow = 4;
  static const int rowsPerPage = 2;

  final A4RecordPageData pageData;
  final double width;
  final String? ownerName;

  double get height => width / 1.414;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.012),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Title
          Text(
            context.tr('MATKA ENTRY SYSTEM - TODAY\'S BET RECORDS'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF064DB5),
              fontSize: width * 0.016,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: width * 0.006),

          // Header Info Columns
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.015,
              vertical: width * 0.006,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Col 1: Filters
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(
                        label: 'DATE',
                        value:
                            AppLocalizations.localizeDigits(pageData.dateStr),
                        fontSize: width * 0.011,
                      ),
                      _HeaderRow(
                        label: 'MARKET',
                        value: AppLocalizations.localizeMarketName(
                          pageData.marketName,
                        ),
                        fontSize: width * 0.011,
                      ),
                      _HeaderRow(
                        label: 'SESSION',
                        value: pageData.sessionName,
                        fontSize: width * 0.011,
                      ),
                    ],
                  ),
                ),
                // Col 2: Totals
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(
                        label: 'TOTAL PEOPLE',
                        value: AppLocalizations.localizeDigits(
                          '${pageData.totalPeople}',
                        ),
                        fontSize: width * 0.011,
                      ),
                      _HeaderRow(
                        label: 'TOTAL AMOUNT',
                        value: AppLocalizations.localizeDigits(
                          '\u20B9 ${pageData.totalAmountText}',
                        ),
                        valueColor: const Color(0xFF16A34A),
                        fontSize: width * 0.011,
                      ),
                    ],
                  ),
                ),
                // Col 3: Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(
                        label: 'TIME',
                        value: pageData.timeStr,
                        fontSize: width * 0.011,
                      ),
                      _HeaderRow(
                        label: 'OPERATOR',
                        value: pageData.operatorName,
                        fontSize: width * 0.011,
                      ),
                      _HeaderRow(
                        label: 'PAGE',
                        value: context.tr(
                          'PAGE {page} OF {total}',
                          params: {
                            'page': pageData.pageNumber,
                            'total': pageData.totalPages,
                          },
                        ),
                        fontSize: width * 0.011,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: width * 0.008),

          // Main 2x4 grid (8 fixed receipt columns)
          Expanded(
            child: Column(
              children: [
                for (int row = 0; row < rowsPerPage; row++) ...[
                  Expanded(
                    child: Row(
                      children: [
                        for (int column = 0;
                            column < columnsPerRow;
                            column++) ...[
                          Expanded(
                            child: _boxForIndex(row * columnsPerRow + column),
                          ),
                          if (column < columnsPerRow - 1)
                            SizedBox(width: width * 0.0025),
                        ],
                      ],
                    ),
                  ),
                  if (row < rowsPerPage - 1) SizedBox(height: width * 0.004),
                ],
              ],
            ),
          ),
          SizedBox(height: width * 0.005),

          // Footer Section
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          SizedBox(height: width * 0.003),
          Row(
            children: [
              Expanded(
                child: _A4FittedText(
                  context.tr('Generated By: Matka Entry System'),
                  fontSize: width * 0.011,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: _A4FittedText(
                  context.tr('This is a computer generated report.'),
                  textAlign: TextAlign.center,
                  fontSize: width * 0.011,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: _A4FittedText(
                  context.tr(
                    'Printed On: {date} {time}',
                    params: {
                      'date': pageData.dateStr,
                      'time': pageData.timeStr,
                    },
                  ),
                  textAlign: TextAlign.right,
                  fontSize: width * 0.011,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boxForIndex(int index) {
    if (index >= pageData.boxes.length) return const SizedBox.expand();
    return RecordBoxWidget(
      box: pageData.boxes[index],
      ownerName: ownerName,
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.label,
    required this.value,
    required this.fontSize,
    this.valueColor,
  });

  final String label;
  final String value;
  final double fontSize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          SizedBox(
            width: fontSize * 9,
            child: Text(
              context.trMaybe(label),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF475569),
            ),
          ),
          Expanded(
            child: _A4FittedText(
              context.trMaybe(value),
              fontSize: fontSize,
              color: valueColor ?? const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _A4FittedText extends StatelessWidget {
  const _A4FittedText(
    this.text, {
    required this.fontSize,
    required this.color,
    required this.fontWeight,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.right
          ? Alignment.centerRight
          : textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}
