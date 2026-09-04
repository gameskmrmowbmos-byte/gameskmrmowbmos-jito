import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/utils/context_extensions.dart';
import 'package:matka_management/features/auth/data/repositories/auth_repository.dart';
import 'package:matka_management/features/auth/presentation/widgets/auth_card.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.email, required this.otp, super.key});

  final String email;
  final String otp;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _passwordError(BuildContext context, String? value) {
    final password = value ?? '';
    if (password.length < 10 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return context.tr(
        'Use 10+ characters with upper, lower, number, and symbol',
      );
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.email.isEmpty || widget.otp.isEmpty) {
      context.showError('Reset OTP is missing');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: widget.email,
            otp: widget.otp,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      if (mounted) {
        context.showSuccess('Password reset. You can now sign in.');
        context.go('/login');
      }
    } on Object catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Set a new password',
      subtitle: 'The new password will invalidate earlier sessions',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _password,
              enabled: !_loading,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: context.tr('New password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) => _passwordError(context, value),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              enabled: !_loading,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: context.tr('Confirm password'),
                prefixIcon: const Icon(Icons.lock_reset_outlined),
              ),
              validator: (value) =>
                  value == _password.text
                      ? null
                      : context.tr('Passwords do not match'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(
                context.tr(_loading ? 'Saving...' : 'Reset password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
