import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/question.dart';

class AssignmentDetailPage extends StatefulWidget {
  final int assignmentId;
  final String assignmentTitle;

  const AssignmentDetailPage({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  late Future<List<Question>> _futureQuestions;

  final Map<int, String> _mcqSelected = {};
  final Map<int, TextEditingController> _shortControllers = {};
  Map<int, bool> _questionResults = {};
  bool _draftLoaded = false;

  @override
  void initState() {
    super.initState();
    _futureQuestions = _fetchQuestions(widget.assignmentId);
  }

  Future<List<Question>> _fetchQuestions(int assignmentId) async {
    final uri = Uri.parse(
      'http://localhost:8080/assignments/$assignmentId/questions',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('加载题目失败');
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    return body
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String get _draftPrefix => 'draft_${widget.assignmentId}_';

  String _mcqKey(int questionId) => '${_draftPrefix}mcq_$questionId';
  String _shortKey(int questionId) => '${_draftPrefix}short_$questionId';

  Future<void> _saveMcqDraft(int questionId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mcqKey(questionId), value);
  }

  Future<void> _saveShortDraft(int questionId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shortKey(questionId), value);
  }

  Future<void> _loadDrafts(List<Question> questions) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (final q in questions) {
        if (q.type.toUpperCase() == 'MCQ') {
          final saved = prefs.getString(_mcqKey(q.id));
          if (saved != null && saved.isNotEmpty) {
            _mcqSelected[q.id] = saved;
          }
        }

        if (q.type.toUpperCase() == 'SHORT') {
          final saved = prefs.getString(_shortKey(q.id)) ?? '';
          _shortControllers.putIfAbsent(q.id, () => TextEditingController());
          _shortControllers[q.id]!.text = saved;
        }
      }
    });
  }

  Future<void> _submitAnswers() async {
    final List<Map<String, dynamic>> answers = [];

    _mcqSelected.forEach((questionId, selected) {
      answers.add({
        "questionId": questionId,
        "answer": selected,
      });
    });

    _shortControllers.forEach((questionId, controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        answers.add({
          "questionId": questionId,
          "answer": text,
        });
      }
    });

    final uri = Uri.parse(
      'http://localhost:8080/assignments/${widget.assignmentId}/submit',
    );

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "studentName": username,
        "answers": answers,
      }),
    );

    if (response.statusCode != 200) {
      _showDialog('提交失败', 'HTTP ${response.statusCode}\n${response.body}');
      return;
    }

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      _showDialog("提交失败", body["error"].toString());
      return;
    }

    final totalScore = body["totalScore"];
    final maxScore = body["maxScore"];
    final List results = body["results"];

    setState(() {
      _questionResults.clear();
      for (var r in results) {
        _questionResults[r["questionId"]] = r["correct"];
      }
    });

    _showDialog('提交成功', '得分：$totalScore / $maxScore');
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMcqOptions(Question q) {
    String? selected = _mcqSelected[q.id];
    const letters = ["A", "B", "C", "D"];

    return List.generate(q.options.length, (index) {
      final opt = q.options[index];
      final letter = index < letters.length ? letters[index] : "";

      return RadioListTile<String>(
        value: letter,
        groupValue: selected,
        title: Text("$letter. $opt"),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _mcqSelected[q.id] = v;
          });
          _saveMcqDraft(q.id, v);
        },
      );
    });
  }

  Widget _buildShortAnswerBox(Question q) {
    _shortControllers.putIfAbsent(q.id, () => TextEditingController());

    return TextField(
      controller: _shortControllers[q.id],
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: '请输入你的答案（会自动保存草稿）',
      ),
      onChanged: (text) {
        _saveShortDraft(q.id, text);
      },
    );
  }

  @override
  void dispose() {
    for (final c in _shortControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignmentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: '提交',
            onPressed: _submitAnswers,
          ),
        ],
      ),
      body: FutureBuilder<List<Question>>(
        future: _futureQuestions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('错误: ${snapshot.error}'));
          }

          final questions = snapshot.data ?? [];

          if (!_draftLoaded) {
            _draftLoaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadDrafts(questions);
            });
          }

          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              final displayIndex = index + 1;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Q$displayIndex. ${q.text}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_questionResults.containsKey(q.id))
                            Text(
                              _questionResults[q.id]! ? "✅" : "❌",
                              style: const TextStyle(fontSize: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (q.type.toUpperCase() == 'MCQ') ...[
                        ..._buildMcqOptions(q),
                      ],

                      if (q.type.toUpperCase() == 'SHORT') ...[
                        _buildShortAnswerBox(q),
                      ],

                      if (q.type.toUpperCase() != 'MCQ' &&
                          q.type.toUpperCase() != 'SHORT')
                        Text('暂不支持题型：${q.type}'),
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