import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/utils/context_extensions.dart';
import 'package:matka_management/features/auth/data/repositories/auth_repository.dart';
import 'package:matka_management/features/auth/presentation/widgets/auth_card.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscure = true;
  String? _developmentOtp;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _passwordError(BuildContext context, String? value) {
    final password = value ?? '';
    if (password.length < 8 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return context.tr('Use 8+ chars with upper, lower, number, and symbol');
    }
    return null;
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _developmentOtp = result.developmentOtp;
      });
      context.showSuccess(
        'If the account exists, an OTP has been generated.',
      );
    } on Object catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      context.showError('Enter the 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).verifyForgotPasswordOtp(
            email: _email.text,
            otp: _otp.text,
          );
      if (!mounted) return;
      setState(() => _otpVerified = true);
      context.showSuccess('OTP verified. Enter a new password.');
    } on Object catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _email.text,
            otp: _otp.text,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      if (!mounted) return;
      context.showSuccess('Password reset successfully. Please login.');
      context.go('/login');
    } on Object catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Forgot Password',
      subtitle: 'Verify OTP and set a new password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_loading && !_otpSent,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  InputDecoration(labelText: context.tr('Email Address')),
              validator: (value) {
                final email = value?.trim() ?? '';
                return email.contains('@')
                    ? null
                    : context.tr('Enter a valid email');
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading || _otpSent ? null : _sendOtp,
              child: Text(
                context.tr(_loading && !_otpSent ? 'Sending...' : 'Send OTP'),
              ),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _otp,
                enabled: !_loading && !_otpVerified,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: context.tr('Enter OTP')),
              ),
              if (_developmentOtp != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Development OTP: {otp}',
                    params: {'otp': _developmentOtp},
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  context.tr(
                    'Development Mode - OTP is shown here for testing only.',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading || _otpVerified ? null : _verifyOtp,
                child: Text(
                  context.tr(
                    _loading && !_otpVerified ? 'Verifying...' : 'Verify OTP',
                  ),
                ),
              ),
            ],
            if (_otpVerified) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_loading,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.tr('New Password'),
                  suffixIcon: IconButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) => _passwordError(context, value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                enabled: !_loading,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.tr('Confirm New Password'),
                ),
                validator: (value) =>
                    value == _password.text
                        ? null
                        : context.tr('Passwords do not match'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _resetPassword,
                child: Text(
                  context.tr(_loading ? 'Resetting...' : 'Reset Password'),
                ),
              ),
            ],
            TextButton(
              onPressed: _loading ? null : () => context.go('/login'),
              child: Text(context.tr('Back to login')),
            ),
          ],
        ),
      ),
    );
  }
}
