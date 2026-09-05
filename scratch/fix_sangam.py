import re

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("final number = rawNumber.replaceAll('*', '-').replaceAll('>', '-');",
                          "final number = rawNumber.replaceAll('-', '*').replaceAll('>', '*');")

content = content.replace("var formattedNumber = number.replaceAll('-', ' ➔ ').replaceAll('*', ' ➔ ');",
                          "var formattedNumber = number.replaceAll('*', ' * ').replaceAll('-', ' * ');")

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
