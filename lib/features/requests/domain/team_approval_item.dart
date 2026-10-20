import 'package:tks_nexa_attendance/features/requests/domain/leave_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/official_duty_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/regularization_request.dart';

enum ApprovalCategory { leave, officialDuty, regularization }

class TeamApprovalItem {
  const TeamApprovalItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.dateDisplay,
    required this.reason,
    required this.createdAt,
    this.employeeName,
    this.employeeCode,
    this.employeeDesignation,
    this.employeePhotoUrl,
    this.daysCount,
    this.leaveRequest,
    this.dutyRequest,
    this.regularizationRequest,
  });

  final int id;
  final ApprovalCategory category;
  final String title;
  final String subtitle;
  final String dateDisplay;
  final String reason;
  final DateTime createdAt;
  final String? employeeName;
  final String? employeeCode;
  final String? employeeDesignation;
  final String? employeePhotoUrl;
  final int? daysCount;
  final LeaveRequest? leaveRequest;
  final OfficialDutyRequest? dutyRequest;
  final RegularizationRequest? regularizationRequest;

  String get categoryLabel => switch (category) {
        ApprovalCategory.leave => 'Leave',
        ApprovalCategory.officialDuty => 'Official Duty',
        ApprovalCategory.regularization => 'Regularization',
      };

  factory TeamApprovalItem.fromLeave(LeaveRequest leave) {
    return TeamApprovalItem(
      id: leave.id,
      category: ApprovalCategory.leave,
      title: leave.leaveTypeName,
      subtitle: '${leave.daysCount} ${leave.daysCount == 1 ? "day" : "days"} (${leave.formattedDates})',
      dateDisplay: leave.formattedDates,
      reason: leave.reason,
      createdAt: leave.createdAt,
      employeeName: leave.employeeName,
      employeeCode: leave.employeeCode,
      employeeDesignation: leave.employeeDesignation,
      employeePhotoUrl: leave.employeePhotoUrl,
      daysCount: leave.daysCount,
      leaveRequest: leave,
    );
  }

  factory TeamApprovalItem.fromDuty(OfficialDutyRequest duty) {
    return TeamApprovalItem(
      id: duty.id,
      category: ApprovalCategory.officialDuty,
      title: duty.dutyTypeLabel,
      subtitle: '${duty.hostOfficeName} • ${duty.daysCount} ${duty.daysCount == 1 ? "day" : "days"}',
      dateDisplay: duty.formattedDates,
      reason: duty.purpose,
      createdAt: duty.createdAt,
      employeeName: duty.employeeName,
      employeeCode: duty.employeeCode,
      employeeDesignation: duty.employeeDesignation,
      employeePhotoUrl: duty.employeePhotoUrl,
      daysCount: duty.daysCount,
      dutyRequest: duty,
    );
  }

  factory TeamApprovalItem.fromRegularization(RegularizationRequest reg) {
    return TeamApprovalItem(
      id: reg.id,
      category: ApprovalCategory.regularization,
      title: '${reg.punchTypeLabel} Regularization',
      subtitle: 'Date: ${reg.formattedDate}${reg.formattedTime != null ? " • Time: ${reg.formattedTime}" : ""}',
      dateDisplay: reg.formattedDate,
      reason: reg.employeeRemarks != null && reg.employeeRemarks!.isNotEmpty
          ? '${reg.reasonLabel}: ${reg.employeeRemarks}'
          : reg.reasonLabel,
      createdAt: reg.createdAt,
      employeeName: reg.employeeName,
      employeeCode: reg.employeeCode,
      employeeDesignation: reg.employeeDesignation,
      employeePhotoUrl: reg.employeePhotoUrl,
      regularizationRequest: reg,
    );
  }
}
