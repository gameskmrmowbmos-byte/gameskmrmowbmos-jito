import 'package:flutter/material.dart';
import 'package:matka_management/core/language/app_localizations.dart';

extension ContextMessages on BuildContext {
  void showSuccess(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(trMaybe(message)),
          backgroundColor: Colors.green.shade700,
        ),
      );
  }

  void showError(Object error) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(trMaybe(error.toString())),
          backgroundColor: Theme.of(this).colorScheme.error,
        ),
      );
  }
}
