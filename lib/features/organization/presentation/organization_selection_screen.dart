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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Brand & QR Header
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 48,
                            child: Image.asset(
                              isDark
                                  ? 'assets/images/logo_transparent_for_dark_bg.png'
                                  : 'assets/images/logo_transparent_for_light_bg.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                'assets/images/android-chrome-512x512.png',
                                height: 42,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          tooltip: 'Scan organization QR code',
                          onPressed: lookup.isLoading
                              ? null
                              : () => context.push(AppRoutes.organizationQr),
                          icon: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Header Titles
                  Text(
                    'Select Workspace',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your organization to access biometric attendance & portal services.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Modern Search Input
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      key: const Key('organization_query'),
                      controller: _searchController,
                      enabled: !lookup.isLoading,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Search organization name, domain, or ID...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  setState(() {});
                                  ref
                                      .read(
                                          organizationLookupProvider.notifier)
                                      .loadTenants();
                                },
                                icon: const Icon(Icons.cancel_rounded),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
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
                  ),
                  const SizedBox(height: 20),

                  // Organization List
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
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 56,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.trim().isEmpty
                                      ? 'No active organizations found.'
                                      : 'No organizations match "${_searchController.text.trim()}".',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
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
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final organization = organizations[index];
                              final isRecent =
                                  recent?.code == organization.code;
                              return _OrganizationTile(
                                organization: organization,
                                isRecent: isRecent,
                                isSelecting:
                                    _selectingCode == organization.code,
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      key: Key('organization_${organization.code}'),
      decoration: BoxDecoration(
        color: isRecent
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecent
              ? primaryColor.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isRecent ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // Organization Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRecent
                          ? [primaryColor, primaryColor.withValues(alpha: 0.8)]
                          : [
                              theme.colorScheme.secondary,
                              theme.colorScheme.secondary.withValues(alpha: 0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      organization.name.isNotEmpty
                          ? organization.name[0].toUpperCase()
                          : 'O',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              organization.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_rounded,
                                      size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Recent',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Domain: ${organization.apiBaseUri.host}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trailing Action / Loader
                if (isSelecting)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
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
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHigh
                .withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .error
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Directory'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
