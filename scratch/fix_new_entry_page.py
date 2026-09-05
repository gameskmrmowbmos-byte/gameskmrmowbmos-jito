import re

with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Conflict 1
c1 = r"""<<<<<<<<< Temporary merge branch 1
  bool get _isAutoMode => _mode == 'AUTO';
  ReceiptMarket\? get _selectedMarket \{
    if \(_markets\.isEmpty\) return null;
    if \(_market == null\) return _markets\.first;
    return _markets\.any\(\(market\) => market\.id == _market!\.id\)
        \? _market
        : _markets\.first;
  \}
=========
  final Map<String, int> _localParchiCounters = \{\};

  String get _previewParchiNo \{
    if \(_market == null\) return 'NEW';
    final count = _localParchiCounters\[_market!\.id\] \?\? 1;
    final marketName = _market!\.name\.trim\(\)\.toUpperCase\(\);
    final parts = marketName\.split\(RegExp\(r'\\s\+'\)\);
    
    String prefix = 'M';
    if \(parts\.length >= 2 && parts\[0\]\.isNotEmpty && parts\[1\]\.isNotEmpty\) \{
      prefix = '\$\{parts\[0\]\[0\]\}\$\{parts\[1\]\[0\]\}';
    \} else if \(parts\.isNotEmpty && parts\[0\]\.isNotEmpty\) \{
      prefix = parts\[0\]\[0\];
    \}
    
    return '\$prefix\$\{count\.toString\(\)\.padLeft\(2, '0'\)\}';
  \}
>>>>>>>>> Temporary merge branch 2"""
r1 = """  bool get _isAutoMode => _mode == 'AUTO';
  ReceiptMarket? get _selectedMarket {
    if (_markets.isEmpty) return null;
    if (_market == null) return _markets.first;
    return _markets.any((market) => market.id == _market!.id)
        ? _market
        : _markets.first;
  }

  final Map<String, int> _localParchiCounters = {};

  String get _previewParchiNo {
    if (_market == null) return 'NEW';
    final count = _localParchiCounters[_market!.id] ?? 1;
    final marketName = _market!.name.trim().toUpperCase();
    final parts = marketName.split(RegExp(r'\\s+'));
    
    String prefix = 'M';
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      prefix = '${parts[0][0]}${parts[1][0]}';
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      prefix = parts[0][0];
    }
    
    return '$prefix${count.toString().padLeft(2, '0')}';
  }"""
content = re.sub(c1, r1.replace('\\s+', '\\\\s+'), content)

# Conflict 2
c2 = r"""<<<<<<<<< Temporary merge branch 1
  bool get _canSave =>
      !_saving &&
      _selectedMarket != null &&
      _receiptLines\.isNotEmpty &&
      \(_isAutoMode
          \? _autoEntries
              \.where\(\(entry\) => entry\.hasAnyValue\)
              \.every\(_isValidAutoEntry\)
          : _manualEntries
              \.where\(\(entry\) => entry\.hasAnyValue\)
              \.every\(_isValidManualEntry\)\);
=========
  String get _marketSession => '\$\{_market\?\.name \?\? ''\} - \$_session';
>>>>>>>>> Temporary merge branch 2"""
r2 = """  bool get _canSave =>
      !_saving &&
      _selectedMarket != null &&
      _receiptLines.isNotEmpty &&
      (_isAutoMode
          ? _autoEntries
              .where((entry) => entry.hasAnyValue)
              .every(_isValidAutoEntry)
          : _manualEntries
              .where((entry) => entry.hasAnyValue)
              .every(_isValidManualEntry));

  String get _marketSession => '${_market?.name ?? ''} - $_session';"""
content = re.sub(c2, r2, content)

# Conflict 3
c3 = r"""<<<<<<<<< Temporary merge branch 1
            jackpotEnabled: entry\.jackpotEnabled,
=========
            isJackpot: entry\.isJackpot,
            sessionOverride: sessionOverride,
>>>>>>>>> Temporary merge branch 2"""
r3 = """            isJackpot: entry.isJackpot,
            sessionOverride: sessionOverride,"""
content = re.sub(c3, r3, content)

# Conflict 4 & 5 (We replace the whole _save method to avoid regex headaches)
save_method_pattern = r'  Future<void> _save\(\{required bool print\}\) async \{.*?(?=  void _clearAll\(\) \{)'
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
content = re.sub(save_method_pattern, new_save, content, flags=re.DOTALL)

# Conflict 6
c6 = r"""<<<<<<<<< Temporary merge branch 1
                    jackpotEnabled: line\.jackpotEnabled,
=========
                    session: line\.sessionOverride \?\? session,
>>>>>>>>> Temporary merge branch 2"""
r6 = """                    isJackpot: line.isJackpot,
                    session: line.sessionOverride ?? session,"""
content = re.sub(c6, r6, content)

# Conflict 7
c7 = r"""<<<<<<<<< Temporary merge branch 1
    required this\.jackpotEnabled,
=========
    required this\.session,
>>>>>>>>> Temporary merge branch 2"""
r7 = """    required this.isJackpot,
    required this.session,"""
content = re.sub(c7, r7, content)

# Conflict 8
c8 = r"""<<<<<<<<< Temporary merge branch 1
  final bool jackpotEnabled;
=========
  final String session;
>>>>>>>>> Temporary merge branch 2"""
r8 = """  final bool isJackpot;
  final String session;"""
content = re.sub(c8, r8, content)


# Conflict 9
c9 = r"""<<<<<<<<< Temporary merge branch 1
            child: Row\(
              children: \[
                if \(jackpotEnabled\) \.\.\.\[
                  Icon\(
                    Icons\.rocket_launch,
                    size: compact \? 15 : 17,
                    color: _NewEntryPageState\._red,
                  \),
                  const SizedBox\(width: 5\),
                \],
                Expanded\(
                  child: Text\(
                    number,
                    maxLines: 1,
                    overflow: TextOverflow\.ellipsis,
                    style: TextStyle\(
                      color: const Color\(0xFF111820\),
                      fontSize: compact \? 18 : 21,
                      fontWeight: FontWeight\.w900,
                      height: 1,
                      letterSpacing: 0,
                    \),
                  \),
                \),
              \],
=========
            child: Text\(
              formattedNumber,
              maxLines: 1,
              overflow: TextOverflow\.ellipsis,
              style: TextStyle\(
                color: const Color\(0xFF111820\),
                fontSize: compact \? 9 : 11,
                fontWeight: FontWeight\.w900,
                height: 1,
                letterSpacing: 0,
              \),
>>>>>>>>> Temporary merge branch 2"""
r9 = """            child: Row(
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
content = re.sub(c9, r9, content)

# Conflict 10
c10 = r"""<<<<<<<<< Temporary merge branch 1
              onPressed: canSave && !_saving \? onSave : null,
              busy: _saving,
=========
              onPressed: canSave && !isLoading \? onSave : null,
>>>>>>>>> Temporary merge branch 2"""
# WAIT I NEED TO BE SURE ABOUT Conflict 10's text! It was:
c10_alt = r"""<<<<<<<<< Temporary merge branch 1
              onPressed: canSave && !saving \? onSave : null,
              busy: saving,
=========
              onPressed: canSave && !isLoading \? onSave : null,
>>>>>>>>> Temporary merge branch 2"""
r10 = """              onPressed: canSave && !saving ? onSave : null,
              busy: saving,"""
content = re.sub(c10_alt, r10, content)

# Conflict 11
c11_alt = r"""<<<<<<<<< Temporary merge branch 1
              onPressed: canSave && !saving \? onSaveAndPrint : null,
              busy: saving,
=========
              onPressed: canSave && !isLoading \? onSaveAndPrint : null,
>>>>>>>>> Temporary merge branch 2"""
r11 = """              onPressed: canSave && !saving ? onSaveAndPrint : null,
              busy: saving,"""
content = re.sub(c11_alt, r11, content)


with open('flutter_app/lib/features/new_entry/presentation/new_entry_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
