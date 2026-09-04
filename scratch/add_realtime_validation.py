def add_realtime_validation(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find _BetRowState and add ascending checker + hook it to onChanged of number field
    old_betrow_state = """class _BetRowState extends State<_BetRow> {
  _BetEntry get entry => widget.entry;
  bool get compact => widget.compact;
  String get session => widget.session;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onDelete => widget.onDelete;
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {"""

    new_betrow_state = """class _BetRowState extends State<_BetRow> {
  _BetEntry get entry => widget.entry;
  bool get compact => widget.compact;
  String get session => widget.session;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onDelete => widget.onDelete;
  int get index => widget.index;

  bool _isAscending(String numberString) {
    final parts = numberString.replaceAll('-', '*').replaceAll('>', '*').split('*');
    for (final part in parts) {
      final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < digits.length - 1; i++) {
        final w1 = digits[i] == '0' ? 10 : int.parse(digits[i]);
        final w2 = digits[i + 1] == '0' ? 10 : int.parse(digits[i + 1]);
        if (w1 > w2) return false;
      }
    }
    return true;
  }

  void _validateNumber() {
    final raw = entry.number.text.trim();
    // Only validate if it looks like a pure digit entry (not sp/dp)
    final isSpDp = RegExp(r'(sp|dp)', caseSensitive: false).hasMatch(raw);
    final newError = (!isSpDp && raw.isNotEmpty && !_isAscending(raw))
        ? 'Ascending only'
        : null;
    if (newError != entry.error) {
      setState(() => entry.error = newError);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {"""

    content = content.replace(old_betrow_state, new_betrow_state)

    # Now hook _validateNumber into the number field's onChanged (replace the existing onChanged in _BetRow)
    old_num_onchanged = """              onChanged: () {
                if (entry.error != null) {
                  setState(() => entry.error = null);
                }
                onChanged();
              },"""

    new_num_onchanged = """              onChanged: () {
                _validateNumber();
              },"""

    content = content.replace(old_num_onchanged, new_num_onchanged)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

add_realtime_validation('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
