def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    old_save = '''  Future<void> _save({required bool print}) async {
    final market = _selectedMarket;
    if (market == null || !_canSave) return;

    final items = _receiptLines'''

    new_save = '''  Future<void> _save({required bool print}) async {
    final market = _selectedMarket;
    if (market == null || !_canSave) return;

    bool _isAscending(String numberString) {
      final parts = numberString.replaceAll('-', '*').replaceAll('>', '*').split('*');
      for (var part in parts) {
        final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
        for (int i = 0; i < digits.length - 1; i++) {
          int w1 = digits[i] == '0' ? 10 : int.parse(digits[i]);
          int w2 = digits[i + 1] == '0' ? 10 : int.parse(digits[i + 1]);
          if (w1 > w2) return false;
        }
      }
      return true;
    }

    if (!_isAutoMode) {
      for (final entry in _manualEntries) {
        final rawNumber = entry.number.text.trim();
        if (rawNumber.isNotEmpty && entry.amount.text.trim().isNotEmpty) {
          if (!_isAscending(rawNumber)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid Number: "$rawNumber". Digits must be in ascending order (0 is treated as 10).'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
    } else {
      if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
         final inputText = _autoSearch.text.trim();
         if (inputText.isNotEmpty && !_isAscending(inputText)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid Input: "$inputText". Digits must be in ascending order (e.g. 1234).'),
                backgroundColor: Colors.red,
              ),
            );
            return;
         }
      }
    }

    final items = _receiptLines'''

    content = content.replace(old_save, new_save)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
