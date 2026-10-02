import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/requests/data/requests_api.dart';
import 'package:tks_nexa_attendance/features/requests/domain/leave_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/official_duty_request.dart';

final requestsApiProvider = Provider<RequestsApi>((ref) {
  final organization = ref.watch(organizationSessionProvider).value;
  final session = ref.watch(currentAuthSessionProvider);
  if (organization == null || session == null) {
    throw StateError('An authenticated tenant session is required.');
  }
  return RequestsApi(
    DioFactory.createTenantClient(
      ref.watch(appConfigProvider),
      organization.apiBaseUri,
    ),
    session.accessToken,
  );
});

final leaveTypesProvider = FutureProvider<List<LeaveType>>((ref) {
  return ref.watch(requestsApiProvider).fetchLeaveTypes();
});

final leaveRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) {
  return ref.watch(requestsApiProvider).fetchLeaveRequests();
});

final hostOfficesProvider = FutureProvider<List<HostOffice>>((ref) {
  return ref.watch(requestsApiProvider).fetchHostOffices();
});

final officialDutyRequestsProvider =
    FutureProvider<List<OfficialDutyRequest>>((ref) {
  return ref.watch(requestsApiProvider).fetchOfficialDutyRequests();
});

final requestsOverviewProvider = FutureProvider<RequestsOverview>((ref) {
  return ref.watch(requestsApiProvider).fetchRequestsOverview();
});
