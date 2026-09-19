import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_repository.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_scoped_data_cleaner.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig must be overridden at bootstrap.'),
);

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => throw StateError('SecureStorageService must be overridden.'),
);

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => throw StateError('OrganizationRepository must be overridden.'),
);

final organizationScopedDataCleanerProvider =
    Provider<OrganizationScopedDataCleaner>(
      (ref) => SecureOrganizationScopedDataCleaner(
        ref.watch(secureStorageServiceProvider),
      ),
    );

final organizationSessionProvider =
    AsyncNotifierProvider<OrganizationSessionController, Organization?>(
      OrganizationSessionController.new,
    );

class OrganizationSessionController extends AsyncNotifier<Organization?> {
  @override
  FutureOr<Organization?> build() {
    return ref.watch(organizationRepositoryProvider).loadSelectedOrganization();
  }

  Future<void> select(Organization organization) async {
    final current = state.value;
    state = const AsyncLoading();
    try {
      if (current != null && current.code != organization.code) {
        await ref.read(organizationScopedDataCleanerProvider).clearFor(current);
      }
      await ref
          .read(organizationRepositoryProvider)
          .saveSelectedOrganization(organization);
      state = AsyncData(organization);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> changeOrganization() async {
    final current = state.value;
    state = const AsyncLoading();
    try {
      if (current != null) {
        await ref.read(organizationScopedDataCleanerProvider).clearFor(current);
      }
      await ref
          .read(organizationRepositoryProvider)
          .clearSelectedOrganization();
      state = const AsyncData(null);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final organizationLookupProvider =
    AsyncNotifierProvider<OrganizationLookupController, List<Organization>>(
      OrganizationLookupController.new,
    );

class OrganizationLookupController extends AsyncNotifier<List<Organization>> {
  @override
  Future<List<Organization>> build() =>
      ref.watch(organizationRepositoryProvider).fetchTenants();

  Future<void> loadTenants() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
        await ref.read(organizationRepositoryProvider).fetchTenants(),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<Organization?> resolveByCode(String code) async {
    state = const AsyncLoading();
    try {
      final organization = await ref
          .read(organizationRepositoryProvider)
          .resolveByCode(code);
      state = AsyncData([organization]);
      return organization;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<void> searchByName(String query) async {
    state = const AsyncLoading();
    try {
      final organizations = await ref
          .read(organizationRepositoryProvider)
          .searchByName(query);
      state = AsyncData(organizations);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
