with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("number: '${spDpType.toUpperCase()} $digit',",
                          "number: '$digit ${spDpType.toUpperCase()}',")

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
