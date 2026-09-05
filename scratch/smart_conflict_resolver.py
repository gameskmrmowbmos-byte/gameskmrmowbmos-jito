import re

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

def replacer(match):
    branch1 = match.group(1)
    branch2 = match.group(2)
    
    # Conflict 1
    if "_isAutoMode" in branch1 and "_localParchiCounters" in branch2:
        return branch1 + "\n  }\n\n" + branch2
        
    # Conflict 2
    elif "_canSave" in branch1 and "_marketSession" in branch2:
        return branch1 + "\n\n" + branch2
        
    # Conflict 3: jackpotEnabled vs isJackpot & sessionOverride
    elif "jackpotEnabled: entry.jackpotEnabled" in branch1:
        return branch2
        
    # Conflict 4: mode ... jackpotEnabled vs mode ...
    elif "'mode': line.isManual" in branch1:
        return "              'mode': line.isManual ? 'Manual' : 'Auto',\n              'isJackpot': line.isJackpot,\n              'sessionOverride': line.sessionOverride,"
        
    # Conflict 6: jackpotEnabled vs sessionOverride
    elif "jackpotEnabled: line.jackpotEnabled" in branch1:
        return "                    isJackpot: line.isJackpot,\n                    session: line.sessionOverride ?? session,"
        
    # Conflict 7: required this.jackpotEnabled vs session
    elif "required this.jackpotEnabled" in branch1:
        return "    required this.session,"
        
    # Conflict 8: final bool jackpotEnabled vs session
    elif "final bool jackpotEnabled" in branch1:
        return "  final String session;"
        
    # Conflict 9: Row with rocket vs formattedNumber text
    elif "Icon(" in branch1 and "formattedNumber" in branch2:
        return """            child: Row(
              children: [
                if (isJackpot) ...[
                  Icon(
                    Icons.rocket_launch,
                    size: compact ? 12 : 14,
                    color: _NewEntryPageState._red,
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    formattedNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF111820),
                      fontSize: compact ? 9 : 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],"""
              
    # Conflict 10 & 11: button onPressed
    elif "busy: saving," in branch1 and "isLoading" in branch2:
        return "              onPressed: canSave && !isLoading ? onSave" + ("AndPrint" if "onSaveAndPrint" in branch2 else "") + " : null,\n              busy: isLoading,"
        
    else:
        return branch2

# Apply replacer for everything except _save
content = re.sub(r'<<<<<<<<< Temporary merge branch 1\n(.*?)\n=========\n(.*?)\n>>>>>>>>> Temporary merge branch 2', replacer, content, flags=re.DOTALL)

# Now manually fix the _save method by replacing it entirely
save_pattern = r'  Future<void> _save\(\{required bool print\}\) async \{.*?(?=  void _clearAll\(\) \{)'
new_save = """  Future<void> _save({required bool print}) async {
    final market = _selectedMarket;
    if (market == null || !_canSave) return;

    final items = _receiptLines
        .map((line) => {
              'type': line.backendType,
              'number': line.number,
              'amount': int.tryParse(line.amount) ?? 0,
              'mode': line.isManual ? 'Manual' : 'Auto',
              'isJackpot': line.isJackpot,
              'sessionOverride': line.sessionOverride,
              if (!line.isManual) 'betType': line.betType,
              if (!line.isManual && line.betSubtype != null)
                'betSubtype': line.betSubtype,
            })
        .toList();

    if (items.isEmpty) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final currentParchiNo = _previewParchiNo;
      final receipt =
          await ref.read(newEntryControllerProvider.notifier).saveReceipt(
                market: market.id,
                session: _session,
                items: items,
                shouldPrint: print,
                overrideParchiNo: currentParchiNo,
              );
              
      if (receipt == null) {
        throw StateError('Receipt was not saved.');
      }
      if (!mounted) return;
      
      final mId = market.id;
      _clearAll();
      
      setState(() {
        _saving = false;
        final current = _localParchiCounters[mId] ?? 1;
        _localParchiCounters[mId] = current >= 99 ? 1 : current + 1;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            print
                ? 'Receipt ${receipt.receiptNumber} saved. Print job added.'
                : 'Receipt ${receipt.receiptNumber} saved.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = error.toString();
      });
    }
  }

"""
content = re.sub(save_pattern, new_save, content, flags=re.DOTALL)

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
