class RegularizationRequest {
  const RegularizationRequest({
    required this.id,
    required this.publicId,
    required this.reference,
    required this.date,
    required this.formattedDate,
    required this.punchType,
    required this.punchTypeLabel,
    this.requestedPunchTime,
    this.formattedTime,
    required this.reason,
    required this.reasonLabel,
    this.employeeRemarks,
    required this.status,
    required this.statusLabel,
    this.approverName,
    this.approverRemarks,
    this.decisionAt,
    required this.createdAt,
  });

  final int id;
  final String publicId;
  final String reference;
  final DateTime date;
  final String formattedDate;
  final String punchType;
  final String punchTypeLabel;
  final String? requestedPunchTime;
  final String? formattedTime;
  final String reason;
  final String reasonLabel;
  final String? employeeRemarks;
  final String status;
  final String statusLabel;
  final String? approverName;
  final String? approverRemarks;
  final DateTime? decisionAt;
  final DateTime createdAt;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
}
