import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/printed_receipts/services/escpos_receipt_builder.dart';

void main() {
  group('receipt page totals', () {
    test('split receipts keep their own total on each page', () {
      final items = List.generate(
        11,
        (index) => ReceiptItemModel(
          id: 'item_$index',
          type: 'Single',
          number: (index + 1).toString().padLeft(2, '0'),
          amount: 100,
        ),
      );

      final totals = computeReceiptPageTotals(items, isOtc: false);

      expect(totals.length, 2);
      expect(totals[0], 1000);
      expect(totals[1], 100);
    });
  });
}
