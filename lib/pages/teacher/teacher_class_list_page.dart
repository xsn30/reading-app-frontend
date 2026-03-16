import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeacherClassListPage extends StatefulWidget {
  const TeacherClassListPage({super.key});

  @override
  State<TeacherClassListPage> createState() => _TeacherClassListPageState();
}

class _TeacherClassListPageState extends State<TeacherClassListPage> {
  late Future<List<dynamic>> _futureClasses;

  @override
  void initState() {
    super.initState();
    _futureClasses = _fetchClasses();
  }

  Future<List<dynamic>> _fetchClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      "http://localhost:8080/classrooms/teacher/$teacherUsername",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载班级失败");
    }

    return json.decode(utf8.decode(response.bodyBytes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("我的班级"),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureClasses,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snapshot.data!;

          if (classes.isEmpty) {
            return const Center(child: Text("暂无班级"));
          }

          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final c = classes[index];

              return ListTile(
                title: Text(c["name"]),
                subtitle: Text("班级ID: ${c["id"]}"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherClassStudentsPage(
                        classId: c["id"],
                        className: c["name"],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class TeacherClassStudentsPage extends StatefulWidget {
  final int classId;
  final String className;

  const TeacherClassStudentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<TeacherClassStudentsPage> createState() =>
      _TeacherClassStudentsPageState();
}

class _TeacherClassStudentsPageState extends State<TeacherClassStudentsPage> {
  late Future<List<dynamic>> _futureStudents;

  @override
  void initState() {
    super.initState();
    _futureStudents = _fetchStudents();
  }

  Future<List<dynamic>> _fetchStudents() async {
    final uri = Uri.parse(
      "http://localhost:8080/classrooms/${widget.classId}/students",
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载学生失败");
    }

    return json.decode(utf8.decode(response.bodyBytes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureStudents,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data!;

          if (students.isEmpty) {
            return const Center(child: Text("暂无学生"));
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final s = students[index];

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(s["username"]),
              );
            },
          );
        },
      ),
    );
  }
}