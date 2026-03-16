import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parent/parent_dashboard_page.dart';
import '../student/student_home_page.dart';
import '../teacher/teacher_home_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _futurePage;

  @override
  void initState() {
    super.initState();
    _futurePage = _checkLogin();
  }

  Future<Widget> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getInt("userId");
    final role = prefs.getString("role");

    if (userId == null || role == null) {
      return const LoginPage();
    }

    if (role == "student") {
      return const StudentHomePage();
    } else if (role == "teacher") {
      return const TeacherHomePage();
    } else if (role == "parent") {
      return const ParentDashboardPage();
    } else {
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _futurePage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text("启动失败"),
            ),
          );
        }

        return snapshot.data ?? const LoginPage();
      },
    );
  }
}