import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/utils/context_extensions.dart';
import 'package:matka_management/features/auth/data/repositories/auth_repository.dart';
import 'package:matka_management/features/auth/presentation/widgets/auth_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  bool _obscure = true;

  @override
  void dispose() {
    _fullName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
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
      final result = await ref.read(authRepositoryProvider).sendRegistrationOtp(
            fullName: _fullName.text,
            ownerName: _ownerName.text,
            email: _email.text,
            phoneNumber: _phone.text,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otp.text = result.developmentOtp ?? '';
        _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
      });
      context.showSuccess('OTP sent. Verify it to create your account.');
    } on Object catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      context.showError('Enter the 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).verifyRegistrationOtp(
            email: _email.text,
            otp: _otp.text,
          );
      if (!mounted) return;
      context.showSuccess(
        'Registration completed. Your account is waiting for administrator approval.',
      );
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
      title: 'Create Account',
      subtitle: 'Verify your email to start the 10-day free trial',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _fullName,
              enabled: !_loading && !_otpSent,
              decoration: InputDecoration(labelText: context.tr('Full Name')),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? context.tr('Enter full name')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerName,
              enabled: !_loading && !_otpSent,
              maxLength: 10,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(
                labelText: context.tr('Owner / Shop Name'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? context.tr('Enter owner or shop name')
                  : null,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              enabled: !_loading && !_otpSent,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  InputDecoration(labelText: context.tr('Mobile Number')),
              validator: (value) =>
                  RegExp(r'^[6-9]\d{9}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : context.tr('Enter a valid 10-digit mobile number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              enabled: !_loading && !_otpSent,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: context.tr('Password'),
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
              enabled: !_loading && !_otpSent,
              obscureText: _obscure,
              decoration:
                  InputDecoration(labelText: context.tr('Confirm Password')),
              validator: (value) => value == _password.text
                  ? null
                  : context.tr('Passwords do not match'),
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
                enabled: !_loading,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('Enter OTP')),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : () => _verify(),
                child: Text(
                  context.tr(
                    _loading ? 'Creating...' : 'Verify & Create Account',
                  ),
                ),
              ),
            ],
            TextButton(
              onPressed: _loading ? null : () => context.go('/login'),
              child: Text(context.tr('Already have an account? Login')),
            ),
          ],
        ),
      ),
    );
  }
}
