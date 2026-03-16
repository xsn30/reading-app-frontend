import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_submission_detail_page.dart';

class TeacherSubmissionStatusPage extends StatefulWidget {
  final int assignmentId;
  final String assignmentTitle;

  const TeacherSubmissionStatusPage({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<TeacherSubmissionStatusPage> createState() =>
      _TeacherSubmissionStatusPageState();
}

class _TeacherSubmissionStatusPageState
    extends State<TeacherSubmissionStatusPage> {
  late Future<List<dynamic>> _futureStatus;

  @override
  void initState() {
    super.initState();
    _futureStatus = _fetchStatus();
  }

  Future<List<dynamic>> _fetchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/teacher/assignments/${widget.assignmentId}/submission-status'
          '?teacherUsername=$teacherUsername',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载提交状态失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("提交状态：${widget.assignmentTitle}"),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureStatus,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("错误: ${snapshot.error}"));
          }

          final statusList = snapshot.data ?? [];

          if (statusList.isEmpty) {
            return const Center(child: Text("当前班级暂无学生"));
          }

          final unsubmittedStudents = statusList
              .where((s) => s["submitted"] != true)
              .cast<Map<String, dynamic>>()
              .toList();

          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "未提交学生（${unsubmittedStudents.length}人）",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (unsubmittedStudents.isEmpty)
                        const Text("所有学生都已提交")
                      else
                        ...unsubmittedStudents.map((student) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text("• ${student['studentUsername']}"),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "全部学生提交状态",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...statusList.map((item) {
                final s = item as Map<String, dynamic>;
                final bool submitted = s["submitted"] == true;

                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    title: Text("学生: ${s['studentUsername']}"),
                    subtitle: submitted
                        ? Text(
                      "状态: 已提交\n得分: ${s['totalScore']} / ${s['maxScore']}\n提交时间: ${s['submittedAt']}",
                    )
                        : const Text("状态: 未提交"),
                    isThreeLine: submitted,
                    trailing: Icon(
                      submitted ? Icons.chevron_right : Icons.hourglass_empty,
                    ),
                    onTap: submitted
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeacherSubmissionDetailPage(
                            submissionId:
                            (s['submissionId'] as num).toInt(),
                          ),
                        ),
                      );
                    }
                        : null,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}