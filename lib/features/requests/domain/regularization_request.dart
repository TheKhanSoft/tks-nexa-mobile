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
    this.employeeName,
    this.employeeCode,
    this.employeeDesignation,
    this.employeePhotoUrl,
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
  final String? employeeName;
  final String? employeeCode;
  final String? employeeDesignation;
  final String? employeePhotoUrl;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
}

class RegularizationMeta {
  const RegularizationMeta({
    this.monthlyLimit = 3,
    this.usedThisMonth = 0,
    this.remainingThisMonth = 3,
    this.maxDaysBack = 7,
    this.suggestedCheckoutTime,
    this.isMissedCheckout = false,
  });

  final int monthlyLimit;
  final int usedThisMonth;
  final int remainingThisMonth;
  final int maxDaysBack;
  final String? suggestedCheckoutTime;
  final bool isMissedCheckout;

  factory RegularizationMeta.fromJson(Map<String, dynamic> json) {
    return RegularizationMeta(
      monthlyLimit: (json['monthly_limit'] as num?)?.toInt() ?? 3,
      usedThisMonth: (json['used_this_month'] as num?)?.toInt() ?? 0,
      remainingThisMonth: (json['remaining_this_month'] as num?)?.toInt() ?? 3,
      maxDaysBack: (json['max_days_back'] as num?)?.toInt() ?? 7,
      suggestedCheckoutTime: json['suggested_checkout_time'] as String?,
      isMissedCheckout: json['is_missed_checkout'] == true,
    );
  }
}
