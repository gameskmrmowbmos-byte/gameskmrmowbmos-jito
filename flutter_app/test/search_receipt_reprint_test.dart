import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/storage/secure_storage_service.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/data/receipt_repository.dart';
import 'package:matka_management/features/receipt_search/presentation/search_receipt_controller.dart';
import 'package:matka_management/features/receipt_search/presentation/search_receipt_page.dart';

void main() {
  testWidgets(
    'reprint starts after its inline reason form has been removed',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _TestSearchReceiptController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchReceiptControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SearchReceiptPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Reprint Receipt'),
      );
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('inline-reprint-reason')),
        'Customer requested a copy',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Reprint'),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('inline-reprint-reason')), findsNothing);

      await tester.pumpAndSettle();

      expect(controller.reprintCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TestSearchReceiptController extends SearchReceiptController {
  _TestSearchReceiptController()
      : super(ReceiptRepository(ApiClient(SecureStorageService()))) {
    state = SearchReceiptState(detail: _receiptDetail);
  }

  int reprintCalls = 0;

  @override
  Future<void> reprint(String reason) async {
    reprintCalls++;
    state = state.copyWith(reprinting: true, clearError: true);
    await Future<void>.delayed(Duration.zero);
    state = state.copyWith(
      reprinting: false,
      message: 'Duplicate print recorded',
    );
  }
}

final _receiptDetail = ReceiptDetail(
  receipt: ReceiptSummary(
    id: 'receipt-1',
    receiptNumber: 'RC-010126-0001',
    date: DateTime(2026, 1, 1),
    market: const ReceiptMarket(id: 'market-1', name: 'Market', code: 'MKT'),
    session: 'Open',
    totalAmount: 100,
    totalItems: 1,
    operator: const ReceiptOperator(id: 'operator-1', name: 'Operator'),
    status: 'Active',
    printStatus: 'Success',
  ),
  items: const [
    ReceiptItemModel(id: 'item-1', type: 'Jodi', number: '12', amount: 100),
  ],
  printLogs: const [],
);
