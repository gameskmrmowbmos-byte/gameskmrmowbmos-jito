def modify_ui(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove the SnackBar from _save() but keep the red box logic
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
        _autoSearchError = null;
        if (_selectedAutoType?.id == 'sp_motor' || _selectedAutoType?.id == 'dp_motor') {
           final inputText = _autoSearch.text.trim();
           if (inputText.isNotEmpty && !isAscendingNumber(inputText)) {
               hasError = true;
               _autoSearchError = 'Ascending only';
           }
        }
      }
    });
    if (hasError) return;"""
    content = content.replace(old_save, new_save)
    
    # 2. Add _autoSearchError variable to state class
    content = content.replace('  bool _saving = false;', '  bool _saving = false;\n  String? _autoSearchError;')

    # 3. Add to _AutoConfigSearchBar constructor
    old_search_bar = """class _AutoConfigSearchBar extends StatelessWidget {
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
        prefixIcon: const Icon(Icons.search),"""
    new_search_bar = """class _AutoConfigSearchBar extends StatelessWidget {
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
        prefixIcon: const Icon(Icons.search),"""
    content = content.replace(old_search_bar, new_search_bar)

    # 4. Modify _AutoConfigPanel correctly by anchoring precisely
    old_panel = """class _AutoConfigPanel extends StatelessWidget {
  const _AutoConfigPanel({
    required this.configs,
    required this.selectedType,
    required this.selectedSubtype,
    required this.numberOptions,
    required this.hasConfiguredNumbers,
    required this.showNumberTable,
    required this.availableColumns,
    required this.selectedColumn,
    required this.searchController,
    required this.entries,
    required this.compact,
    required this.onTypeSelected,
    required this.onSubtypeSelected,
    required this.onColumnSelected,
    required this.onSearchChanged,
    required this.onNumberSelected,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onAddRow,
    required this.onAddTenRows,
    required this.onDelete,
  });

  final List<GameBetTypeConfig> configs;
  final GameBetTypeConfig? selectedType;
  final GameBetSubtypeConfig? selectedSubtype;
  final List<GameNumberOption> numberOptions;
  final bool hasConfiguredNumbers;
  final bool showNumberTable;
  final List<int> availableColumns;
  final int? selectedColumn;
  final TextEditingController searchController;
  final List<_AutoBetEntry> entries;
  final bool compact;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String> onSubtypeSelected;
  final ValueChanged<int?> onColumnSelected;
  final VoidCallback onSearchChanged;
  final ValueChanged<GameNumberOption> onNumberSelected;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final VoidCallback onAddTenRows;
  final ValueChanged<_AutoBetEntry> onDelete;"""
  
    new_panel = """class _AutoConfigPanel extends StatelessWidget {
  const _AutoConfigPanel({
    required this.configs,
    required this.selectedType,
    required this.selectedSubtype,
    required this.numberOptions,
    required this.hasConfiguredNumbers,
    required this.showNumberTable,
    required this.availableColumns,
    required this.selectedColumn,
    required this.searchController,
    required this.entries,
    required this.compact,
    required this.onTypeSelected,
    required this.onSubtypeSelected,
    required this.onColumnSelected,
    required this.onSearchChanged,
    required this.onNumberSelected,
    required this.numberError,
    required this.amountError,
    required this.onChanged,
    required this.onAddRow,
    required this.onAddTenRows,
    required this.onDelete,
    this.autoSearchError,
    this.onClearError,
  });

  final List<GameBetTypeConfig> configs;
  final GameBetTypeConfig? selectedType;
  final GameBetSubtypeConfig? selectedSubtype;
  final List<GameNumberOption> numberOptions;
  final bool hasConfiguredNumbers;
  final bool showNumberTable;
  final List<int> availableColumns;
  final int? selectedColumn;
  final TextEditingController searchController;
  final List<_AutoBetEntry> entries;
  final bool compact;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String> onSubtypeSelected;
  final ValueChanged<int?> onColumnSelected;
  final VoidCallback onSearchChanged;
  final ValueChanged<GameNumberOption> onNumberSelected;
  final String? Function(_AutoBetEntry entry) numberError;
  final String? Function(_AutoBetEntry entry) amountError;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final VoidCallback onAddTenRows;
  final ValueChanged<_AutoBetEntry> onDelete;
  final String? autoSearchError;
  final VoidCallback? onClearError;"""
    content = content.replace(old_panel, new_panel)

    # 5. _NewEntryPageState usage of _AutoConfigPanel
    old_panel_usage = """                      onDelete: _removeAutoEntry,
                    )"""
    new_panel_usage = """                      onDelete: _removeAutoEntry,
                      autoSearchError: _autoSearchError,
                      onClearError: () => setState(() => _autoSearchError = null),
                    )"""
    content = content.replace(old_panel_usage, new_panel_usage)

    # 6. _AutoConfigPanel usage of _AutoConfigSearchBar
    old_search_bar_usage = """          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
          ),"""
    new_search_bar_usage = """          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
            autoSearchError: autoSearchError,
            onClearError: onClearError,
          ),"""
    content = content.replace(old_search_bar_usage, new_search_bar_usage)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

modify_ui('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
