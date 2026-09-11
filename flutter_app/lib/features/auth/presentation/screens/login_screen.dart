import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/auth/presentation/widgets/auth_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberSession = true;

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
    } on Object {
      // The provider exposes the sanitized error below the form.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final loading = auth.busy;
    return AuthCard(
      title: 'Welcome back',
      subtitle: 'Sign in as an administrator or operator',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              enabled: !loading,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: context.tr('Password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: context.tr(
                    _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                  onPressed: () => setState(
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
            const SizedBox(height: 6),
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
                Expanded(child: Text(context.tr('Remember secure session'))),
                TextButton(
                  onPressed:
                      loading ? null : () => context.go('/forgot-password'),
                  child: Text(context.tr('Forgot password?')),
                ),
              ],
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 8),
              Text(
                context.trMaybe(auth.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: loading ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Sign in')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
