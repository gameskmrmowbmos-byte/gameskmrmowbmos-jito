import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/core/language/app_localizations.dart';

void main() {
  group('AppLocalizations receipt labels', () {
    test('Hindi should use Hindi strings for receipt labels', () {
      expect(AppLocalizations.translate(AppLanguage.hindi, 'Receipt'), 'रसीद');
      expect(AppLocalizations.translate(AppLanguage.hindi, 'OTC'), 'ओटीसी');
      expect(AppLocalizations.translate(AppLanguage.hindi, 'PARCHI NO.'),
          'पर्ची नं.');
    });

    test('Marathi should use Marathi strings for receipt labels', () {
      expect(
          AppLocalizations.translate(AppLanguage.marathi, 'Receipt'), 'पावती');
      expect(AppLocalizations.translate(AppLanguage.marathi, 'OTC'), 'ओटीसी');
      expect(AppLocalizations.translate(AppLanguage.marathi, 'PARCHI NO.'),
          'पर्ची नं.');
      expect(AppLocalizations.translate(AppLanguage.marathi, '1234567890'),
          '१२३४५६७८९०');
    });
  });
}
