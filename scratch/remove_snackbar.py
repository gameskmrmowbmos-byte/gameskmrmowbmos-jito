def remove_snackbar(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. First, replace the _save logic
    old_save = """    bool hasError = false;
    String? errorMessage;
    setState(() {
      if (!_isAutoMode) {
        for (final entry in _manualEntries) {
          entry.error = null;
          final rawNumber = entry.number.text.trim();
          if (rawNumber.isNotEmpty && entry.amount.text.trim().isNotEmpty) {
            if (!isAscendingNumber(rawNumber)) {
              entry.error = 'Ascending only';
              hasError = true;
              errorMessage ??= 'Invalid Number: "$rawNumber". Digits must be in ascending order (0 is treated as 10).';
            }
          }
        }
      } else {
        if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
           final inputText = _autoSearch.text.trim();
           if (inputText.isNotEmpty && !isAscendingNumber(inputText)) {
               hasError = true;
               errorMessage ??= 'Invalid Input: "$inputText". Digits must be in ascending order (0 is treated as 10).';
           }
        }
      }
    });
    if (hasError) {
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }"""

    new_save = """    bool hasError = false;
    setState(() {
      if (!_isAutoMode) {
        for (final entry in _manualEntries) {
          entry.error = null;
          final rawNumber = entry.number.text.trim();
          if (rawNumber.isNotEmpty && entry.amount.text.trim().isNotEmpty) {
            if (!isAscendingNumber(rawNumber)) {
              entry.error = 'Ascending only';
              hasError = true;
            }
          }
        }
      } else {
        if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
           final inputText = _autoSearch.text.trim();
           if (inputText.isNotEmpty && !isAscendingNumber(inputText)) {
               hasError = true;
           }
        }
      }
    });
    if (hasError) return;"""
    content = content.replace(old_save, new_save)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

remove_snackbar('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
