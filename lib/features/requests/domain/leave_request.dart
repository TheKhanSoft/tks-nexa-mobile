class LeaveEntitlement {
  const LeaveEntitlement({
    required this.allocated,
    required this.used,
    required this.pending,
    required this.remaining,
  });

  final double allocated;
  final double used;
  final double pending;
  final double remaining;
}

class LeaveType {
  const LeaveType({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.isPaid,
    required this.defaultDaysAllowed,
    required this.requiresDocument,
    required this.year,
    required this.entitlement,
    this.showBalance = true,
  });

  final int id;
  final String name;
  final String code;
  final String description;
  final bool isPaid;
  final int defaultDaysAllowed;
  final bool requiresDocument;
  final int year;
  final LeaveEntitlement entitlement;
  final bool showBalance;
}

class ApprovalStep {
  const ApprovalStep({
    required this.id,
    required this.approverName,
    required this.action,
    this.comments,
    this.decidedAt,
  });

  final int id;
  final String approverName;
  final String action;
  final String? comments;
  final DateTime? decidedAt;
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.publicId,
    required this.reference,
    required this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.formattedDates,
    required this.daysCount,
    this.approvedDaysCount,
    required this.status,
    required this.reason,
    required this.createdAt,
    this.canCancel = false,
    this.canReschedule = false,
    this.markedToName,
    this.cancellationReason,
    this.cancelledAt,
    this.rescheduledAt,
    this.approvals = const [],
  });

  final int id;
  final String publicId;
  final String reference;
  final String leaveTypeName;
  final DateTime startDate;
  final DateTime endDate;
  final String formattedDates;
  final int daysCount;
  final int? approvedDaysCount;
  final String status;
  final String reason;
  final DateTime createdAt;
  final bool canCancel;
  final bool canReschedule;
  final String? markedToName;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final DateTime? rescheduledAt;
  final List<ApprovalStep> approvals;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isForwarded => status.toLowerCase() == 'forwarded';
}

class RequestsOverview {
  const RequestsOverview({
    this.pendingLeaveRequests = 0,
    this.pendingDutyRequests = 0,
    this.pendingRegularizationRequests = 0,
    this.upcomingApprovedLeaves = const [],
    this.upcomingApprovedDuties = const [],
  });

  final int pendingLeaveRequests;
  final int pendingDutyRequests;
  final int pendingRegularizationRequests;
  final List<LeaveRequest> upcomingApprovedLeaves;
  final List<dynamic> upcomingApprovedDuties;
}

