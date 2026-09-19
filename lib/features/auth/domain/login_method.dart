enum LoginMethod {
  email('email', 'Email'),
  cnic('cnic', 'CNIC'),
  employeeCode('employee_code', 'Employee ID'),
  username('username', 'Username');

  const LoginMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
