import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/login_response_model.dart';
import '../parent/parent_dashboard_page.dart';
import '../student/student_home_page.dart';
import '../teacher/teacher_home_page.dart';

class SmsLoginPage extends StatefulWidget {
  const SmsLoginPage({super.key});

  @override
  State<SmsLoginPage> createState() => _SmsLoginPageState();
}

class _SmsLoginPageState extends State<SmsLoginPage> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSendingCode = false;
  bool _isLoggingIn = false;
  String? _debugCode;

  Future<void> _sendCode() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    if (username.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入账号和手机号")),
      );
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    final uri = Uri.parse('http://localhost:8080/auth/send-sms-code');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "phone": phone,
      }),
    );

    setState(() {
      _isSendingCode = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"].toString())),
      );
      return;
    }

    setState(() {
      _debugCode = body["code"]?.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("验证码已发送")),
    );
  }

  Future<void> _loginBySms() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (username.isEmpty || phone.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请填写账号、手机号和验证码")),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    final uri = Uri.parse('http://localhost:8080/auth/login-by-sms');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "phone": phone,
        "code": code,
      }),
    );

    setState(() {
      _isLoggingIn = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"].toString())),
      );
      return;
    }

    final loginUser = LoginResponseModel.fromJson(body);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("userId", loginUser.id);
    await prefs.setString("username", loginUser.username);
    await prefs.setString("role", loginUser.role);
    await prefs.setString("linkedStudentUsername", loginUser.linkedStudentUsername);
    await prefs.setString("phone", loginUser.phone);

    if (!mounted) return;

    if (loginUser.role == "student") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomePage()),
      );
    } else if (loginUser.role == "teacher") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherHomePage()),
      );
    } else if (loginUser.role == "parent") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ParentDashboardPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("未知角色")),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("短信验证码登录"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "账号",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "手机号",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "验证码",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSendingCode ? null : _sendCode,
                    child: Text(_isSendingCode ? "发送中..." : "获取验证码"),
                  ),
                ),
              ],
            ),
            if (_debugCode != null) ...[
              const SizedBox(height: 12),
              Text(
                "测试验证码：$_debugCode",
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoggingIn ? null : _loginBySms,
                child: Text(_isLoggingIn ? "登录中..." : "短信登录"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}