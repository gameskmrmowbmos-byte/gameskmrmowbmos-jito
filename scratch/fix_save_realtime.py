def fix_save_and_realtime(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Make Save and Save&Print buttons ALWAYS active (only disabled when saving)
    content = content.replace(
        "onPressed: canSave && !isLoading ? onSave : null,\n              compact: true,",
        "onPressed: !isLoading ? onSave : null,\n              compact: true,"
    )
    content = content.replace(
        "onPressed: canSave && !isLoading ? onSaveAndPrint : null,\n              compact: true,",
        "onPressed: !isLoading ? onSaveAndPrint : null,\n              compact: true,"
    )
    # Also fix the non-compact versions
    content = content.replace(
        "onPressed: canSave && !isLoading ? onSave : null,\n        ),",
        "onPressed: !isLoading ? onSave : null,\n        ),"
    )
    content = content.replace(
        "onPressed: canSave && !isLoading ? onSaveAndPrint : null,\n        ),",
        "onPressed: !isLoading ? onSaveAndPrint : null,\n        ),"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_save_and_realtime('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart')
