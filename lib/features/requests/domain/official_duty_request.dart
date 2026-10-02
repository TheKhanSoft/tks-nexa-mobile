class HostOffice {
  const HostOffice({
    required this.id,
    required this.name,
    this.campusName,
  });

  final int id;
  final String name;
  final String? campusName;
}

class OfficialDutyTypeOption {
  const OfficialDutyTypeOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class OfficialDutyRequest {
  const OfficialDutyRequest({
    required this.id,
    required this.publicId,
    required this.reference,
    required this.dutyType,
    required this.dutyTypeLabel,
    required this.startDate,
    required this.endDate,
    required this.formattedDates,
    required this.daysCount,
    required this.location,
    required this.hostOfficeName,
    required this.purpose,
    required this.isRetrospective,
    required this.hasDocument,
    required this.status,
    required this.createdAt,
    this.documentUrl,
    this.approverName,
    this.referenceNumber,
    this.remarks,
  });

  final int id;
  final String publicId;
  final String reference;
  final String dutyType;
  final String dutyTypeLabel;
  final DateTime startDate;
  final DateTime endDate;
  final String formattedDates;
  final int daysCount;
  final String location;
  final String hostOfficeName;
  final String purpose;
  final bool isRetrospective;
  final bool hasDocument;
  final String status;
  final DateTime createdAt;
  final String? documentUrl;
  final String? approverName;
  final String? referenceNumber;
  final String? remarks;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
}
