import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ParentLinkStudentPage extends StatefulWidget {
  const ParentLinkStudentPage({super.key});

  @override
  State<ParentLinkStudentPage> createState() => _ParentLinkStudentPageState();
}

class _ParentLinkStudentPageState extends State<ParentLinkStudentPage> {
  final _studentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _linkStudent() async {
    final studentUsername = _studentController.text.trim();

    if (studentUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入孩子用户名")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final parentUsername = prefs.getString("username") ?? "";

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse("http://localhost:8080/parent/link-student");

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "parentUsername": parentUsername,
        "studentUsername": studentUsername,
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
      const SnackBar(content: Text("绑定成功")),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _studentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("绑定孩子"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _studentController,
              decoration: const InputDecoration(
                labelText: "孩子用户名",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _linkStudent,
                child: Text(_isLoading ? "绑定中..." : "绑定"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}