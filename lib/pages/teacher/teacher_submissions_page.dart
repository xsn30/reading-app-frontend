import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_submission_detail_page.dart';

class TeacherSubmissionsPage extends StatefulWidget {
  final int assignmentId;

  const TeacherSubmissionsPage({super.key, required this.assignmentId});

  @override
  State<TeacherSubmissionsPage> createState() => _TeacherSubmissionsPageState();
}

class _TeacherSubmissionsPageState extends State<TeacherSubmissionsPage> {
  late Future<List<dynamic>> _futureSubmissions;

  @override
  void initState() {
    super.initState();
    _futureSubmissions = _fetchSubmissions();
  }

  Future<List<dynamic>> _fetchSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";
    final uri = Uri.parse(
      'http://localhost:8080/teacher/assignments/${widget.assignmentId}/submissions'
          '?teacherUsername=$teacherUsername',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载提交失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("老师端：提交列表")),
      body: FutureBuilder<List<dynamic>>(
        future: _futureSubmissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("错误: ${snapshot.error}"));
          }

          final submissions = snapshot.data ?? [];
          if (submissions.isEmpty) {
            return const Center(child: Text("暂无提交"));
          }

          return ListView.builder(
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final s = submissions[index] as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text("学生: ${s['studentName']}"),
                  subtitle: Text(
                    "得分: ${s['totalScore']} / ${s['maxScore']}\n提交时间: ${s['submittedAt']}",
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherSubmissionDetailPage(
                          submissionId: (s['id'] as num).toInt(),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}