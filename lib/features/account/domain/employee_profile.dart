class EmployeeProfile {
  const EmployeeProfile({
    required this.name,
    required this.email,
    required this.employeeCode,
    required this.fatherName,
    required this.cnic,
    required this.designation,
    required this.office,
    required this.campus,
    required this.mobileNumber,
    required this.gender,
    required this.isActive,
    required this.faceEnrolled,
    this.photoUrl,
    this.username = '',
    this.dateOfBirth = '',
    this.address = '',
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.designationGrade = '',
    this.department = '',
    this.reportingTo = '',
    this.mustChangePassword = false,
    this.canMarkAttendance = false,
    this.attendanceReasons = const [],
    this.assignedShift,
    this.security = const EmployeeSecurityProfile(),
  });

  final String name;
  final String email;
  final String employeeCode;
  final String fatherName;
  final String cnic;
  final String designation;
  final String office;
  final String campus;
  final String mobileNumber;
  final String gender;
  final bool isActive;
  final bool faceEnrolled;
  final String? photoUrl;
  final String username;
  final String dateOfBirth;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final String designationGrade;
  final String department;
  final String reportingTo;
  final bool mustChangePassword;
  final bool canMarkAttendance;
  final List<String> attendanceReasons;
  final EmployeeShiftProfile? assignedShift;
  final EmployeeSecurityProfile security;
}

class EmployeeSecurityProfile {
  const EmployeeSecurityProfile({
    this.institutionalCameraAvailable = false,
    this.locationName = '',
    this.deviceId = '',
    this.deviceName = '',
    this.keyFingerprint = '',
    this.deviceEnrolledAt,
    this.totalScans = 0,
    this.averageTrustScore,
    this.highTrustCount = 0,
    this.corroboratedCount = 0,
  });

  final bool institutionalCameraAvailable;
  final String locationName;
  final String deviceId;
  final String deviceName;
  final String keyFingerprint;
  final DateTime? deviceEnrolledAt;
  final int totalScans;
  final double? averageTrustScore;
  final int highTrustCount;
  final int corroboratedCount;

  bool get hasTrustedDevice => deviceId.isNotEmpty;
}

class EmployeeShiftProfile {
  const EmployeeShiftProfile({
    required this.name,
    required this.code,
    required this.startTime,
    required this.endTime,
    required this.gracePeriodMinutes,
    required this.isOvernight,
  });

  final String name;
  final String code;
  final String startTime;
  final String endTime;
  final int gracePeriodMinutes;
  final bool isOvernight;
}
