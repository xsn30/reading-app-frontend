import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class Assignment {
  final int id;
  final String title;
  final String bookTitle;
  final String chapter;
  final String dueDate;

  Assignment({
    required this.id,
    required this.title,
    required this.bookTitle,
    required this.chapter,
    required this.dueDate,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      bookTitle: (json['bookTitle'] ?? '') as String,
      chapter: (json['chapter'] ?? '') as String,
      dueDate: (json['dueDate'] ?? '') as String,
    );
  }
}
class Question {
  final int id;
  final int assignmentId;
  final String type; // "MCQ" / "SHORT"
  final String text;
  final List<String> options;
  final int score; // 可选字段（你后端有 score 的话）
  final String difficulty; // 可选字段

  Question({
    required this.id,
    required this.assignmentId,
    required this.type,
    required this.text,
    required this.options,
    required this.score,
    required this.difficulty,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];

    // 有的后端会返回 options: []，有的可能是 null
    final List<String> options = (rawOptions is List)
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];

    return Question(
      id: (json['id'] as num).toInt(),
      assignmentId: (json['assignmentId'] as num).toInt(),
      type: (json['type'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      options: options,
      score: (json['score'] is num) ? (json['score'] as num).toInt() : 1,
      difficulty: (json['difficulty'] ?? '') as String,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '阅读作业',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RoleSelectionPage(),
    );
  }
}

/// 作业列表页（主页）
class AssignmentListPage extends StatefulWidget {
  const AssignmentListPage({super.key});

  @override
  State<AssignmentListPage> createState() => _AssignmentListPageState();
}

class _AssignmentListPageState extends State<AssignmentListPage> {
  late Future<List<Assignment>> _futureAssignments;

  @override
  void initState() {
    super.initState();
    _futureAssignments = _fetchAssignments();
  }

  /// 去后端拉取作业列表
  Future<List<Assignment>> _fetchAssignments() async {
    // 注意：这里用的就是你现在的后端地址
    final uri = Uri.parse('http://localhost:8080/assignments');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('加载失败：HTTP ${response.statusCode}');
    }

    // 后端返回的是一个 Page 对象，里面有 content 数组
    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> content = body['content'] as List<dynamic>;

    return content
        .map((item) => Assignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('作业列表'),
      ),
      body: FutureBuilder<List<Assignment>>(
        future: _futureAssignments,
        builder: (context, snapshot) {
          // 1. 正在加载：转圈
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. 出错：显示错误信息
          if (snapshot.hasError) {
            return Center(
              child: Text('出错了：${snapshot.error}'),
            );
          }

          final assignments = snapshot.data ?? [];

          // 3. 没有数据
          if (assignments.isEmpty) {
            return const Center(child: Text('暂时没有作业'));
          }

          // 4. 正常显示列表
          return ListView.builder(
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index]; // ✅ a 在这里定义

              return ListTile(
                title: Text(a.title),
                subtitle: Text('截止日期：${a.dueDate}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignmentDetailPage(
                        assignmentId: a.id,
                        assignmentTitle: a.title,
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

  @override
  void initState() {
    super.initState();
    _futureQuestions = _fetchQuestions(widget.assignmentId);
  }

  Future<List<Question>> _fetchQuestions(int assignmentId) async {
    final uri = Uri.parse('http://localhost:8080/assignments/$assignmentId/questions');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('加载题目失败');
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    return body
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList();
  }
  // 给每个作业一个独立前缀，避免不同作业互相覆盖
  String get _draftPrefix => 'draft_${widget.assignmentId}_';

  String _mcqKey(int questionId) => '${_draftPrefix}mcq_$questionId';
  String _shortKey(int questionId) => '${_draftPrefix}short_$questionId';

// 保存某题 MCQ
  Future<void> _saveMcqDraft(int questionId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mcqKey(questionId), value);
  }

// 保存某题 SHORT
  Future<void> _saveShortDraft(int questionId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shortKey(questionId), value);
  }

// 进入页面后：把草稿从本地读出来，恢复到 UI
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
  final Map<int, String> _mcqSelected = {};      // questionId -> "A"/"B"/...
  final Map<int, TextEditingController> _shortControllers = {}; // questionId -> controller
  Map<int, bool> _questionResults = {};
  bool _draftLoaded = false;
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
          // 第一次拿到 questions 时，把草稿恢复出来
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
                      // 题干
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Q$displayIndex. ${q.text}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

                      // MCQ：显示选项 + 单选
                      if (q.type.toUpperCase() == 'MCQ') ...[
                        ..._buildMcqOptions(q),
                      ],

                      // SHORT：显示文本框
                      if (q.type.toUpperCase() == 'SHORT') ...[
                        _buildShortAnswerBox(q),
                      ],

                      // 其他类型兜底
                      if (q.type.toUpperCase() != 'MCQ' && q.type.toUpperCase() != 'SHORT')
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
  @override
  void dispose() {
    for (final c in _shortControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
  Future<void> _submitAnswers() async {
    // 1) 组装 answers
    final List<Map<String, dynamic>> answers = [];

    // MCQ：把选中的 "A"/"B" 之类放进去
    _mcqSelected.forEach((questionId, selected) {
      answers.add({
        "questionId": questionId,
        "answer": selected,
      });
    });

    // SHORT：把文本框内容放进去
    _shortControllers.forEach((questionId, controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        answers.add({
          "questionId": questionId,
          "answer": text,
        });
      }
    });

    // 2) POST 到后端
    final uri = Uri.parse(
      'http://localhost:8080/assignments/${widget.assignmentId}/submit',
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({"answers": answers}),
    );

    if (response.statusCode != 200) {
      _showDialog('提交失败', 'HTTP ${response.statusCode}\n${response.body}');
      return;
    }

    // 3) 解析返回结果
    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

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
    // 后端 options 通常是 ["A. ...", "B. ..."]，我们要提取字母 A/B/C/D
    String? selected = _mcqSelected[q.id];

    return q.options.map((opt) {
      // 提取选项字母（如果格式是 "A. xxx"）
      String letter = opt.isNotEmpty ? opt.trim()[0] : '';

      return RadioListTile<String>(
        value: letter,
        groupValue: selected,
        title: Text(opt),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _mcqSelected[q.id] = v;
          });
          _saveMcqDraft(q.id, v);
        },
      );
    }).toList();
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
        _saveShortDraft(q.id, text); // ✅ 自动保存
      },
    );
  }
}
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
    final uri = Uri.parse(
      'http://localhost:8080/teacher/assignments/${widget.assignmentId}/submissions',
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

              return ListTile(
                title: Text("学生: ${s['studentName']}"),
                subtitle: Text("得分: ${s['totalScore']} / ${s['maxScore']}"),
                trailing: Text("${s['submittedAt']}"),
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
              );
            },
          );
        },
      ),
    );
  }
}

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
class TeacherAssignmentPage extends StatefulWidget {
  const TeacherAssignmentPage({super.key});

  @override
  State<TeacherAssignmentPage> createState() => _TeacherAssignmentPageState();
}

class _TeacherAssignmentPageState extends State<TeacherAssignmentPage> {
  late Future<List<Assignment>> _futureAssignments;

  @override
  void initState() {
    super.initState();
    _futureAssignments = _fetchAssignments();
  }

  Future<List<Assignment>> _fetchAssignments() async {
    final uri = Uri.parse('http://localhost:8080/assignments');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('加载老师端作业失败：HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> content = body['content'] as List<dynamic>;

    return content
        .map((item) => Assignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("老师端：作业列表"),
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

              return ListTile(
                title: Text(a.title),
                subtitle: Text(
                  "书名：${a.bookTitle}\n章节：${a.chapter}\n截止日期：${a.dueDate}",
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherAssignmentManagePage(
                        assignment: a,
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
class TeacherCreateAssignmentPage extends StatefulWidget {
  const TeacherCreateAssignmentPage({super.key});

  @override
  State<TeacherCreateAssignmentPage> createState() =>
      _TeacherCreateAssignmentPageState();
}

class _TeacherCreateAssignmentPageState
    extends State<TeacherCreateAssignmentPage> {
  final _titleController = TextEditingController();
  final _bookTitleController = TextEditingController();
  final _chapterController = TextEditingController();
  final _dueDateController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _createAssignment() async {
    final title = _titleController.text.trim();
    final bookTitle = _bookTitleController.text.trim();
    final chapter = _chapterController.text.trim();
    final dueDate = _dueDateController.text.trim();

    if (title.isEmpty || bookTitle.isEmpty || chapter.isEmpty || dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请把所有字段填写完整")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final uri = Uri.parse('http://localhost:8080/teacher/assignments');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "title": title,
        "bookTitle": bookTitle,
        "chapter": chapter,
        "dueDate": dueDate,
      }),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("创建失败：HTTP ${response.statusCode}")),
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
        title: const Text("老师端：创建作业"),
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
                onPressed: _isSubmitting ? null : _createAssignment,
                child: Text(_isSubmitting ? "提交中..." : "创建作业"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class TeacherAssignmentManagePage extends StatelessWidget {
  final Assignment assignment;

  const TeacherAssignmentManagePage({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("管理作业：${assignment.title}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: const Text("查看提交列表"),
              subtitle: const Text("查看学生提交和成绩"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherSubmissionsPage(
                      assignmentId: assignment.id,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              title: const Text("添加题目"),
              subtitle: const Text("给这个作业新增选择题或简答题"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherCreateQuestionPage(
                      assignmentId: assignment.id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
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
        "correctAnswer": correctAnswer,
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
                labelText: "正确答案（MCQ填 A/B/C/D，简答填参考答案）",
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
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  late Future<List<dynamic>> _futureSubmissions;

  // 先写死，后面做登录/绑定关系时再改
  final String studentName = "test-student";

  @override
  void initState() {
    super.initState();
    _futureSubmissions = _fetchSubmissions();
  }

  Future<List<dynamic>> _fetchSubmissions() async {
    final uri = Uri.parse(
      'http://localhost:8080/parent/students/$studentName/submissions',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载家长端记录失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("家长端：孩子提交记录"),
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

              return ListTile(
                title: Text("作业ID: ${s['assignmentId']}"),
                subtitle: Text("得分: ${s['totalScore']} / ${s['maxScore']}"),
                trailing: Text("${s['submittedAt']}"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentSubmissionDetailPage(
                        submissionId: (s['id'] as num).toInt(),
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
class ParentSubmissionDetailPage extends StatefulWidget {
  final int submissionId;

  const ParentSubmissionDetailPage({super.key, required this.submissionId});

  @override
  State<ParentSubmissionDetailPage> createState() =>
      _ParentSubmissionDetailPageState();
}

class _ParentSubmissionDetailPageState
    extends State<ParentSubmissionDetailPage> {
  late Future<List<dynamic>> _futureAnswers;

  @override
  void initState() {
    super.initState();
    _futureAnswers = _fetchAnswers();
  }

  Future<List<dynamic>> _fetchAnswers() async {
    final uri = Uri.parse(
      'http://localhost:8080/parent/submissions/${widget.submissionId}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载详情失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("家长端：提交详情"),
      ),
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
                      Text("孩子答案: ${a['studentAnswer']}"),
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
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("选择角色"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "欢迎使用阅读作业系统",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.school),
                label: const Text("学生"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssignmentListPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text("老师"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherAssignmentPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.family_restroom),
                label: const Text("家长"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentHomePage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
