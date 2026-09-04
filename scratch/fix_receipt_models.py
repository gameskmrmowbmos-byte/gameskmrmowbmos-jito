import re

with open('flutter_app/lib/features/entries/data/receipt_models.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("json[\\'isJackpot\\']", "json['isJackpot']")
content = content.replace("json[\\'sessionOverride\\']", "json['sessionOverride']")

with open('flutter_app/lib/features/entries/data/receipt_models.dart', 'w', encoding='utf-8') as f:
    f.write(content)
