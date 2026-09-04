def fix_betrow_and_validation(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Make _BetRow NOT const so it always rebuilds properly
    content = content.replace(
        '              _BetRow(\n                index: index,\n                entry: entries[index],\n                compact: compact,\n                session: session,\n                onChanged: onChanged,\n                onDelete: () => onDelete(index),\n              ),',
        '              _BetRow(\n                key: ValueKey(index),\n                index: index,\n                entry: entries[index],\n                compact: compact,\n                session: session,\n                onChanged: onChanged,\n                onDelete: () => onDelete(index),\n              ),'
    )

    # 2. Fix _BetRow to be StatefulWidget so entry.error changes cause local rebuilds
    old_betrow_class = """class _BetRow extends StatelessWidget {
  const _BetRow({
    required this.index,
    required this.entry,
    required this.compact,
    required this.session,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _BetEntry entry;
  final bool compact;
  final String session;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {"""

    new_betrow_class = """class _BetRow extends StatefulWidget {
  const _BetRow({
    super.key,
    required this.index,
    required this.entry,
    required this.compact,
    required this.session,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _BetEntry entry;
  final bool compact;
  final String session;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  State<_BetRow> createState() => _BetRowState();
}

class _BetRowState extends State<_BetRow> {
  _BetEntry get entry => widget.entry;
  bool get compact => widget.compact;
  String get session => widget.session;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onDelete => widget.onDelete;
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {"""

    content = content.replace(old_betrow_class, new_betrow_class)

    # 3. Fix the entry.error = null in _BetRow onChanged to also do setState
    old_on_changed = """              onChanged: () {
                if (entry.error != null) entry.error = null;
                onChanged();
              },"""
    new_on_changed = """              onChanged: () {
                if (entry.error != null) {
                  setState(() => entry.error = null);
                }
                onChanged();
              },"""
    content = content.replace(old_on_changed, new_on_changed)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_betrow_and_validation('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
