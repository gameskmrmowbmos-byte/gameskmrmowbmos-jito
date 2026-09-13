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

    test('jackpot rows crossing the limit stay on the next page total', () {
      final items = [
        ...List.generate(
          9,
          (index) => ReceiptItemModel(
            id: 'item_$index',
            type: 'Single',
            number: (index + 1).toString().padLeft(2, '0'),
            amount: 100,
          ),
        ),
        const ReceiptItemModel(
          id: 'jackpot',
          type: 'Single',
          number: '99',
          amount: 300,
          isJackpot: true,
          jackpotEntries: [
            JackpotEntryModel(number: '01', amount: '100'),
            JackpotEntryModel(number: '02', amount: '100'),
            JackpotEntryModel(number: '03', amount: '100'),
          ],
        ),
      ];

      final totals = computeReceiptPageTotals(items, isOtc: false);

      expect(totals, [900, 300]);
    });

    test('family jackpot page totals use calculated jackpot amounts', () {
      final items = [
        ReceiptItemModel(
          id: 'family_jackpot',
          type: 'Patti',
          number: '123',
          amount: 260,
          betType: 'PANNA',
          betSubtype: 'family',
          isJackpot: true,
          isFamily: true,
          displayAmount: '10',
          jackpotEntries: List.generate(
            11,
            (index) => JackpotEntryModel(
              number: '${index % 10}',
              amount: '5',
              calculatedAmount: '20',
            ),
          ),
        ),
      ];

      final totals = computeReceiptPageTotals(items, isOtc: false);

      expect(totals, [220, 40]);
    });

    test('jackpot amount falls back to calculated amount from receipt json',
        () {
      final detail = ReceiptDetail.fromJson({
        'data': {
          'receipt': {
            '_id': 'receipt',
            'receiptNumber': 'R1',
            'session': 'Open',
          },
          'items': [
            {
              '_id': 'item',
              'type': 'Patti',
              'number': '123',
              'amount': 60,
              'isJackpot': true,
              'components': {
                'family': true,
                'displayAmount': '10',
                'jackpotEntries': [
                  {'number': '1', 'calculatedAmount': '20'},
                ],
              },
            },
          ],
        },
      });

      final entry = detail.items.single.jackpotEntries.single;

      expect(entry.amount, '20');
      expect(entry.displayAmount, '20');
      expect(entry.totalAmount, '20');
    });
  });
}
