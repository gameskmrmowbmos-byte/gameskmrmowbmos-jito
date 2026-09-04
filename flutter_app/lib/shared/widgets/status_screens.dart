import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/auth/data/models/access_status.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_draft_provider.dart';

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) => _StatusScreen(
        icon: Icons.lock_outline,
        title: 'Access denied',
        message: 'Your role does not have access to this module.',
        action: () => context.go('/new-entry'),
      );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => _StatusScreen(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: 'The requested page does not exist.',
        action: () => context.go('/new-entry'),
      );
}

class AccessRestrictedScreen extends ConsumerWidget {
  const AccessRestrictedScreen({required this.status, super.key});

  final AccessStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = status?.code;
    final expiry = status?.expiryDate == null
        ? null
        : DateFormat('dd-MM-yyyy').format(status!.expiryDate!);

    final expiryMessage = expiry == null
        ? ''
        : context.tr(
            '\n\nExpiry Date: {date}',
            params: {'date': expiry},
          );
    final details = switch (code) {
      'ACCOUNT_PENDING' => (
          Icons.hourglass_empty,
          'ACCOUNT PENDING APPROVAL',
          'Your account is waiting for Admin approval.',
        ),
      'ACCOUNT_REJECTED' => (
          Icons.cancel_outlined,
          'ACCOUNT NOT APPROVED',
          'Please contact Admin.',
        ),
      'ACCOUNT_BLOCKED' => (
          Icons.block,
          'ACCOUNT BLOCKED',
          'Please contact Admin.',
        ),
      'ACCOUNT_DISABLED' => (
          Icons.lock_outline,
          'ACCOUNT DISABLED',
          'Please contact Admin.',
        ),
      'SUBSCRIPTION_EXPIRED' => (
          Icons.event_busy,
          'ACCESS EXPIRED',
          context.tr(
            'Your recharge has expired.{expiry}\n\nPlease contact Admin to recharge your account.',
            params: {'expiry': expiryMessage},
          ),
        ),
      'SUBSCRIPTION_NOT_ACTIVE' => (
          Icons.payments_outlined,
          'RECHARGE NOT ACTIVE',
          'Your account has no active recharge. Please contact Admin.',
        ),
      _ => (
          Icons.lock_outline,
          'ACCESS DENIED',
          status?.message ?? 'Please contact Admin.',
        ),
    };

    return _StatusScreen(
      icon: details.$1,
      title: details.$2,
      message: details.$3,
      actionLabel: 'Back to login',
      action: () async {
        ref.read(newEntryDraftProvider.notifier).clearActive();
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
    );
  }
}

class SubscriptionLockedScreen extends ConsumerWidget {
  const SubscriptionLockedScreen({required this.status, super.key});

  final AccessStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiry = status?.expiryDate == null
        ? '-'
        : DateFormat('dd-MM-yyyy').format(status!.expiryDate!);
    final type = status?.subscriptionType == 'TRIAL'
        ? context.tr('Free Trial')
        : status?.subscriptionType == 'PAID'
            ? context.tr('Paid Plan')
            : context.tr('Subscription');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_clock_outlined, size: 58),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Subscription Expired'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      'Your free trial or subscription has expired. Please contact the administrator to recharge your account and continue creating new entries.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(label: context.tr('Trial / Plan Status'), value: type),
                  _InfoRow(label: context.tr('Expired On'), value: expiry),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).refreshAccessStatus();
                      if (context.mounted) context.go('/new-entry');
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('Refresh Subscription')),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/entries'),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: Text(context.tr('Contact Admin')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.actionLabel = 'Go to dashboard',
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 68),
              const SizedBox(height: 16),
              Text(
                context.trMaybe(title),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(context.trMaybe(message), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: action,
                child: Text(context.tr(actionLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
