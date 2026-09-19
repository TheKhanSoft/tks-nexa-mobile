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
