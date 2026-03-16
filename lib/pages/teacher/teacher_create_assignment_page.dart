import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeacherCreateAssignmentPage extends StatefulWidget {
  const TeacherCreateAssignmentPage({super.key});

  @override
  State<TeacherCreateAssignmentPage> createState() =>
      _TeacherCreateAssignmentPageState();
}

class _TeacherCreateAssignmentPageState
    extends State<TeacherCreateAssignmentPage> {
  final _titleController = TextEditingController();
  final _bookTitleController = TextEditingController();
  final _chapterController = TextEditingController();
  final _dueDateController = TextEditingController();

  bool _isSubmitting = false;
  List<dynamic> _classrooms = [];
  int? _selectedClassroomId;

  @override
  void initState() {
    super.initState();
    _loadTeacherClassrooms();
  }

  Future<void> _loadTeacherClassrooms() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/classrooms/teacher/$teacherUsername',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return;
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    setState(() {
      _classrooms = body;

      if (_classrooms.isNotEmpty) {
        _selectedClassroomId = (_classrooms.first['id'] as num).toInt();
      }
    });
  }

  Future<void> _createAssignment() async {
    final title = _titleController.text.trim();
    final bookTitle = _bookTitleController.text.trim();
    final chapter = _chapterController.text.trim();
    final dueDate = _dueDateController.text.trim();

    if (title.isEmpty || bookTitle.isEmpty || chapter.isEmpty || dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请把所有字段填写完整")),
      );
      return;
    }

    if (_selectedClassroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请先选择班级")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    setState(() {
      _isSubmitting = true;
    });

    final uri = Uri.parse('http://localhost:8080/teacher/assignments');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "title": title,
        "bookTitle": bookTitle,
        "chapter": chapter,
        "dueDate": dueDate,
        "classroomId": _selectedClassroomId,
        "teacherUsername": teacherUsername,
      }),
    );

    setState(() {
      _isSubmitting = false;
    });

    final dynamic body = json.decode(utf8.decode(response.bodyBytes));

    if (body is Map<String, dynamic> && body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("创建失败：HTTP ${response.statusCode}")),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bookTitleController.dispose();
    _chapterController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("老师端：创建作业"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "作业标题",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bookTitleController,
              decoration: const InputDecoration(
                labelText: "书名",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chapterController,
              decoration: const InputDecoration(
                labelText: "章节",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dueDateController,
              decoration: const InputDecoration(
                labelText: "截止日期（例如 2026-04-01）",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_classrooms.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text("当前没有班级，请先创建班级"),
              )
            else
              DropdownButtonFormField<int>(
                value: _selectedClassroomId,
                decoration: const InputDecoration(
                  labelText: "选择班级",
                  border: OutlineInputBorder(),
                ),
                items: _classrooms.map((c) {
                  return DropdownMenuItem<int>(
                    value: (c['id'] as num).toInt(),
                    child: Text("${c['name']}（班级ID: ${c['id']}）"),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassroomId = value;
                  });
                },
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createAssignment,
                child: Text(_isSubmitting ? "提交中..." : "创建作业"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}