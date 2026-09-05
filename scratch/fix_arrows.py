import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = content.replace("replaceAll('-', ' ➔ ').replaceAll('*', ' ➔ ')", "replaceAll('-', ' * ').replaceAll('*', ' * ')")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('flutter_app/lib/features/entries/presentation/receipt_detail_widgets.dart')
fix_file('flutter_app/lib/features/printed_receipts/services/customer_parchi_printer_web.dart')
