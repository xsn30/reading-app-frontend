import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TeacherSubmissionDetailPage extends StatefulWidget {
  final int submissionId;

  const TeacherSubmissionDetailPage({super.key, required this.submissionId});

  @override
  State<TeacherSubmissionDetailPage> createState() =>
      _TeacherSubmissionDetailPageState();
}

class _TeacherSubmissionDetailPageState
    extends State<TeacherSubmissionDetailPage> {
  late Future<List<dynamic>> _futureAnswers;

  @override
  void initState() {
    super.initState();
    _futureAnswers = _fetchAnswers();
  }

  Future<List<dynamic>> _fetchAnswers() async {
    final uri = Uri.parse(
      'http://localhost:8080/teacher/submissions/${widget.submissionId}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载答案失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("老师端：提交详情")),
      body: FutureBuilder<List<dynamic>>(
        future: _futureAnswers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("错误: ${snapshot.error}"));
          }

          final answers = snapshot.data ?? [];
          if (answers.isEmpty) {
            return const Center(child: Text("没有答案记录"));
          }

          return ListView.builder(
            itemCount: answers.length,
            itemBuilder: (context, index) {
              final a = answers[index] as Map<String, dynamic>;
              final bool correct = (a['correct'] == true);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("题目ID: ${a['questionId']}"),
                      const SizedBox(height: 6),
                      Text("学生答案: ${a['studentAnswer']}"),
                      const SizedBox(height: 6),
                      Text("正确答案: ${a['correctAnswer']}"),
                      const SizedBox(height: 6),
                      Text(
                        correct ? "✅ 正确" : "❌ 错误",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: correct ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text("得分: ${a['scoreEarned']} / ${a['scoreMax']}"),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}