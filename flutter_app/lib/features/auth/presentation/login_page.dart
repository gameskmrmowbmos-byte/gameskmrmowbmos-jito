import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_switcher.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _rememberSession = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authProvider.notifier)
          .login(_identifier.text.trim(), _password.text);
      if (mounted) context.go('/new-entry');
    } on Object {
      // AuthProvider exposes a user-friendly message below the form.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final loading = auth.status == AuthStatus.initializing;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageSwitcher(),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('MATKA ENTRY'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('Please login to continue'),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _identifier,
                  enabled: !loading,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Email or username'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr('Required')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !loading,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.tr('Password'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: context.tr(
                        _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                      onPressed: loading
                          ? null
                          : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? context.tr('Required')
                      : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberSession,
                      onChanged: loading
                          ? null
                          : (value) => setState(
                                () => _rememberSession = value ?? true,
                              ),
                    ),
                    Text(context.tr('Remember Me')),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          loading ? null : () => context.go('/forgot-password'),
                      child: Text(context.tr('Forgot Password?')),
                    ),
                  ],
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.trMaybe(auth.error!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.tr('LOGIN'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: loading ? null : () => context.go('/register'),
                  child: Text(context.tr('Create Account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
