import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isSendingCode = false;
  bool _isResetting = false;
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

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (body["error"] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"].toString())),
      );
      return;
    }

    setState(() {
      _debugCode = body["code"]?.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("验证码已发送（当前为测试模式）")),
    );
  }

  Future<void> _resetPassword() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (username.isEmpty ||
        phone.isEmpty ||
        code.isEmpty ||
        newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请填写完整信息")),
      );
      return;
    }

    setState(() {
      _isResetting = true;
    });

    final uri = Uri.parse(
      'http://localhost:8080/auth/reset-password-by-sms',
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "phone": phone,
        "code": code,
        "newPassword": newPassword,
      }),
    );

    setState(() {
      _isResetting = false;
    });

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (body["error"] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"].toString())),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("密码重置成功，请返回登录")),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("忘记密码"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildField(
              controller: _usernameController,
              label: "账号",
            ),
            _buildField(
              controller: _phoneController,
              label: "手机号",
              keyboardType: TextInputType.phone,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _codeController,
                    label: "验证码",
                    keyboardType: TextInputType.number,
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
            _buildField(
              controller: _newPasswordController,
              label: "新密码",
              obscureText: true,
            ),
            if (_debugCode != null) ...[
              const SizedBox(height: 8),
              Text(
                "测试验证码：$_debugCode",
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResetting ? null : _resetPassword,
                child: Text(_isResetting ? "提交中..." : "重置密码"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}