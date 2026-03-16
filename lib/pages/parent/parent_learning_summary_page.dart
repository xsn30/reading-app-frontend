import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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