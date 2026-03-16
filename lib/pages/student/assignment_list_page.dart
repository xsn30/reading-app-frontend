import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/assignment.dart';
import '../../utils/logout.dart';
import 'assignment_detail_page.dart';

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

          final activeAssignments =
          assignments.where((a) => !_isExpired(a.dueDate)).toList();

          final expiredAssignments =
          assignments.where((a) => _isExpired(a.dueDate)).toList();

          return ListView(
            children: [
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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