import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/assignment.dart';
import '../../utils/logout.dart';
import 'teacher_assignment_manage_page.dart';
import 'teacher_create_assignment_page.dart';

class TeacherAssignmentPage extends StatefulWidget {
  const TeacherAssignmentPage({super.key});

  @override
  State<TeacherAssignmentPage> createState() => _TeacherAssignmentPageState();
}

class _TeacherAssignmentPageState extends State<TeacherAssignmentPage> {
  late Future<List<Assignment>> _futureAssignments;
  Map<int, String> _classroomNameMap = {};

  @override
  void initState() {
    super.initState();
    _futureAssignments = _fetchAssignments();
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

    final Map<int, String> nameMap = {};
    for (final item in body) {
      final classroom = item as Map<String, dynamic>;
      final id = (classroom['id'] as num).toInt();
      final name = (classroom['name'] ?? '') as String;
      nameMap[id] = name;
    }

    if (!mounted) return;

    setState(() {
      _classroomNameMap = nameMap;
    });
  }

  Future<List<Assignment>> _fetchAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/teacher/assignments?teacherUsername=$teacherUsername',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('加载老师端作业失败：HTTP ${response.statusCode}');
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    return body
        .map((item) => Assignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("老师端：作业列表"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "退出登录",
            onPressed: () {
              logout(context);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherCreateAssignmentPage(),
            ),
          );

          if (created == true) {
            setState(() {
              _futureAssignments = _fetchAssignments();
            });
          }
        },
      ),
      body: FutureBuilder<List<Assignment>>(
        future: _futureAssignments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('错误: ${snapshot.error}'));
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return const Center(child: Text("暂无作业"));
          }

          return ListView.builder(
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index];
              final classroomName = _classroomNameMap[a.classroomId] ?? "未知班级";

              return ListTile(
                title: Text(a.title),
                subtitle: Text(
                  "班级：$classroomName\n书名：${a.bookTitle}\n章节：${a.chapter}\n截止日期：${a.dueDate}",
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherAssignmentManagePage(
                        assignment: a,
                      ),
                    ),
                  );

                  if (changed == true) {
                    setState(() {
                      _futureAssignments = _fetchAssignments();
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}