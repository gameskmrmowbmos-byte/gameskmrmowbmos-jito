import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/data/receipt_repository.dart';
import 'package:matka_management/features/new_entry/data/game_config_models.dart';
import 'package:matka_management/features/new_entry/data/game_config_repository.dart';
import 'package:matka_management/features/printed_receipts/data/print_repository.dart';
import 'package:matka_management/features/printed_receipts/services/customer_parchi_printer.dart';

final newEntryControllerProvider =
    AsyncNotifierProvider.autoDispose<NewEntryController, NewEntryData>(
  NewEntryController.new,
);

class NewEntryController extends AutoDisposeAsyncNotifier<NewEntryData> {
  @override
  Future<NewEntryData> build() async {
    return _fetchData();
  }

  Future<NewEntryData> _fetchData({String? marketId}) async {
    final markets = await ref.read(receiptRepositoryProvider).getMarkets();
    final selectedMarketId =
        marketId ?? (markets.isEmpty ? null : markets.first.id);
    final gameConfig = selectedMarketId == null
        ? null
        : await ref
            .read(gameConfigRepositoryProvider)
            .getCurrentConfig(selectedMarketId);
    return NewEntryData(
      markets: markets,
      gameConfig: gameConfig,
      gameConfigMarketId: selectedMarketId,
    );
  }

  Future<void> loadGameConfigForMarket(String marketId) async {
    final current = state.valueOrNull;
    if (current?.gameConfigMarketId == marketId) return;
    if (current == null) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchData(marketId: marketId));
      return;
    }
    final previous = current;
    state = AsyncData(
      NewEntryData(
        markets: previous.markets,
        gameConfig: previous.gameConfig,
        gameConfigMarketId: previous.gameConfigMarketId,
      ),
    );
    try {
      final nextConfig = await ref
          .read(gameConfigRepositoryProvider)
          .getCurrentConfig(marketId);
      state = AsyncData(
        NewEntryData(
          markets: previous.markets,
          gameConfig: nextConfig,
          gameConfigMarketId: marketId,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<ReceiptDetail?> saveReceipt({
    required String market,
    String? marketName,
    required String session,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? customerMobile,
    String? notes,
    bool isOtc = false,
    required bool shouldPrint,
    String printerName = 'POS-58',
    String? overrideParchiNo,
  }) async {
    final printSession = shouldPrint ? prepareCustomerParchiPrint() : null;
    final previousData = state.valueOrNull;

    try {
      state = const AsyncLoading();

      final repo = ref.read(receiptRepositoryProvider);
      final receipt = await repo.createReceipt(
        market: market,
        session: session,
        items: items,
        customerName: customerName,
        customerMobile: customerMobile,
        notes: notes,
        isOtc: isOtc,
      );

      if (shouldPrint) {
        Object? printError;
        var printed = false;
        try {
          await printSession?.printReceipt(
            receipt,
            overrideParchiNo: overrideParchiNo,
            marketName: marketName,
            ownerName: ref.read(authProvider).user?.ownerName,
          );
          printed = true;
        } on Object catch (error) {
          printError = error;
        }

        try {
          final printRepo = ref.read(printRepositoryProvider);
          await printRepo.createOriginalPrint(
            receiptId: receipt.receipt.id,
            printerName: printerName,
            status: printed ? 'Success' : 'Failed',
            errorMessage: printError?.toString(),
          );
        } catch (e) {
          // Print errors shouldn't fail the save, but could be logged or returned in a result wrapper
        }
      }

      try {
        state = AsyncData(await _fetchData(marketId: market));
      } catch (refreshError, refreshStack) {
        if (previousData != null) {
          state = AsyncData(previousData);
        } else {
          state = AsyncError(refreshError, refreshStack);
        }
      }
      return receipt;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
