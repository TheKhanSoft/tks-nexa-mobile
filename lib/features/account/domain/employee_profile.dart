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

  EmployeeProfile copyWith({
    String? name,
    String? email,
    String? employeeCode,
    String? fatherName,
    String? cnic,
    String? designation,
    String? office,
    String? campus,
    String? mobileNumber,
    String? gender,
    bool? isActive,
    bool? faceEnrolled,
    String? photoUrl,
    String? username,
    String? dateOfBirth,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? designationGrade,
    String? department,
    String? reportingTo,
    bool? mustChangePassword,
    bool? canMarkAttendance,
    List<String>? attendanceReasons,
    EmployeeShiftProfile? assignedShift,
    EmployeeSecurityProfile? security,
  }) {
    return EmployeeProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      employeeCode: employeeCode ?? this.employeeCode,
      fatherName: fatherName ?? this.fatherName,
      cnic: cnic ?? this.cnic,
      designation: designation ?? this.designation,
      office: office ?? this.office,
      campus: campus ?? this.campus,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      faceEnrolled: faceEnrolled ?? this.faceEnrolled,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      designationGrade: designationGrade ?? this.designationGrade,
      department: department ?? this.department,
      reportingTo: reportingTo ?? this.reportingTo,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      canMarkAttendance: canMarkAttendance ?? this.canMarkAttendance,
      attendanceReasons: attendanceReasons ?? this.attendanceReasons,
      assignedShift: assignedShift ?? this.assignedShift,
      security: security ?? this.security,
    );
  }
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
