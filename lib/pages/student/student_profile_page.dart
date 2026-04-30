import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  late Future<Map<String, dynamic>> _futureProfile;

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();

  bool _isSaving = false;
  bool _initializedForm = false;

  @override
  void initState() {
    super.initState();
    _futureProfile = _fetchProfile();
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/student/profile?username=$username',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载资料失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes))
    as Map<String, dynamic>;
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("未获取到当前用户名，请重新登录")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final uri = Uri.parse('http://localhost:8080/student/profile');

    final response = await http.put(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "displayName": _displayNameController.text.trim(),
        "email": _emailController.text.trim(),
        "phone": _phoneController.text.trim(),
        "birthday": _birthdayController.text.trim(),
      }),
    );

    setState(() {
      _isSaving = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"].toString())),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("资料保存成功")),
    );

    final newProfile = await _fetchProfile();

    setState(() {
      _futureProfile = Future.value(newProfile);

      _displayNameController.text =
          (newProfile["displayName"] ?? "").toString();
      _emailController.text = (newProfile["email"] ?? "").toString();
      _phoneController.text = (newProfile["phone"] ?? "").toString();
      _birthdayController.text = (newProfile["birthday"] ?? "").toString();

      _initializedForm = true;
    });
  }

  String _formatValue(dynamic value, {String fallback = "暂无"}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  int _calculateCompletionFromProfile(Map<String, dynamic> profile) {
    int filled = 0;

    final name = (profile["displayName"] ?? "").toString().trim();
    final email = (profile["email"] ?? "").toString().trim();
    final phone = (profile["phone"] ?? "").toString().trim();
    final birthday = (profile["birthday"] ?? "").toString().trim();

    if (name.isNotEmpty) filled++;
    if (email.isNotEmpty) filled++;
    if (phone.isNotEmpty) filled++;
    if (birthday.isNotEmpty) filled++;

    return ((filled / 4) * 100).round();
  }

  void _initFormIfNeeded(Map<String, dynamic> profile) {
    if (_initializedForm) return;

    _displayNameController.text = (profile["displayName"] ?? "").toString();
    _emailController.text = (profile["email"] ?? "").toString();
    _phoneController.text = (profile["phone"] ?? "").toString();
    _birthdayController.text = (profile["birthday"] ?? "").toString();

    _initializedForm = true;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("我的资料"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureProfile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("错误: ${snapshot.error}"));
          }

          final profile = snapshot.data ?? {};

          if (profile.containsKey("error")) {
            return Center(
              child: Text(profile["error"].toString()),
            );
          }

          _initFormIfNeeded(profile);

          final completion = _calculateCompletionFromProfile(profile);

          final username = _formatValue(profile["username"]);
          final role = _formatValue(profile["role"]);
          final classroomId = _formatValue(profile["classroomId"]);
          final classroomName = _formatValue(profile["classroomName"]);
          final submissionCount =
          _formatValue(profile["submissionCount"], fallback: "0");
          final latestSubmittedAt = _formatValue(profile["latestSubmittedAt"]);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "基础信息",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text("账号：$username"),
                      const SizedBox(height: 8),
                      Text("角色：$role"),
                      const SizedBox(height: 8),
                      Text("班级名称：$classroomName"),
                      const SizedBox(height: 8),
                      Text("班级 ID：$classroomId"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "学习信息",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text("提交次数：$submissionCount"),
                      const SizedBox(height: 8),
                      Text("最近提交时间：$latestSubmittedAt"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "完善个人资料",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text("资料完成度：$completion%"),
                      const SizedBox(height: 16),
                      _buildEditableField(
                        controller: _displayNameController,
                        label: "姓名 / 昵称",
                      ),
                      _buildEditableField(
                        controller: _emailController,
                        label: "邮箱",
                      ),
                      _buildEditableField(
                        controller: _phoneController,
                        label: "手机号",
                      ),
                      _buildEditableField(
                        controller: _birthdayController,
                        label: "生日",
                        hint: "例如 2003-08-15",
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: Text(_isSaving ? "保存中..." : "保存资料"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}