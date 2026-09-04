import re

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("  bool get _isAutoMode => _mode == 'AUTO';\n", '', 1)
content = content.replace('entry.jackpotEnabled', 'entry.isJackpot')
content = content.replace('receipt.receiptNumber', 'receipt.receipt.receiptNumber')
content = content.replace('                      onJackpotChanged: _toggleJackpot,\n', '')
content = content.replace('saving: _saving', 'isLoading: _saving')
content = content.replace('saving: saving', 'isLoading: saving')

# For duplicates that I might have created:
content = content.replace('isJackpot: line.isJackpot,\n                    isJackpot: line.isJackpot,\n', 'isJackpot: line.isJackpot,\n')
content = content.replace('required this.isJackpot,\n    required this.isJackpot,\n', 'required this.isJackpot,\n')
content = content.replace('final bool isJackpot;\n  final bool isJackpot;\n', 'final bool isJackpot;\n')

content = content.replace('busy: saving', 'busy: isLoading')
content = content.replace('busy: _saving', 'busy: isLoading')

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
