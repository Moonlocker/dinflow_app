import 'package:dinflow_app/app.dart';
import 'package:dinflow_app/features/auth/pages/login_page.dart';
import 'package:dinflow_app/features/dashboard/pages/dashboard_page.dart';
import 'package:dinflow_app/features/shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widgets principais compilam e instanciam', () {
    expect(const DinFlowApp(), isA<DinFlowApp>());
    expect(const LoginPage(), isA<LoginPage>());
    expect(const DashboardPage(), isA<DashboardPage>());
    expect(const AppShell(), isA<AppShell>());
  });
}
