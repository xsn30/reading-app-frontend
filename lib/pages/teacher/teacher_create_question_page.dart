import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TeacherCreateQuestionPage extends StatefulWidget {
  final int assignmentId;

  const TeacherCreateQuestionPage({super.key, required this.assignmentId});

  @override
  State<TeacherCreateQuestionPage> createState() =>
      _TeacherCreateQuestionPageState();
}

class _TeacherCreateQuestionPageState extends State<TeacherCreateQuestionPage> {
  String _type = "MCQ";

  final _textController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  final _scoreController = TextEditingController();
  final _difficultyController = TextEditingController();

  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _createQuestion() async {
    final text = _textController.text.trim();
    final correctAnswer = _correctAnswerController.text.trim();
    final scoreText = _scoreController.text.trim();
    final difficulty = _difficultyController.text.trim();

    if (text.isEmpty || correctAnswer.isEmpty || scoreText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请填写完整题目信息")),
      );
      return;
    }

    final int? score = int.tryParse(scoreText);
    if (score == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("分数必须是数字")),
      );
      return;
    }

    List<String> options = [];
    if (_type == "MCQ") {
      options = [
        _optionAController.text.trim(),
        _optionBController.text.trim(),
        _optionCController.text.trim(),
        _optionDController.text.trim(),
      ];

      if (options.any((o) => o.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("选择题的四个选项都要填写")),
        );
        return;
      }
      if (!["A", "B", "C", "D"].contains(correctAnswer.toUpperCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("选择题正确答案必须填写 A、B、C 或 D")),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    final uri = Uri.parse(
      'http://localhost:8080/teacher/assignments/${widget.assignmentId}/questions',
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "assignmentId": widget.assignmentId,
        "type": _type,
        "text": text,
        "options": options,
        "correctAnswer": _type == "MCQ"
            ? correctAnswer.toUpperCase()
            : correctAnswer,
        "score": score,
        "difficulty": difficulty.isEmpty ? "MEDIUM" : difficulty,
      }),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("创建题目失败：HTTP ${response.statusCode}")),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("题目创建成功")),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _correctAnswerController.dispose();
    _scoreController.dispose();
    _difficultyController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("老师端：添加题目"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: "题型",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "MCQ", child: Text("选择题")),
                DropdownMenuItem(value: "SHORT", child: Text("简答题")),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: "题干",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (_type == "MCQ") ...[
              TextField(
                controller: _optionAController,
                decoration: const InputDecoration(
                  labelText: "选项 A",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _optionBController,
                decoration: const InputDecoration(
                  labelText: "选项 B",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _optionCController,
                decoration: const InputDecoration(
                  labelText: "选项 C",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _optionDController,
                decoration: const InputDecoration(
                  labelText: "选项 D",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _correctAnswerController,
              decoration: const InputDecoration(
                labelText: "正确答案（MCQ填 A/B/C/D，不要填选项内容；简答填参考答案）",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scoreController,
              decoration: const InputDecoration(
                labelText: "分数",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _difficultyController,
              decoration: const InputDecoration(
                labelText: "难度（例如 EASY / MEDIUM / HARD）",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createQuestion,
                child: Text(_isSubmitting ? "提交中..." : "创建题目"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}