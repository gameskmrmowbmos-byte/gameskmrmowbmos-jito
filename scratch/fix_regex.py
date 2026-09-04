def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = content.replace("RegExp(r'(?i)SP_MOTOR')", "RegExp(r'SP_MOTOR', caseSensitive: false)")
    content = content.replace("var dt =", "final dt =")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('flutter_app/lib/features/entries/data/receipt_models.dart')
fix_file('flutter_app/lib/features/share_records/data/share_records_models.dart')
