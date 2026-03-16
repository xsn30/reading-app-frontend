import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/assignment.dart';

class TeacherEditAssignmentPage extends StatefulWidget {
  final Assignment assignment;

  const TeacherEditAssignmentPage({super.key, required this.assignment});

  @override
  State<TeacherEditAssignmentPage> createState() =>
      _TeacherEditAssignmentPageState();
}

class _TeacherEditAssignmentPageState extends State<TeacherEditAssignmentPage> {
  late TextEditingController _titleController;
  late TextEditingController _bookTitleController;
  late TextEditingController _chapterController;
  late TextEditingController _dueDateController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.assignment.title);
    _bookTitleController =
        TextEditingController(text: widget.assignment.bookTitle);
    _chapterController = TextEditingController(text: widget.assignment.chapter);
    _dueDateController = TextEditingController(text: widget.assignment.dueDate);
  }

  Future<void> _saveAssignment() async {
    final title = _titleController.text.trim();
    final bookTitle = _bookTitleController.text.trim();
    final chapter = _chapterController.text.trim();
    final dueDate = _dueDateController.text.trim();

    if (title.isEmpty ||
        bookTitle.isEmpty ||
        chapter.isEmpty ||
        dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请把所有字段填写完整")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final uri = Uri.parse(
      'http://localhost:8080/assignments/${widget.assignment.id}',
    );

    final response = await http.put(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "id": widget.assignment.id,
        "title": title,
        "bookTitle": bookTitle,
        "chapter": chapter,
        "dueDate": dueDate,
        "classroomId": widget.assignment.classroomId,
      }),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("保存失败：HTTP ${response.statusCode}")),
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
        title: const Text("编辑作业信息"),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveAssignment,
                child: Text(_isSubmitting ? "保存中..." : "保存修改"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}