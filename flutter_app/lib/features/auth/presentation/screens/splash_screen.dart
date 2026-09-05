import 'package:flutter/material.dart';
import 'package:matka_management/core/constants/app_constants.dart';
import 'package:matka_management/core/language/app_localizations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fact_check_outlined, size: 64),
            const SizedBox(height: 18),
            Text(
              context.tr(AppConstants.applicationName),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.tr('Restoring secure session...')),
          ],
        ),
      ),
    );
  }
}
