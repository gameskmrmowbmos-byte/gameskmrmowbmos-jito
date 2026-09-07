import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Printer Settings'),
              subtitle: const Text(
                'Connect and test your thermal receipt printer',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Printer settings will be added here.
              },
            ),
          ),
        ],
      ),
    );
  }
}