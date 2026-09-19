import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/failure_message.dart';

class OrganizationSelectionScreen extends ConsumerStatefulWidget {
  const OrganizationSelectionScreen({super.key});

  @override
  ConsumerState<OrganizationSelectionScreen> createState() =>
      _OrganizationSelectionScreenState();
}

class _OrganizationSelectionScreenState
    extends ConsumerState<OrganizationSelectionScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectingCode;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(organizationLookupProvider.notifier).searchByName(value);
    });
  }

  List<Organization> _recentFirst(
    List<Organization> organizations,
    Organization? recent,
  ) {
    if (recent == null) return organizations;
    final recentIndex = organizations.indexWhere(
      (organization) => organization.code == recent.code,
    );
    if (recentIndex <= 0) return organizations;
    return [
      organizations[recentIndex],
      ...organizations.take(recentIndex),
      ...organizations.skip(recentIndex + 1),
    ];
  }

  Future<void> _selectOrganization(Organization organization) async {
    if (_selectingCode != null) return;
    setState(() => _selectingCode = organization.code);
    try {
      await ref.read(organizationSessionProvider.notifier).select(organization);
      if (mounted) context.go(AppRoutes.login);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeFailureMessage(error))));
      setState(() => _selectingCode = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(organizationLookupProvider);
    final recent = ref.watch(organizationSessionProvider).value;
    final organizations = _recentFirst(
      lookup.value ?? const <Organization>[],
      recent,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Organization'),
        actions: [
          IconButton(
            tooltip: 'Scan organization QR code',
            onPressed: lookup.isLoading
                ? null
                : () => context.push(AppRoutes.organizationQr),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose your organization',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Organizations are loaded from the secure TKS Nexa '
                    'directory.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key('organization_query'),
                    controller: _searchController,
                    enabled: !lookup.isLoading,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Search organizations',
                      hintText: 'Enter a name, slug, or organization ID',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchController.clear();
                                setState(() {});
                                ref
                                    .read(organizationLookupProvider.notifier)
                                    .loadTenants();
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _onSearchChanged(value);
                    },
                    onSubmitted: (value) {
                      _searchDebounce?.cancel();
                      ref
                          .read(organizationLookupProvider.notifier)
                          .searchByName(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: switch (lookup) {
                      AsyncLoading() => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      AsyncError(:final error) => _DirectoryError(
                        message: safeFailureMessage(error),
                        onRetry: () => ref
                            .read(organizationLookupProvider.notifier)
                            .loadTenants(),
                      ),
                      AsyncData() when organizations.isEmpty => Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'No active organizations are available.'
                              : 'No organizations match your search.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      _ => RefreshIndicator(
                        onRefresh: () => ref
                            .read(organizationLookupProvider.notifier)
                            .searchByName(_searchController.text),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: organizations.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final organization = organizations[index];
                            final isRecent = recent?.code == organization.code;
                            return _OrganizationTile(
                              organization: organization,
                              isRecent: isRecent,
                              isSelecting: _selectingCode == organization.code,
                              onTap: _selectingCode == null
                                  ? () => _selectOrganization(organization)
                                  : null,
                            );
                          },
                        ),
                      ),
                    },
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

class _OrganizationTile extends StatelessWidget {
  const _OrganizationTile({
    required this.organization,
    required this.isRecent,
    required this.isSelecting,
    required this.onTap,
  });

  final Organization organization;
  final bool isRecent;
  final bool isSelecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('organization_${organization.code}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isRecent
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(isRecent ? Icons.star : Icons.apartment_outlined),
        ),
        title: Text(organization.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecent) ...[
              const Chip(
                avatar: Icon(Icons.history, size: 16),
                label: Text('Recent'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
            ],
            if (isSelecting)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _DirectoryError extends StatelessWidget {
  const _DirectoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
