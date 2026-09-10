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

    if (current?.gameConfigMarketId == marketId) {
      return;
    }

    if (current == null) {
      state = const AsyncLoading();

      state = await AsyncValue.guard(
        () => _fetchData(marketId: marketId),
      );

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
    String? printerName,
    String? overrideParchiNo,
  }) async {
    final printSession =
        shouldPrint ? prepareCustomerParchiPrint() : null;

    /*
     * Keep the currently loaded markets/configuration.
     *
     * We do NOT need to reload them after creating a receipt.
     */
    final currentData = state.valueOrNull;

    try {
      /*
       * Show loading while the receipt itself is being saved.
       */
      state = const AsyncLoading();

      final repo = ref.read(receiptRepositoryProvider);

      /*
       * SAVE RECEIPT
       */
      final receipt = await repo.createReceipt(
        market: market,
        session: session,
        items: items,
        customerName: customerName,
        customerMobile: customerMobile,
        notes: notes,
        isOtc: isOtc,
      );

      /*
       * PRINT RECEIPT
       *
       * We still WAIT for the actual printer operation.
       *
       * This guarantees that the receipt has been sent to the
       * printer before saveReceipt() finishes.
       */
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

        /*
         * Save print history in the background.
         *
         * IMPORTANT:
         *
         * We do NOT await this operation.
         *
         * The user should not have to wait for the print-history
         * API/database operation before entering the next receipt.
         */
        try {
          final printRepo = ref.read(printRepositoryProvider);

          final resolvedPrinterName = printerName ??
              await printSession?.activePrinterName ??
              'Unknown printer';

          Future<void>(() async {
            try {
              await printRepo.createOriginalPrint(
                receiptId: receipt.receipt.id,
                printerName: resolvedPrinterName,
                status: printed ? 'Success' : 'Failed',
                errorMessage: printError?.toString(),
              );
            } catch (_) {
              // Print-history failure must never block New Entry.
            }
          });
        } catch (_) {
          // Ignore print-history setup errors.
        }
      }

      /*
       * IMPORTANT:
       *
       * Do NOT call _fetchData() here.
       *
       * The market list and game configuration are already loaded.
       * Reloading them was causing the New Entry screen to remain
       * loading after the receipt had already printed.
       */
      if (currentData != null) {
        state = AsyncData(currentData);
      } else {
        /*
         * This is only a fallback in case the controller had no
         * existing data.
         */
        try {
          state = AsyncData(
            await _fetchData(marketId: market),
          );
        } catch (refreshError, refreshStack) {
          state = AsyncError(
            refreshError,
            refreshStack,
          );
        }
      }

      return receipt;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}