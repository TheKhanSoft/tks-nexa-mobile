import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';

class OrganizationConfirmationScreen extends ConsumerWidget {
  const OrganizationConfirmationScreen({required this.organization, super.key});

  final Organization organization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(organizationSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Organization')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: const Icon(Icons.apartment, size: 42),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    organization.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    organization.code,
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Verified HTTPS service'),
                                Text(
                                  organization.apiBaseUri.host,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('confirm_organization'),
                    onPressed: session.isLoading
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(organizationSessionProvider.notifier)
                                  .select(organization);
                              if (context.mounted) context.go(AppRoutes.home);
                            } on Object {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'The organization could not be saved securely.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: session.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Use this organization'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: session.isLoading ? null : () => context.pop(),
                    child: const Text('Choose another'),
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
