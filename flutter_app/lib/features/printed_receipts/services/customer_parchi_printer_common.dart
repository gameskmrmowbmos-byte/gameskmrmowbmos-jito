import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

class CustomerParchiPrintSession {
  const CustomerParchiPrintSession();

  Future<void> printReceipt(ReceiptDetail detail,
      {String? overrideParchiNo}) async {
    throw UnsupportedError(
      AppLocalizations.trCurrent(
        'Customer parchi printing is supported in web builds only.',
      ),
    );
  }
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return const CustomerParchiPrintSession();
}
