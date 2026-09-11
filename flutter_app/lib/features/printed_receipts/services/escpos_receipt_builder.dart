import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

class EscPosReceiptBuilder {
  Future<List<int>> buildReceipt(
    ReceiptDetail detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final receipt = detail.receipt;
    final bytes = <int>[];
    final centeredBold = const PosStyles(align: PosAlign.center, bold: true);
    final parchi = canonicalParchiNumber(
      overrideParchiNo ?? receipt.receiptNumber,
    );

    bytes.addAll(generator.text('PARCHI NO. $parchi', styles: centeredBold));
    final createdAt = receipt.createdAt ?? receipt.date ?? DateTime.now();
    bytes.addAll(generator.text(
      '${DateFormat('dd/MM/yyyy').format(createdAt)} '
      '${DateFormat('hh:mm a').format(createdAt)}',
      styles: const PosStyles(align: PosAlign.right),
    ));
    if (ownerName?.trim().isNotEmpty == true) {
      bytes.addAll(generator.text(ownerName!.trim().toUpperCase(),
          styles: centeredBold));
    }
    final suppliedMarket = marketName?.trim();
    final storedMarket = receipt.market?.name.trim();
    final market = suppliedMarket?.isNotEmpty == true
        ? suppliedMarket!
        : storedMarket?.isNotEmpty == true
            ? storedMarket!
            : '-';
    bytes.addAll(generator.text(
      '${AppLocalizations.localizeMarketName(market.toUpperCase())} - '
      '${AppLocalizations.trCurrent(receipt.session.trim().toUpperCase())}',
      styles: centeredBold,
    ));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: AppLocalizations.trCurrent('NUMBER'), width: 8),
      PosColumn(
        text: AppLocalizations.trCurrent('AMT'),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    for (final item in detail.consolidatedItems) {
      if (item.isBazarSangam) {
        bytes.addAll(
            generator.text('BAZAR', styles: const PosStyles(bold: true)));
      } else if (item.isMotorPana) {
        bytes.addAll(generator.text('MP', styles: const PosStyles(bold: true)));
      }
      bytes.addAll(generator.row([
        PosColumn(
          text: AppLocalizations.localizeDigits(
            formatParchiNumber(item, item.sessionOverride ?? receipt.session),
          ),
          width: 8,
        ),
        PosColumn(
          text: AppLocalizations.localizeDigits(item.effectiveDisplayAmount),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      for (final jackpot in item.jackpotEntries) {
        bytes.addAll(generator.row([
          PosColumn(text: '->${jackpot.number} >', width: 8),
          PosColumn(
            text: jackpot.amount,
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));
      }
    }
    final total = detail.consolidatedItems.fold<num>(
          0,
          (sum, item) => sum + item.amount,
        ) *
        (receipt.isOtc ? 2 : 1);
    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: AppLocalizations.trCurrent('TOTAL'), width: 8),
      PosColumn(
        text: _formatAmount(total),
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));
    if (receipt.isOtc) {
      bytes.addAll(generator.text('OTC', styles: centeredBold));
    }
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> buildTestPrint(String printerName) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    return [
      ...generator.text(
        'TEST PRINT',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...generator.text(
        printerName,
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...generator.feed(3),
      ...generator.cut(),
    ];
  }

  String _formatAmount(num amount) =>
      amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
