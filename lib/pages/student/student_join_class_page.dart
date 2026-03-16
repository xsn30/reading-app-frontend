import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentJoinClassPage extends StatefulWidget {
  const StudentJoinClassPage({super.key});

  @override
  State<StudentJoinClassPage> createState() => _StudentJoinClassPageState();
}

class _StudentJoinClassPageState extends State<StudentJoinClassPage> {
  final _classroomIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinClassroom() async {
    final classroomIdText = _classroomIdController.text.trim();

    if (classroomIdText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入班级ID")),
      );
      return;
    }

    final classroomId = int.tryParse(classroomIdText);
    if (classroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("班级ID必须是数字")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("当前未获取到学生用户名，请重新登录")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(
      'http://localhost:8080/classrooms/$classroomId/join',
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "studentUsername": username,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("加入班级成功")),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _classroomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("加入班级"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _classroomIdController,
              decoration: const InputDecoration(
                labelText: "请输入班级ID",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinClassroom,
                child: Text(_isLoading ? "加入中..." : "加入班级"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}