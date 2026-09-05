import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matka_management/features/share_records/data/share_records_models.dart';
import 'package:matka_management/features/share_records/domain/share_records_chunker.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  await initializeDateFormatting('hi');
  await initializeDateFormatting('mr');

  group('ShareRecordsChunker Unit Tests', () {
    test('1 receipt with 1 bet produces 1 box and 1 page', () {
      final record = ShareRecordEntry(
        receiptId: 'r1',
        receiptNumber: 'RC-1001',
        customerName: 'RAJU BHAI',
        market: const ShareRecordMarket(id: 'm1', name: 'KALYAN', code: 'KL'),
        session: 'OPEN',
        operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
        createdAt: DateTime.now(),
        date: DateTime.now(),
        totalAmount: 100,
        totalItems: 1,
        items: const [
          ShareRecordItem(id: 'i1', type: 'Single', number: '04', amount: 100),
        ],
      );

      final boxes = ShareRecordsChunker.buildBoxes([record]);
      expect(boxes.length, 1);
      expect(boxes[0].sequenceNumber, 1);
      expect(boxes[0].displayName, 'RAJU BHAI');
      expect(boxes[0].totalParts, 1);
      expect(boxes[0].totalReceiptAmount, 100);

      final pages = ShareRecordsChunker.buildPages(
        records: [record],
        filterDate: DateTime.now(),
        marketName: 'KALYAN',
        sessionName: 'OPEN',
      );
      expect(pages.length, 1);
      expect(pages[0].totalPeople, 1);
      expect(pages[0].totalAmount, 100);
      expect(pages[0].boxes.length, 1);
    });

    test('BZ display amount stays separate from calculated totals', () {
      final item = ShareRecordItem.fromJson(const {
        '_id': 'i1',
        'type': 'Full Sangam',
        'number': '118-128',
        'amount': 10,
        'components': {
          'bazar': true,
          'displayAmount': '1',
        },
      });
      final record = ShareRecordEntry(
        receiptId: 'r1',
        receiptNumber: 'RC-1001',
        customerName: 'RAJU BHAI',
        market: const ShareRecordMarket(id: 'm1', name: 'KALYAN', code: 'KL'),
        session: 'OPEN',
        operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
        createdAt: DateTime.now(),
        date: DateTime.now(),
        totalAmount: 10,
        totalItems: 1,
        items: [item],
      );

      final box = ShareRecordsChunker.buildBoxes([record]).single;

      expect(item.effectiveDisplayAmount, '1');
      expect(item.amountText, '10');
      expect(item.isBazarSangam, true);
      expect(box.boxSubtotal, 10);
      expect(box.totalReceiptAmount, 10);
    });

    test(
        '1 receipt with 15 bets chunks into 2 boxes without double-counting people in summary',
        () {
      final items = List.generate(
        15,
        (index) => ShareRecordItem(
          id: 'item_$index',
          type: 'Single',
          number: (index + 1).toString().padLeft(2, '0'),
          amount: 10,
        ),
      );

      final record = ShareRecordEntry(
        receiptId: 'r2',
        receiptNumber: 'RC-1002',
        customerName: 'SURESH',
        market: const ShareRecordMarket(id: 'm1', name: 'KALYAN', code: 'KL'),
        session: 'OPEN',
        operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
        createdAt: DateTime.now(),
        date: DateTime.now(),
        totalAmount: 150,
        totalItems: 15,
        items: items,
      );

      final boxes = ShareRecordsChunker.buildBoxes([record]);
      expect(boxes.length, 2);

      // Box 1: first 10 items from the same receipt.
      expect(boxes[0].sequenceNumber, 1);
      expect(boxes[0].partIndex, 1);
      expect(boxes[0].totalParts, 2);
      expect(boxes[0].items.length, 10);
      expect(boxes[0].totalReceiptAmount, 150);
      expect(boxes[0].isContinuation, false);

      // Box 2: continuation keeps the same receipt total.
      expect(boxes[1].sequenceNumber, 2);
      expect(boxes[1].partIndex, 2);
      expect(boxes[1].totalParts, 2);
      expect(boxes[1].items.length, 5);
      expect(boxes[1].receiptNumber, 'RC-1002');
      expect(boxes[1].totalReceiptAmount, 150);
      expect(boxes[1].isContinuation, true);

      final pages = ShareRecordsChunker.buildPages(
        records: [record],
        filterDate: DateTime.now(),
        marketName: 'KALYAN',
        sessionName: 'OPEN',
      );

      expect(pages.length, 1); // 2 boxes fit in 1 page (max 10 boxes per page)
      expect(pages[0].totalPeople, 1); // Only 1 person!
      expect(pages[0].totalAmount, 150);
    });

    test('15 single-item receipts paginate into 2 A4 pages (10 and 5 boxes)',
        () {
      final records = List.generate(
        15,
        (i) => ShareRecordEntry(
          receiptId: 'rec_$i',
          receiptNumber: 'RC-${1000 + i}',
          customerName: 'Customer ${i + 1}',
          market: const ShareRecordMarket(id: 'm1', name: 'KALYAN', code: 'KL'),
          session: 'OPEN',
          operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
          createdAt: DateTime.now(),
          date: DateTime.now(),
          totalAmount: 50,
          totalItems: 1,
          items: [
            ShareRecordItem(
                id: 'item_$i', type: 'Single', number: '07', amount: 50),
          ],
        ),
      );

      final pages = ShareRecordsChunker.buildPages(
        records: records,
        filterDate: DateTime.now(),
        marketName: 'KALYAN',
        sessionName: 'OPEN',
      );

      expect(pages.length, 2);
      expect(pages[0].pageNumber, 1);
      expect(pages[0].totalPages, 2);
      expect(pages[0].boxes.length, 10);
      expect(pages[1].boxes.length, 5);

      expect(pages[0].totalPeople, 15);
      expect(pages[0].totalAmount, 750);
    });

    test('21 single-item receipts paginate into 3 pages (10, 10 and 1 boxes)',
        () {
      final records = List.generate(
        21,
        (i) => ShareRecordEntry(
          receiptId: 'rec_$i',
          receiptNumber: 'RC-${1000 + i}',
          customerName: 'Customer ${i + 1}',
          market: const ShareRecordMarket(id: 'm1', name: 'KALYAN', code: 'KL'),
          session: 'OPEN',
          operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
          createdAt: DateTime.now(),
          date: DateTime.now(),
          totalAmount: 50,
          totalItems: 1,
          items: [
            ShareRecordItem(
                id: 'item_$i', type: 'Single', number: '07', amount: 50),
          ],
        ),
      );

      final pages = ShareRecordsChunker.buildPages(
        records: records,
        filterDate: DateTime(2026, 8, 24),
        marketName: 'KALYAN',
        sessionName: 'OPEN',
      );

      expect(pages.length, 3);
      expect(pages[0].boxes.length, 10);
      expect(pages[1].boxes.length, 10);
      expect(pages[2].boxes.length, 1);
      expect(pages[0].totalPeople, 21);
      expect(pages[0].totalAmount, 1050);
      expect(pages[0].dateStr, '24-08-2026 (Monday)');
    });

    test('MP label does not consume an extra entry slot', () {
      final items = <ShareRecordItem>[
        for (var i = 0; i < 9; i++)
          ShareRecordItem(
            id: 'single_$i',
            type: 'Single',
            number: '$i',
            amount: 10,
          ),
        const ShareRecordItem(
          id: 'mp',
          type: 'SP Motor',
          number: '123456',
          amount: 10,
        ),
      ];

      final record = ShareRecordEntry(
        receiptId: 'r3',
        receiptNumber: 'RC-20260826-000123',
        customerName: 'LONG TEST',
        market:
            const ShareRecordMarket(id: 'm1', name: 'KALYAN DAY', code: 'KD'),
        session: 'OPEN',
        operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
        createdAt: DateTime.now(),
        date: DateTime.now(),
        totalAmount: 100,
        totalItems: items.length,
        items: items,
      );

      final boxes = ShareRecordsChunker.buildBoxes([record]);

      expect(boxes.length, 1);
      expect(boxes[0].items.length, 10);
      expect(boxes[0].items.last.id, 'mp');
      expect(boxes[0].receiptNumber, 'RC-20260826-000123');
    });

    test('BAZAR label does not consume an extra entry slot', () {
      final items = <ShareRecordItem>[
        for (var i = 0; i < 9; i++)
          ShareRecordItem(
            id: 'single_$i',
            type: 'Single',
            number: '$i',
            amount: 10,
          ),
        const ShareRecordItem(
          id: 'bazar',
          type: 'Full Sangam',
          number: '123-456',
          amount: 10,
          isBazarSangam: true,
        ),
      ];

      final record = ShareRecordEntry(
        receiptId: 'r-bazar',
        receiptNumber: 'RC-BAZAR',
        customerName: 'BAZAR TEST',
        market:
            const ShareRecordMarket(id: 'm1', name: 'KALYAN DAY', code: 'KD'),
        session: 'OPEN',
        operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
        createdAt: DateTime.now(),
        date: DateTime.now(),
        totalAmount: 100,
        totalItems: items.length,
        items: items,
      );

      final boxes = ShareRecordsChunker.buildBoxes([record]);

      expect(boxes.length, 1);
      expect(boxes.single.items.length, 10);
      expect(boxes.single.items.last.isBazarSangam, true);
    });

    test('jackpot visual lines continue with the same saved receipt number',
        () {
      final jackpot = ShareRecordItem(
        id: 'jp',
        type: 'Single',
        number: '12',
        amount: 130,
        isJackpot: true,
        jackpotEntries: [
          for (var i = 0; i < 12; i++)
            ShareRecordJackpotEntry(number: '$i', amount: '10'),
        ],
      );
      final record = ShareRecordEntry(
        receiptId: 'r4',
        receiptNumber: 'KD01',
        customerName: 'JACKPOT TEST',
        market:
            const ShareRecordMarket(id: 'm1', name: 'KALYAN DAY', code: 'KD'),
        session: 'OPEN',
        operator: const ShareRecordOperator(id: 'o1', name: 'OPERATOR 01'),
        createdAt: DateTime.now(),
        date: DateTime.now(),
        totalAmount: 130,
        totalItems: 1,
        items: [jackpot],
      );

      final boxes = ShareRecordsChunker.buildBoxes([record]);

      expect(boxes.length, 2);
      expect(boxes[0].receiptNumber, 'KD01');
      expect(boxes[1].receiptNumber, 'KD01');
      expect(boxes[0].items.single.jackpotEntries.length, 9);
      expect(boxes[1].items.single.showMainEntry, false);
      expect(boxes[1].items.single.jackpotEntries.length, 3);
    });
  });
}
