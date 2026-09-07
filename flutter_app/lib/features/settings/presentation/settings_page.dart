import 'dart:async';

import 'package:flutter/material.dart';

import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/data/printer_store.dart';
import 'package:matka_management/features/printed_receipts/services/customer_parchi_printer.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _store = PrinterStore();
  final _session = prepareCustomerParchiPrint();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  StreamSubscription<List<DiscoveredBluetoothPrinter>>? _scanSubscription;
  List<PrinterConfiguration> _printers = const [];
  List<DiscoveredBluetoothPrinter> _discovered = const [];
  String? _activeId;
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final printers = await _store.loadPrinters();
    final active = await _store.loadActivePrinter();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _activeId = active?.id;
    });
  }

  void _scanBluetooth() {
    _scanSubscription?.cancel();
    _scanSubscription = _session.scanResults.listen((items) {
      if (mounted) setState(() => _discovered = items);
    });
    setState(() {
      _error = null;
      _scanning = true;
    });
    _session.startScan();
    Future<void>.delayed(const Duration(seconds: 9), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _saveWifi() async {
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (name.isEmpty ||
        host.isEmpty ||
        port == null ||
        port < 1 ||
        port > 65535) {
      setState(() =>
          _error = 'Enter a printer name, valid IP/hostname, and TCP port.');
      return;
    }
    final printer = PrinterConfiguration(
      id: 'wifi:$host:$port',
      type: PrinterConnectionType.wifi,
      name: name,
      host: host,
      port: port,
    );
    await _store.savePrinter(printer);
    await _store.setActivePrinter(printer.id);
    _nameController.clear();
    _hostController.clear();
    _portController.text = '9100';
    await _load();
  }

  Future<void> _saveBluetooth(DiscoveredBluetoothPrinter device) async {
    final printer = PrinterConfiguration(
      id: 'bluetooth:${device.address}',
      type: PrinterConnectionType.bluetooth,
      name: device.name,
      address: device.address,
    );
    await _store.savePrinter(printer);
    await _store.setActivePrinter(printer.id);
    await _load();
  }

  Future<void> _test(PrinterConfiguration printer) async {
    setState(() => _error = null);
    try {
      await _session.printTest(printer);
      if (mounted) _message('Test print sent.');
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _select(PrinterConfiguration printer) async {
    await _store.setActivePrinter(printer.id);
    if (mounted) setState(() => _activeId = printer.id);
  }

  Future<void> _remove(PrinterConfiguration printer) async {
    await _store.removePrinter(printer.id);
    await _load();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('permission denied')) {
      return 'Bluetooth permission denied.';
    }
    if (text.contains('timeout')) {
      return 'Printer did not respond before timeout.';
    }
    if (text.contains('Invalid')) {
      return text.replaceFirst('FormatException: ', '');
    }
    return text.replaceFirst('Bad state: ', '');
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _session.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Bluetooth SPP'),
          ElevatedButton.icon(
            onPressed: _scanning ? null : _scanBluetooth,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(_scanning ? 'Scanning...' : 'Scan printers'),
          ),
          for (final device in _discovered)
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(device.name),
              subtitle: Text(device.address),
              trailing: IconButton(
                tooltip: 'Save printer',
                icon: const Icon(Icons.add),
                onPressed: () => _saveBluetooth(device),
              ),
            ),
          const Divider(height: 32),
          _sectionTitle('Wi-Fi / TCP'),
          TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Printer name')),
          TextField(
              controller: _hostController,
              decoration:
                  const InputDecoration(labelText: 'IP address or hostname')),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'TCP port'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saveWifi,
            icon: const Icon(Icons.add),
            label: const Text('Save Wi-Fi printer'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const Divider(height: 32),
          _sectionTitle('Saved printers'),
          RadioGroup<String>(
            groupValue: _activeId,
            onChanged: (id) {
              if (id == null) return;
              final printer = _printers.firstWhere((item) => item.id == id);
              _select(printer);
            },
            child: Column(
              children: [
                if (_printers.isEmpty) const Text('No printer configured.'),
                for (final printer in _printers)
                  Card(
                    child: ListTile(
                      leading: Icon(
                          printer.isBluetooth ? Icons.bluetooth : Icons.wifi),
                      title: Text(printer.name),
                      subtitle: Text(printer.isBluetooth
                          ? printer.address ?? ''
                          : '${printer.host}:${printer.port}'),
                      trailing: Wrap(spacing: 4, children: [
                        Radio<String>(value: printer.id),
                        IconButton(
                            tooltip: 'Test print',
                            icon: const Icon(Icons.print),
                            onPressed: () => _test(printer)),
                        IconButton(
                            tooltip: 'Remove printer',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(printer)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
}
