import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/account/presentation/employee_avatar.dart';

void main() {
  Widget subject({
    required String photoUrl,
    String? authToken,
    String? developmentConnectHost,
    int? developmentConnectPort,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EmployeeAvatar(
          name: 'Example Employee',
          photoUrl: photoUrl,
          authToken: authToken,
          developmentConnectHost: developmentConnectHost,
          developmentConnectPort: developmentConnectPort,
        ),
      ),
    );
  }

  testWidgets('loads a temporary signed photo URL without bearer headers', (
    tester,
  ) async {
    const url =
        'https://tenant.example/file/employee.jpg?expires=1789623817&signature=abc123';
    await tester.pumpWidget(subject(photoUrl: url));

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(provider.url, url);
    expect(provider.headers, isNull);
  });

  testWidgets('uses a bearer header for an unsigned native photo URL', (
    tester,
  ) async {
    const url = 'https://tenant.example/file/employee.jpg';
    await tester.pumpWidget(subject(photoUrl: url, authToken: 'sanctum-token'));

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(provider.url, url);
    expect(provider.headers, {'Authorization': 'Bearer sanctum-token'});
  });

  testWidgets('routes a local photo through the native development bridge', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        photoUrl:
            'http://awkum.localhost:8000/file/employee.jpg?expires=1789623817&signature=abc123',
        developmentConnectHost: '10.10.190.46',
        developmentConnectPort: 8001,
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(
      provider.url,
      'http://10.10.190.46:8001/file/employee.jpg?expires=1789623817&signature=abc123',
    );
    expect(provider.headers, {'Host': 'awkum.localhost:8000'});
  });

  testWidgets('does not request an unsigned photo without authentication', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(photoUrl: 'https://tenant.example/file/employee.jpg'),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('EE'), findsOneWidget);
  });

  testWidgets('rejects non-local insecure photo URLs', (tester) async {
    await tester.pumpWidget(
      subject(
        photoUrl:
            'http://tenant.example/file/employee.jpg?expires=1789623817&signature=abc123',
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('EE'), findsOneWidget);
  });
}
