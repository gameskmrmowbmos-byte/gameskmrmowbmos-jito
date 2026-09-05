import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

void main() {
  test('splits receipt numbers from their suffix labels and arrows', () {
    final cp = NumberDisplayParts.fromDisplay('12 CP >');
    expect(cp.beforeSuffix, '12');
    expect(cp.suffix, 'CP');
    expect(cp.trailingArrow, '>');

    final family = NumberDisplayParts.fromDisplay('> 45 F');
    expect(family.leadingArrow, '>');
    expect(family.beforeSuffix, '45');
    expect(family.suffix, 'F');

    final bazar = NumberDisplayParts.fromDisplay('BAZAR');
    expect(bazar.beforeSuffix, '');
    expect(bazar.suffix, 'BAZAR');

    final lowerCaseSp = NumberDisplayParts.fromDisplay('4sp >');
    expect(lowerCaseSp.beforeSuffix, '4');
    expect(lowerCaseSp.suffix, 'SP');
    expect(lowerCaseSp.trailingArrow, '>');

    final common = NumberDisplayParts.fromDisplay('5cm >');
    expect(common.beforeSuffix, '5');
    expect(common.suffix, 'COMMON');
    expect(common.trailingArrow, '>');
  });
}
