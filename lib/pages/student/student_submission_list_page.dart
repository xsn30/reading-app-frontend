import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'student_submission_detail_page.dart';

class StudentSubmissionListPage extends StatefulWidget {
  const StudentSubmissionListPage({super.key});

  @override
  State<StudentSubmissionListPage> createState() =>
      _StudentSubmissionListPageState();
}

class _StudentSubmissionListPageState extends State<StudentSubmissionListPage> {
  late Future<List<dynamic>> _futureSubmissions;

  @override
  void initState() {
    super.initState();
    _futureSubmissions = _fetchSubmissions();
  }

  Future<List<dynamic>> _fetchSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/student/submissions?studentUsername=$username',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载提交记录失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("我的提交记录"),
      ),
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
            return const Center(child: Text("暂无提交记录"));
          }

          return ListView.builder(
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final s = submissions[index] as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text("作业ID: ${s['assignmentId']}"),
                  subtitle: Text("得分: ${s['totalScore']} / ${s['maxScore']}"),
                  trailing: Text("${s['submittedAt']}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentSubmissionDetailPage(
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