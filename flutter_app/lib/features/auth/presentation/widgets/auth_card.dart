import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:matka_management/core/constants/app_constants.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_switcher.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4F46E5).withValues(alpha: 0.08), // Indigo
              const Color(0xFF0EA5E9).withValues(alpha: 0.06), // Sky Blue
              const Color(0xFF14B8A6).withValues(alpha: 0.04), // Teal
              const Color(0xFF8B5CF6).withValues(alpha: 0.06), // Violet
              const Color(0xFFF43F5E).withValues(alpha: 0.08), // Rose
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFDDE1EA)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: LanguageSwitcher(),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.fact_check_outlined,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.trMaybe(title),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.trMaybe(subtitle),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 32),
                        child,
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(AppConstants.legalNotice),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 500.ms, curve: Curves.easeOut).scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
