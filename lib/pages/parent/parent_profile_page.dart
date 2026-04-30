import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ParentProfilePage extends StatefulWidget {
  const ParentProfilePage({super.key});

  @override
  State<ParentProfilePage> createState() => _ParentProfilePageState();
}

class _ParentProfilePageState extends State<ParentProfilePage> {
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

    final uri =
    Uri.parse("http://localhost:8080/parent/profile?username=$username");

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载资料失败");
    }

    return json.decode(utf8.decode(response.bodyBytes));
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    setState(() {
      _isSaving = true;
    });

    final uri = Uri.parse("http://localhost:8080/parent/profile");

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

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (body["error"] != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(body["error"])));
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("资料保存成功")));

    final newProfile = await _fetchProfile();

    setState(() {
      _futureProfile = Future.value(newProfile);

      _displayNameController.text =
          (newProfile["displayName"] ?? "").toString();
      _emailController.text =
          (newProfile["email"] ?? "").toString();
      _phoneController.text =
          (newProfile["phone"] ?? "").toString();
      _birthdayController.text =
          (newProfile["birthday"] ?? "").toString();

      _initializedForm = true;
    });
  }

  void _initFormIfNeeded(Map<String, dynamic> profile) {
    if (_initializedForm) return;

    _displayNameController.text = profile["displayName"] ?? "";
    _emailController.text = profile["email"] ?? "";
    _phoneController.text = profile["phone"] ?? "";
    _birthdayController.text = profile["birthday"] ?? "";

    _initializedForm = true;
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
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

    final result = ((filled / 4) * 100).round();

    return result;
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data!;

          _initFormIfNeeded(profile);


          final completion = _calculateCompletionFromProfile(profile);

          final children = profile["children"] ?? [];


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
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text("账号：${profile["username"] ?? ""}"),
                      const SizedBox(height: 8),
                      Text("角色：${profile["role"] ?? ""}"),
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
                        "孩子信息",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      if (children.isEmpty)
                        const Text("暂无孩子")
                      else
                        ...children.map<Widget>((child) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text("• ${child["username"]}"),
                          );
                        }).toList(),
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
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text("资料完成度：$completion%"),
                      const SizedBox(height: 16),

                      _buildEditableField(
                          controller: _displayNameController, label: "姓名 / 昵称"),

                      _buildEditableField(
                          controller: _emailController, label: "邮箱"),

                      _buildEditableField(
                          controller: _phoneController, label: "手机号"),

                      _buildEditableField(
                          controller: _birthdayController, label: "生日"),

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