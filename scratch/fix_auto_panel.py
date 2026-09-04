def fix_auto_panel(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # _AutoConfigPanel constructor
    old_panel_constructor = '''class _AutoConfigPanel extends StatelessWidget {
  const _AutoConfigPanel({
    required this.config,
    required this.subtype,
    required this.compact,
    required this.searchController,
    required this.selectedColumn,
    required this.numberOptions,
    required this.hasConfiguredNumbers,
    required this.onSearchChanged,
    required this.onColumnSelected,
  });'''
    new_panel_constructor = '''class _AutoConfigPanel extends StatelessWidget {
  const _AutoConfigPanel({
    required this.config,
    required this.subtype,
    required this.compact,
    required this.searchController,
    required this.selectedColumn,
    required this.numberOptions,
    required this.hasConfiguredNumbers,
    required this.onSearchChanged,
    required this.onColumnSelected,
    this.autoSearchError,
    this.onClearError,
  });'''
    content = content.replace(old_panel_constructor, new_panel_constructor)

    old_panel_fields = '''  final bool hasConfiguredNumbers;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onColumnSelected;'''
    new_panel_fields = '''  final bool hasConfiguredNumbers;
  final VoidCallback onSearchChanged;
  final ValueChanged<int?> onColumnSelected;
  final String? autoSearchError;
  final VoidCallback? onClearError;'''
    content = content.replace(old_panel_fields, new_panel_fields)

    # Pass it down in _AutoConfigPanel build method
    old_panel_instantiation = '''          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
          ),'''
    new_panel_instantiation = '''          _AutoConfigSearchBar(
            searchController: searchController,
            columns: showNumberTable ? const <int>[] : availableColumns,
            selectedColumn: selectedColumn,
            compact: compact,
            onSearchChanged: onSearchChanged,
            onColumnSelected: onColumnSelected,
            autoSearchError: autoSearchError,
            onClearError: onClearError,
          ),'''
    content = content.replace(old_panel_instantiation, new_panel_instantiation)

    # Pass it from _NewEntryPageState build method
    old_main_instantiation = '''              _AutoConfigPanel(
                config: _selectedAutoType,
                subtype: _selectedAutoSubtype,
                compact: compact,
                searchController: _autoSearch,
                selectedColumn: _selectedAutoSearchColumn,
                numberOptions: _selectedAutoNumberOptions,
                hasConfiguredNumbers: _hasConfiguredNumbers,
                onSearchChanged: _onAutoSearchChanged,
                onColumnSelected: (val) {
                  setState(() => _selectedAutoSearchColumn = val);
                  _ensureAutoRowForSelection();
                },
              ),'''
    new_main_instantiation = '''              _AutoConfigPanel(
                config: _selectedAutoType,
                subtype: _selectedAutoSubtype,
                compact: compact,
                searchController: _autoSearch,
                selectedColumn: _selectedAutoSearchColumn,
                numberOptions: _selectedAutoNumberOptions,
                hasConfiguredNumbers: _hasConfiguredNumbers,
                onSearchChanged: _onAutoSearchChanged,
                onColumnSelected: (val) {
                  setState(() => _selectedAutoSearchColumn = val);
                  _ensureAutoRowForSelection();
                },
                autoSearchError: _autoSearchError,
                onClearError: () => setState(() => _autoSearchError = null),
              ),'''
    content = content.replace(old_main_instantiation, new_main_instantiation)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_auto_panel('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
