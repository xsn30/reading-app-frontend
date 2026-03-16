import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../utils/logout.dart';
import 'parent_submission_detail_page.dart';

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