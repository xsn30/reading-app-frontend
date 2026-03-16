import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/question.dart';
import 'teacher_edit_question_page.dart';

class TeacherQuestionManagePage extends StatefulWidget {
  final int assignmentId;
  final String assignmentTitle;

  const TeacherQuestionManagePage({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<TeacherQuestionManagePage> createState() =>
      _TeacherQuestionManagePageState();
}

class _TeacherQuestionManagePageState extends State<TeacherQuestionManagePage> {
  late Future<List<Question>> _futureQuestions;

  @override
  void initState() {
    super.initState();
    _futureQuestions = _fetchQuestions();
  }

  Future<List<Question>> _fetchQuestions() async {
    final uri = Uri.parse(
      'http://localhost:8080/assignments/${widget.assignmentId}/questions',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载题目失败：HTTP ${response.statusCode}");
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    return body
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _deleteQuestion(int questionId) async {
    final uri = Uri.parse(
      'http://localhost:8080/questions/$questionId',
    );

    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("删除题目失败：HTTP ${response.statusCode}")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("题目已删除")),
    );

    setState(() {
      _futureQuestions = _fetchQuestions();
    });
  }

  void _confirmDeleteQuestion(int questionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("确认删除"),
        content: const Text("确定要删除这道题吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteQuestion(questionId);
            },
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("管理题目：${widget.assignmentTitle}"),
      ),
      body: FutureBuilder<List<Question>>(
        future: _futureQuestions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("错误: ${snapshot.error}"));
          }

          final questions = snapshot.data ?? [];

          if (questions.isEmpty) {
            return const Center(child: Text("当前没有题目"));
          }

          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "题目 ${index + 1}（${q.type}）",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("题干：${q.text}"),
                      const SizedBox(height: 6),
                      Text("正确答案：${q.correctAnswer}"),
                      const SizedBox(height: 6),
                      Text("分数：${q.score}"),
                      const SizedBox(height: 6),
                      Text("难度：${q.difficulty}"),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeacherEditQuestionPage(
                                    question: q,
                                  ),
                                ),
                              );

                              if (changed == true) {
                                setState(() {
                                  _futureQuestions = _fetchQuestions();
                                });
                              }
                            },
                            child: const Text("编辑"),
                          ),
                          TextButton(
                            onPressed: () {
                              _confirmDeleteQuestion(q.id);
                            },
                            child: const Text("删除"),
                          ),
                        ],
                      ),
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