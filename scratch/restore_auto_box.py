import re

def restore_auto_box_red(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # 1. Add _autoSearchError to _NewEntryPageState
    content = content.replace('  bool _saving = false;', '  bool _saving = false;\\n  String? _autoSearchError;')

    # 2. Set _autoSearchError in _save()
    old_save = '''      } else {
        if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
           final inputText = _autoSearch.text.trim();
           if (inputText.isNotEmpty && !isAscendingNumber(inputText)) {
               hasError = true;
           }
        }
      }'''
    new_save = '''      } else {
        _autoSearchError = null;
        if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
           final inputText = _autoSearch.text.trim();
           if (inputText.isNotEmpty && !isAscendingNumber(inputText)) {
               hasError = true;
               _autoSearchError = 'Ascending only';
           }
        }
      }'''
    content = content.replace(old_save, new_save)
    
    # 3. Add autoSearchError to _AutoConfigSearchBar
    old_search_bar = '''class _AutoConfigSearchBar extends StatelessWidget {
  const _AutoConfigSearchBar({
    required this.searchController,
    required this.columns,
    required this.selectedColumn,
    required this.compact,
    required this.onSearchChanged,
    required this.onColumnSelected,
  });

  final TextEditingController searchController;
  final List<int> columns;
  final int? selectedColumn;
  final bool compact;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onColumnSelected;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchController,
      keyboardType: TextInputType.text,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(7),
      ],
      onChanged: (_) {
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: 'Search Number',
        prefixIcon: const Icon(Icons.search),'''

    new_search_bar = '''class _AutoConfigSearchBar extends StatelessWidget {
  const _AutoConfigSearchBar({
    required this.searchController,
    required this.columns,
    required this.selectedColumn,
    required this.compact,
    required this.onSearchChanged,
    required this.onColumnSelected,
    this.autoSearchError,
    this.onClearError,
  });

  final TextEditingController searchController;
  final List<int> columns;
  final int? selectedColumn;
  final bool compact;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onColumnSelected;
  final String? autoSearchError;
  final VoidCallback? onClearError;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchController,
      keyboardType: TextInputType.text,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(7),
      ],
      onChanged: (_) {
        if (autoSearchError != null) onClearError?.call();
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: 'Search Number',
        errorText: autoSearchError,
        prefixIcon: const Icon(Icons.search),'''
    content = content.replace(old_search_bar, new_search_bar)

    # 4. Modify _AutoConfigPanel constructor and fields using regex
    content = re.sub(
        r'(class _AutoConfigPanel extends StatelessWidget \{\n  const _AutoConfigPanel\(\{[\s\S]*?)(  \}\);)',
        r'\1    this.autoSearchError,\n    this.onClearError,\n\2',
        content,
        count=1
    )
    content = re.sub(
        r'(  final VoidCallback onAmountErrorCleared;\n)',
        r'\1  final String? autoSearchError;\n  final VoidCallback? onClearError;\n',
        content,
        count=1
    )

    # 5. Pass them down from _NewEntryPageState to _AutoConfigPanel
    old_panel_usage = '''                      onDelete: _removeAutoEntry,
                    )'''
    new_panel_usage = '''                      onDelete: _removeAutoEntry,
                      autoSearchError: _autoSearchError,
                      onClearError: () => setState(() => _autoSearchError = null),
                    )'''
    content = content.replace(old_panel_usage, new_panel_usage)

    # 6. Pass them down from _AutoConfigPanel to _AutoConfigSearchBar
    old_search_bar_usage = '''          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
          ),'''
    new_search_bar_usage = '''          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
            autoSearchError: autoSearchError,
            onClearError: onClearError,
          ),'''
    content = content.replace(old_search_bar_usage, new_search_bar_usage)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

restore_auto_box_red('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
