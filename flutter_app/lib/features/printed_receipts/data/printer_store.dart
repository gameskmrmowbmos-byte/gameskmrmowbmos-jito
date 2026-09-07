import 'dart:convert';

import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterStore {
  static const _printersKey = 'saved_printers';
  static const _activePrinterKey = 'active_printer_id';

  Future<List<PrinterConfiguration>> loadPrinters() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_printersKey) ?? const [];
    return values
        .map((value) => PrinterConfiguration.fromJson(
              jsonDecode(value) as Map<String, dynamic>,
            ))
        .where((printer) => printer.id.isNotEmpty && printer.name.isNotEmpty)
        .toList();
  }

  Future<PrinterConfiguration?> loadActivePrinter() async {
    final preferences = await SharedPreferences.getInstance();
    final activeId = preferences.getString(_activePrinterKey);
    if (activeId == null) return null;
    for (final printer in await loadPrinters()) {
      if (printer.id == activeId) return printer;
    }
    return null;
  }

  Future<void> savePrinter(PrinterConfiguration printer) async {
    final printers = await loadPrinters();
    final next = [
      for (final item in printers)
        if (item.id != printer.id) item,
      printer,
    ];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _printersKey,
      next.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> setActivePrinter(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activePrinterKey, id);
  }

  Future<void> removePrinter(String id) async {
    final printers = (await loadPrinters()).where((item) => item.id != id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _printersKey,
      printers.map((item) => jsonEncode(item.toJson())).toList(),
    );
    if (preferences.getString(_activePrinterKey) == id) {
      await preferences.remove(_activePrinterKey);
    }
  }
}
