import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeacherCreateClassPage extends StatefulWidget {
  const TeacherCreateClassPage({super.key});

  @override
  State<TeacherCreateClassPage> createState() => _TeacherCreateClassPageState();
}

class _TeacherCreateClassPageState extends State<TeacherCreateClassPage> {
  final _classNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createClassroom() async {
    final name = _classNameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入班级名称")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse("http://localhost:8080/classrooms");

    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "name": name,
        "teacherUsername": teacherUsername,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("班级创建成功")),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("创建班级"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: "班级名称",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createClassroom,
                child: Text(_isLoading ? "创建中..." : "创建班级"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}