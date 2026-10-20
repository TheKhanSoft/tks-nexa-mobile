import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/requests/data/requests_api.dart';
import 'package:tks_nexa_attendance/features/requests/domain/leave_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/official_duty_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/regularization_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/team_approval_item.dart';

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

final regularizationsProvider =
    FutureProvider<List<RegularizationRequest>>((ref) {
  return ref.watch(requestsApiProvider).fetchRegularizations();
});

final requestsOverviewProvider = FutureProvider<RequestsOverview>((ref) {
  return ref.watch(requestsApiProvider).fetchRequestsOverview();
});

final pendingLeaveApprovalsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  try {
    return await ref.watch(requestsApiProvider).fetchPendingLeaveApprovals();
  } catch (_) {
    return const [];
  }
});

final pendingDutyApprovalsProvider =
    FutureProvider<List<OfficialDutyRequest>>((ref) async {
  try {
    return await ref.watch(requestsApiProvider).fetchPendingDutyApprovals();
  } catch (_) {
    return const [];
  }
});

final pendingRegularizationApprovalsProvider =
    FutureProvider<List<RegularizationRequest>>((ref) async {
  try {
    return await ref.watch(requestsApiProvider).fetchPendingRegularizationApprovals();
  } catch (_) {
    return const [];
  }
});

final teamApprovalsProvider = FutureProvider<List<TeamApprovalItem>>((ref) async {
  final leaves = await ref.watch(pendingLeaveApprovalsProvider.future);
  final duties = await ref.watch(pendingDutyApprovalsProvider.future);
  final regularizations =
      await ref.watch(pendingRegularizationApprovalsProvider.future);

  final items = <TeamApprovalItem>[
    ...leaves.map(TeamApprovalItem.fromLeave),
    ...duties.map(TeamApprovalItem.fromDuty),
    ...regularizations.map(TeamApprovalItem.fromRegularization),
  ];

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
});

final pendingApprovalsCountProvider = Provider<int>((ref) {
  final overview = ref.watch(requestsOverviewProvider).value;
  if (overview != null && overview.totalPendingApprovals > 0) {
    return overview.totalPendingApprovals;
  }
  final items = ref.watch(teamApprovalsProvider).value;
  return items?.length ?? 0;
});

class ApprovalActionNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> approve(
    TeamApprovalItem item, {
    String? comments,
    int? approvedDaysCount,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(requestsApiProvider);
      switch (item.category) {
        case ApprovalCategory.leave:
          await api.approveLeave(
            item.id,
            comments: comments,
            approvedDaysCount: approvedDaysCount,
          );
          break;
        case ApprovalCategory.officialDuty:
          await api.approveOfficialDuty(item.id, remarks: comments);
          break;
        case ApprovalCategory.regularization:
          await api.approveRegularization(item.id, remarks: comments);
          break;
      }
      _invalidateApprovals();
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> reject(
    TeamApprovalItem item, {
    required String reason,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(requestsApiProvider);
      switch (item.category) {
        case ApprovalCategory.leave:
          await api.rejectLeave(item.id, reason: reason);
          break;
        case ApprovalCategory.officialDuty:
          await api.rejectOfficialDuty(item.id, reason: reason);
          break;
        case ApprovalCategory.regularization:
          await api.rejectRegularization(item.id, reason: reason);
          break;
      }
      _invalidateApprovals();
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  void _invalidateApprovals() {
    ref.invalidate(pendingLeaveApprovalsProvider);
    ref.invalidate(pendingDutyApprovalsProvider);
    ref.invalidate(pendingRegularizationApprovalsProvider);
    ref.invalidate(teamApprovalsProvider);
    ref.invalidate(requestsOverviewProvider);
  }
}

final approvalActionProvider =
    AsyncNotifierProvider<ApprovalActionNotifier, void>(
  ApprovalActionNotifier.new,
);
