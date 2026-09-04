def fix_errors(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Fix _BetRow setState issue
    old_betrow = '''              onChanged: () {
                if (entry.error != null) setState(() => entry.error = null);
                onChanged();
              },'''
    new_betrow = '''              onChanged: () {
                if (entry.error != null) entry.error = null;
                onChanged();
              },'''
    content = content.replace(old_betrow, new_betrow)

    # 2. Update _AutoConfigSearchBar signature and usage
    old_search_bar_class = '''class _AutoConfigSearchBar extends StatelessWidget {
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
  final ValueChanged<int?> onColumnSelected;'''
    new_search_bar_class = '''class _AutoConfigSearchBar extends StatelessWidget {
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
  final VoidCallback? onClearError;'''
    content = content.replace(old_search_bar_class, new_search_bar_class)

    old_search_field = '''      onChanged: (_) {
        if (_autoSearchError != null) setState(() => _autoSearchError = null);
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: 'Search Number',
        errorText: _autoSearchError,'''
    new_search_field = '''      onChanged: (_) {
        if (autoSearchError != null) onClearError?.call();
        onSearchChanged();
      },
      decoration: InputDecoration(
        labelText: 'Search Number',
        errorText: autoSearchError,'''
    content = content.replace(old_search_field, new_search_field)

    # 3. Update instantiation of _AutoConfigSearchBar
    old_instantiation = '''              _AutoConfigSearchBar(
                searchController: _autoSearch,
                columns: columns,
                selectedColumn: _selectedAutoSearchColumn,
                compact: compact,
                onSearchChanged: _onAutoSearchChanged,
                onColumnSelected: (val) {'''
    new_instantiation = '''              _AutoConfigSearchBar(
                searchController: _autoSearch,
                columns: columns,
                selectedColumn: _selectedAutoSearchColumn,
                compact: compact,
                autoSearchError: _autoSearchError,
                onClearError: () => setState(() => _autoSearchError = null),
                onSearchChanged: _onAutoSearchChanged,
                onColumnSelected: (val) {'''
    content = content.replace(old_instantiation, new_instantiation)

    # 4. Remove leading underscore from _isAscending
    content = content.replace('bool _isAscending(String numberString)', 'bool isAscendingNumber(String numberString)')
    content = content.replace('!_isAscending(rawNumber)', '!isAscendingNumber(rawNumber)')
    content = content.replace('!_isAscending(inputText)', '!isAscendingNumber(inputText)')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_errors('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
