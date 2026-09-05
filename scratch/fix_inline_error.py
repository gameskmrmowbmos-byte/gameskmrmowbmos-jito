def update_errors(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add error field to _BetEntry
    old_betentry = '''  bool isJackpot = false;
  String? sessionOverride;

  bool get hasAnyValue =>'''
    new_betentry = '''  bool isJackpot = false;
  String? sessionOverride;
  String? error;

  bool get hasAnyValue =>'''
    content = content.replace(old_betentry, new_betentry)

    # 2. Add _autoSearchError to _NewEntryPageState
    old_state = '''  bool _saving = false;'''
    new_state = '''  bool _saving = false;
  String? _autoSearchError;'''
    content = content.replace(old_state, new_state)

    # 3. Update _save function to use these fields instead of SnackBar
    old_save = '''    if (!_isAutoMode) {
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
    }'''

    new_save = '''    bool hasError = false;
    setState(() {
      if (!_isAutoMode) {
        for (final entry in _manualEntries) {
          entry.error = null;
          final rawNumber = entry.number.text.trim();
          if (rawNumber.isNotEmpty && entry.amount.text.trim().isNotEmpty) {
            if (!_isAscending(rawNumber)) {
              entry.error = 'Ascending only';
              hasError = true;
            }
          }
        }
      } else {
        _autoSearchError = null;
        if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
           final inputText = _autoSearch.text.trim();
           if (inputText.isNotEmpty && !_isAscending(inputText)) {
              _autoSearchError = 'Ascending only';
              hasError = true;
           }
        }
      }
    });
    if (hasError) return;'''
    content = content.replace(old_save, new_save)

    # 4. Clear error on change in manual mode
    old_onchanged_number = '''            _EntryTextField(
              controller: entry.number,
              compact: compact,
              maxLength: 10,
              onChanged: onChanged,
            ),'''
    new_onchanged_number = '''            _EntryTextField(
              controller: entry.number,
              errorText: entry.error,
              compact: compact,
              maxLength: 10,
              onChanged: () {
                if (entry.error != null) setState(() => entry.error = null);
                onChanged();
              },
            ),'''
    content = content.replace(old_onchanged_number, new_onchanged_number)

    # 5. Clear error on change in auto mode search
    old_onchanged_autosearch = '''              final search = TextField(
      controller: searchController,'''
    new_onchanged_autosearch = '''              final search = TextField(
      controller: searchController,
      onChanged: (_) {
        if (_autoSearchError != null) setState(() => _autoSearchError = null);
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: 'Search Number',
        errorText: _autoSearchError,'''
    content = content.replace('''      onChanged: (_) => onSearchChanged(),
      decoration: InputDecoration(
        labelText: 'Search Number',''', '''      onChanged: (_) {
        if (_autoSearchError != null) setState(() => _autoSearchError = null);
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: 'Search Number',
        errorText: _autoSearchError,''')

    # 6. Update _EntryTextField to support errorText and remove fixed height
    old_entry_textfield = '''class _EntryTextField extends StatelessWidget {
  const _EntryTextField({
    required this.controller,
    required this.compact,
    required this.maxLength,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool compact;
  final int maxLength;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 22 : 30,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: maxLength > 5 ? TextInputType.text : TextInputType.number,
        inputFormatters: [
          maxLength > 5
              ? FilteringTextInputFormatter.allow(RegExp(r'[0-9spdcSPDC>\ \-\*]'))
              : FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        onChanged: (_) => onChanged(),
        style:
            TextStyle(fontSize: compact ? 12 : 14, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 6,
            vertical: compact ? 0 : 4,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}'''

    new_entry_textfield = '''class _EntryTextField extends StatelessWidget {
  const _EntryTextField({
    required this.controller,
    required this.compact,
    required this.maxLength,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final bool compact;
  final int maxLength;
  final VoidCallback onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: maxLength > 5 ? TextInputType.text : TextInputType.number,
      inputFormatters: [
        maxLength > 5
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9spdcSPDC>\ \-\*]'))
            : FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (_) => onChanged(),
      style: TextStyle(fontSize: compact ? 12 : 14, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 9, height: 0.8),
        counterText: '',
        filled: true,
        fillColor: errorText != null ? Colors.red.shade50 : Colors.white,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 6,
          vertical: compact ? 4 : 8,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}'''
    content = content.replace(old_entry_textfield, new_entry_textfield)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file = update_errors
fix_file('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
