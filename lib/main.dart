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
  final int classroomId;

  Assignment({
    required this.id,
    required this.title,
    required this.bookTitle,
    required this.chapter,
    required this.dueDate,
    required this.classroomId,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      bookTitle: (json['bookTitle'] ?? '') as String,
      chapter: (json['chapter'] ?? '') as String,
      dueDate: (json['dueDate'] ?? '') as String,
      classroomId: (json['classroomId'] as num?)?.toInt() ?? 0,
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
  final String correctAnswer;

  Question({
    required this.id,
    required this.assignmentId,
    required this.type,
    required this.text,
    required this.options,
    required this.score,
    required this.difficulty,
    required this.correctAnswer,
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
      correctAnswer: (json['correctAnswer'] ?? '') as String,
    );
  }
}
class LoginResponseModel {
  final int id;
  final String username;
  final String role;
  final String linkedStudentUsername;

  LoginResponseModel({
    required this.id,
    required this.username,
    required this.role,
    required this.linkedStudentUsername,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      id: (json['id'] as num).toInt(),
      username: (json['username'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      linkedStudentUsername: (json['linkedStudentUsername'] ?? '') as String,
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
      home: const AuthGate(),
    );
  }
}
Future<void> logout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove("userId");
  await prefs.remove("username");
  await prefs.remove("role");
  await prefs.remove("linkedStudentUsername");


  if (!context.mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
  );
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
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/student/assignments?studentUsername=$username',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('加载失败：HTTP ${response.statusCode}');
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    return body
        .map((item) => Assignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 判断作业是否已截止
  bool _isExpired(String dueDate) {
    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();

      final dueOnly = DateTime(due.year, due.month, due.day);
      final nowOnly = DateTime(now.year, now.month, now.day);

      return nowOnly.isAfter(dueOnly);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('作业列表'),
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
      body: FutureBuilder<List<Assignment>>(
        future: _futureAssignments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('出错了：${snapshot.error}'),
            );
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return const Center(child: Text('暂时没有作业'));
          }

          /// ⭐ 分组
          final activeAssignments =
          assignments.where((a) => !_isExpired(a.dueDate)).toList();

          final expiredAssignments =
          assignments.where((a) => _isExpired(a.dueDate)).toList();

          return ListView(
            children: [
              /// 未截止作业
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "未截止作业",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (activeAssignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("暂无未截止作业"),
                )
              else
                ...activeAssignments.map((a) {
                  return Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text('截止日期：${a.dueDate}'),
                      trailing: const Icon(Icons.chevron_right),
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
                    ),
                  );
                }),

              /// 已截止作业
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  "已截止作业",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (expiredAssignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("暂无已截止作业"),
                )
              else
                ...expiredAssignments.map((a) {
                  return Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text(
                        '截止日期：${a.dueDate}\n状态：已截止',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.lock_clock),
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

// 先从本地拿当前登录学生用户名
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

// ⭐ 先判断后端有没有返回 error
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

    final List<dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

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
  List<dynamic> _classrooms = [];
  int? _selectedClassroomId;
  @override
  void initState() {
    super.initState();
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

    setState(() {
      _classrooms = body;

      if (_classrooms.isNotEmpty) {
        _selectedClassroomId = (_classrooms.first['id'] as num).toInt();
      }
    });
  }

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

    if (_selectedClassroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请先选择班级")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

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
        "classroomId": _selectedClassroomId,
        "teacherUsername": teacherUsername,
      }),
    );

    setState(() {
      _isSubmitting = false;
    });

    final dynamic body = json.decode(utf8.decode(response.bodyBytes));

    if (body is Map<String, dynamic> && body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

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

            const SizedBox(height: 12),

            // ⭐ 班级选择框
            if (_classrooms.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text("当前没有班级，请先创建班级"),
              )
            else
              DropdownButtonFormField<int>(
                value: _selectedClassroomId,
                decoration: const InputDecoration(
                  labelText: "选择班级",
                  border: OutlineInputBorder(),
                ),
                items: _classrooms.map((c) {
                  return DropdownMenuItem<int>(
                    value: (c['id'] as num).toInt(),
                    child: Text("${c['name']}（班级ID: ${c['id']}）"),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassroomId = value;
                  });
                },
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

  Future<void> _deleteAssignment(BuildContext context) async {
    final uri = Uri.parse(
      'http://localhost:8080/assignments/${assignment.id}',
    );

    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("删除失败：HTTP ${response.statusCode}")),
      );
      return;
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("作业已删除")),
    );

    Navigator.pop(context, true);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("确认删除"),
        content: Text("确定要删除作业《${assignment.title}》吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteAssignment(context);
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
        title: Text("管理作业：${assignment.title}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: const Text("查看学生提交状态"),
              subtitle: const Text("查看本班学生已交 / 未交情况"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherSubmissionStatusPage(
                      assignmentId: assignment.id,
                      assignmentTitle: assignment.title,
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
            const Divider(),
            ListTile(
              title: const Text("编辑作业信息"),
              subtitle: const Text("修改标题、书名、章节和截止日期"),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherEditAssignmentPage(
                      assignment: assignment,
                    ),
                  ),
                );

                if (changed == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            const Divider(),
            ListTile(
              title: const Text("管理题目"),
              subtitle: const Text("查看、编辑或删除这份作业下的题目"),
              trailing: const Icon(Icons.list_alt),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherQuestionManagePage(
                      assignmentId: assignment.id,
                      assignmentTitle: assignment.title,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              title: const Text("删除作业"),
              subtitle: const Text("删除这个作业及其题目"),
              trailing: const Icon(Icons.delete_outline),
              onTap: () {
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
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


class TeacherEditQuestionPage extends StatefulWidget {
  final Question question;

  const TeacherEditQuestionPage({super.key, required this.question});

  @override
  State<TeacherEditQuestionPage> createState() =>
      _TeacherEditQuestionPageState();
}

class _TeacherEditQuestionPageState extends State<TeacherEditQuestionPage> {
  late TextEditingController _textController;
  late TextEditingController _correctAnswerController;
  late TextEditingController _scoreController;
  late TextEditingController _difficultyController;

  late TextEditingController _optionAController;
  late TextEditingController _optionBController;
  late TextEditingController _optionCController;
  late TextEditingController _optionDController;

  late String _type;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.question.type;
    _textController = TextEditingController(text: widget.question.text);
    _correctAnswerController =
        TextEditingController(text: widget.question.correctAnswer);
    _scoreController = TextEditingController(text: widget.question.score.toString());
    _difficultyController =
        TextEditingController(text: widget.question.difficulty);

    final options = widget.question.options;
    _optionAController =
        TextEditingController(text: options.length > 0 ? options[0] : "");
    _optionBController =
        TextEditingController(text: options.length > 1 ? options[1] : "");
    _optionCController =
        TextEditingController(text: options.length > 2 ? options[2] : "");
    _optionDController =
        TextEditingController(text: options.length > 3 ? options[3] : "");
  }

  Future<void> _saveQuestion() async {
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
          const SnackBar(content: Text("选择题四个选项都要填写")),
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
      'http://localhost:8080/questions/${widget.question.id}',
    );

    final response = await http.put(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "id": widget.question.id,
        "assignmentId": widget.question.assignmentId,
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
        SnackBar(content: Text("保存失败：HTTP ${response.statusCode}")),
      );
      return;
    }

    if (!mounted) return;
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
        title: const Text("编辑题目"),
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
                labelText: "正确答案（选择题填 A/B/C/D，不要填选项内容；简答题填参考答案）",
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
                labelText: "难度",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveQuestion,
                child: Text(_isSubmitting ? "保存中..." : "保存修改"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class TeacherEditAssignmentPage extends StatefulWidget {
  final Assignment assignment;

  const TeacherEditAssignmentPage({super.key, required this.assignment});

  @override
  State<TeacherEditAssignmentPage> createState() =>
      _TeacherEditAssignmentPageState();
}

class _TeacherEditAssignmentPageState extends State<TeacherEditAssignmentPage> {
  late TextEditingController _titleController;
  late TextEditingController _bookTitleController;
  late TextEditingController _chapterController;
  late TextEditingController _dueDateController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.assignment.title);
    _bookTitleController =
        TextEditingController(text: widget.assignment.bookTitle);
    _chapterController = TextEditingController(text: widget.assignment.chapter);
    _dueDateController = TextEditingController(text: widget.assignment.dueDate);
  }

  Future<void> _saveAssignment() async {
    final title = _titleController.text.trim();
    final bookTitle = _bookTitleController.text.trim();
    final chapter = _chapterController.text.trim();
    final dueDate = _dueDateController.text.trim();

    if (title.isEmpty ||
        bookTitle.isEmpty ||
        chapter.isEmpty ||
        dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请把所有字段填写完整")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final uri = Uri.parse(
      'http://localhost:8080/assignments/${widget.assignment.id}',
    );

    final response = await http.put(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "id": widget.assignment.id,
        "title": title,
        "bookTitle": bookTitle,
        "chapter": chapter,
        "dueDate": dueDate,
        "classroomId": widget.assignment.classroomId,
      }),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("保存失败：HTTP ${response.statusCode}")),
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
        title: const Text("编辑作业信息"),
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
                onPressed: _isSubmitting ? null : _saveAssignment,
                child: Text(_isSubmitting ? "保存中..." : "保存修改"),
              ),
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
class ParentHomePage extends StatefulWidget {
  final String studentUsername;

  const ParentHomePage({
    super.key,
    required this.studentUsername,
  });

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  late Future<List<dynamic>> _futureSubmissions;

  @override
  void initState() {
    super.initState();
    _futureSubmissions = _fetchSubmissions();
  }

  Future<List<dynamic>> _fetchSubmissions() async {
    final uri = Uri.parse(
      'http://localhost:8080/parent/students/${widget.studentUsername}/submissions',
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
        title: Text("孩子提交记录：${widget.studentUsername}"),
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
                      builder: (_) => const ParentDashboardPage(),
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
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入用户名和密码")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse('http://localhost:8080/auth/login');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "password": password,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    final loginUser = LoginResponseModel.fromJson(body);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("userId", loginUser.id);
    await prefs.setString("username", loginUser.username);
    await prefs.setString("role", loginUser.role);
    await prefs.setString(
      "linkedStudentUsername",
      loginUser.linkedStudentUsername,
    );

    if (!mounted) return;

    if (loginUser.role == "student") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomePage()),
      );
    } else if (loginUser.role == "teacher") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherHomePage()),
      );
    } else if (loginUser.role == "parent") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ParentDashboardPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("未知角色")),
      );
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("登录"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "用户名",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "密码",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: Text(_isLoading ? "登录中..." : "登录"),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goToRegister,
              child: const Text("没有账号？去注册"),
            ),
          ],
        ),
      ),
    );
  }
}
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = "student";
  bool _isLoading = false;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入用户名和密码")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse('http://localhost:8080/auth/register');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "username": username,
        "password": password,
        "role": _role,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("注册成功，请登录")),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("注册"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "用户名",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "密码",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: "角色",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "student", child: Text("学生")),
                DropdownMenuItem(value: "teacher", child: Text("老师")),
                DropdownMenuItem(value: "parent", child: Text("家长")),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _role = value;
                });
              },
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: Text(_isLoading ? "注册中..." : "注册"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _futurePage;

  @override
  void initState() {
    super.initState();
    _futurePage = _checkLogin();
  }

  Future<Widget> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getInt("userId");
    final role = prefs.getString("role");

    if (userId == null || role == null) {
      return const LoginPage();
    }

    if (role == "student") {
      return const StudentHomePage();
    } else if (role == "teacher") {
      return const TeacherHomePage();
    } else if (role == "parent") {
      return const ParentDashboardPage();
    } else {
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _futurePage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text("启动失败"),
            ),
          );
        }

        return snapshot.data ?? const LoginPage();
      },
    );
  }
}
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  String username = "";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("username") ?? "";

    setState(() {
      username = savedName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("学生首页"),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              username.isEmpty ? "欢迎你" : "欢迎你，$username",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text("查看作业"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AssignmentListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text("我的提交记录"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentSubmissionListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.group_add),
              label: const Text("加入班级"),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentJoinClassPage(),
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
class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  String username = "";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("username") ?? "";

    setState(() {
      username = savedName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("老师首页"),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              username.isEmpty ? "欢迎你" : "欢迎你，$username",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: const Icon(Icons.assignment),
              label: const Text("管理作业"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherAssignmentPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),


            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("创建班级"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherCreateClassPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.class_),
              label: const Text("我的班级"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherClassListPage(),
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
class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  String username = "";
  List<dynamic> _children = [];
  String? _selectedStudentUsername;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadChildren();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("username") ?? "";

    setState(() {
      username = savedName;
    });
  }

  Future<void> _loadChildren() async {
    final prefs = await SharedPreferences.getInstance();
    final parentUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse(
      'http://localhost:8080/parent/$parentUsername/children',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return;
    }

    final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

    setState(() {
      _children = body;
      if (_children.isNotEmpty && _selectedStudentUsername == null) {
        _selectedStudentUsername = _children.first['username'] as String;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("家长首页"),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              username.isEmpty ? "欢迎你" : "欢迎你，$username",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            if (_children.isEmpty) ...[
              const Text("当前还没有绑定孩子"),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text("绑定孩子"),
                onPressed: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentLinkStudentPage(),
                    ),
                  );

                  if (changed == true) {
                    _loadChildren();
                  }
                },
              ),
              const SizedBox(height: 24),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _selectedStudentUsername,
                decoration: const InputDecoration(
                  labelText: "选择孩子",
                  border: OutlineInputBorder(),
                ),
                items: _children.map((child) {
                  return DropdownMenuItem<String>(
                    value: child['username'] as String,
                    child: Text(child['username'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStudentUsername = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text("绑定新的孩子"),
                onPressed: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentLinkStudentPage(),
                    ),
                  );

                  if (changed == true) {
                    _loadChildren();
                  }
                },
              ),
              const SizedBox(height: 24),
            ],

            ElevatedButton.icon(
              icon: const Icon(Icons.child_care),
              label: const Text("查看孩子提交记录"),
              onPressed: _selectedStudentUsername == null
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentHomePage(
                      studentUsername: _selectedStudentUsername!,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.insights),
              label: const Text("查看学习情况"),
              onPressed: _selectedStudentUsername == null
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentLearningSummaryPage(
                      studentUsername: _selectedStudentUsername!,
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
class StudentJoinClassPage extends StatefulWidget {
  const StudentJoinClassPage({super.key});

  @override
  State<StudentJoinClassPage> createState() => _StudentJoinClassPageState();
}

class _StudentJoinClassPageState extends State<StudentJoinClassPage> {
  final _classroomIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinClassroom() async {
    final classroomIdText = _classroomIdController.text.trim();

    if (classroomIdText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入班级ID")),
      );
      return;
    }

    final classroomId = int.tryParse(classroomIdText);
    if (classroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("班级ID必须是数字")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString("username") ?? "";

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("当前未获取到学生用户名，请重新登录")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(
      'http://localhost:8080/classrooms/$classroomId/join',
    );

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "studentUsername": username,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final Map<String, dynamic> body =
    json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("加入班级成功")),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _classroomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("加入班级"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _classroomIdController,
              decoration: const InputDecoration(
                labelText: "请输入班级ID",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinClassroom,
                child: Text(_isLoading ? "加入中..." : "加入班级"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class TeacherCreateClassPage extends StatefulWidget {
  const TeacherCreateClassPage({super.key});

  @override
  State<TeacherCreateClassPage> createState() => _TeacherCreateClassPageState();
}

class _TeacherCreateClassPageState extends State<TeacherCreateClassPage> {
  final _classNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createClassroom() async {
    final name = _classNameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入班级名称")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final teacherUsername = prefs.getString("username") ?? "";

    final uri = Uri.parse("http://localhost:8080/classrooms");

    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "name": name,
        "teacherUsername": teacherUsername,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("班级创建成功")),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("创建班级"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: "班级名称",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createClassroom,
                child: Text(_isLoading ? "创建中..." : "创建班级"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
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
class StudentSubmissionDetailPage extends StatefulWidget {
  final int submissionId;

  const StudentSubmissionDetailPage({super.key, required this.submissionId});

  @override
  State<StudentSubmissionDetailPage> createState() =>
      _StudentSubmissionDetailPageState();
}

class _StudentSubmissionDetailPageState
    extends State<StudentSubmissionDetailPage> {
  late Future<List<dynamic>> _futureAnswers;

  @override
  void initState() {
    super.initState();
    _futureAnswers = _fetchAnswers();
  }

  Future<List<dynamic>> _fetchAnswers() async {
    final uri = Uri.parse(
      'http://localhost:8080/student/submissions/${widget.submissionId}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载提交详情失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("提交详情"),
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
                      Text("我的答案: ${a['studentAnswer']}"),
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
      'http://localhost:8080/teacher/assignments/${widget
          .assignmentId}/submission-status'
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
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                          builder: (_) =>
                              TeacherSubmissionDetailPage(
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
class ParentLearningSummaryPage extends StatefulWidget {
  final String studentUsername;

  const ParentLearningSummaryPage({
    super.key,
    required this.studentUsername,
  });

  @override
  State<ParentLearningSummaryPage> createState() =>
      _ParentLearningSummaryPageState();
}

class _ParentLearningSummaryPageState extends State<ParentLearningSummaryPage> {
  late Future<Map<String, dynamic>> _futureSummary;

  @override
  void initState() {
    super.initState();
    _futureSummary = _fetchSummary();
  }

  Future<Map<String, dynamic>> _fetchSummary() async {
    final uri = Uri.parse(
      'http://localhost:8080/parent/students/${widget.studentUsername}/summary',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("加载学习情况失败：HTTP ${response.statusCode}");
    }

    return json.decode(utf8.decode(response.bodyBytes))
    as Map<String, dynamic>;
  }

  String _formatAverageScore(dynamic value) {
    if (value == null) return "0.00";
    if (value is int) return value.toStringAsFixed(2);
    if (value is double) return value.toStringAsFixed(2);
    return double.tryParse(value.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("学习情况：${widget.studentUsername}"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureSummary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("错误: ${snapshot.error}"));
          }

          final summary = snapshot.data ?? {};

          final totalSubmissions = summary["totalSubmissions"] ?? 0;
          final averageScore = _formatAverageScore(summary["averageScore"]);
          final latestScore = summary["latestScore"];
          final latestMaxScore = summary["latestMaxScore"];
          final latestSubmittedAt = summary["latestSubmittedAt"];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "学习概览",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text("已完成作业数：$totalSubmissions"),
                      const SizedBox(height: 8),
                      Text("平均分：$averageScore"),
                      const SizedBox(height: 8),
                      Text(
                        latestScore == null || latestMaxScore == null
                            ? "最近一次得分：暂无"
                            : "最近一次得分：$latestScore / $latestMaxScore",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        latestSubmittedAt == null
                            ? "最近提交时间：暂无"
                            : "最近提交时间：$latestSubmittedAt",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class ParentLinkStudentPage extends StatefulWidget {
  const ParentLinkStudentPage({super.key});

  @override
  State<ParentLinkStudentPage> createState() => _ParentLinkStudentPageState();
}

class _ParentLinkStudentPageState extends State<ParentLinkStudentPage> {
  final _studentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _linkStudent() async {
    final studentUsername = _studentController.text.trim();

    if (studentUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入孩子用户名")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final parentUsername = prefs.getString("username") ?? "";

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse("http://localhost:8080/parent/link-student");

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "parentUsername": parentUsername,
        "studentUsername": studentUsername,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final body = json.decode(utf8.decode(response.bodyBytes));

    if (body.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"])),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("绑定成功")),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _studentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("绑定孩子"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _studentController,
              decoration: const InputDecoration(
                labelText: "孩子用户名",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _linkStudent,
                child: Text(_isLoading ? "绑定中..." : "绑定"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}