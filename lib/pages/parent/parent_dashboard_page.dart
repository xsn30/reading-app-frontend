import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/logout.dart';
import 'parent_home_page.dart';
import 'parent_learning_summary_page.dart';
import 'parent_link_student_page.dart';
import 'parent_profile_page.dart';

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
        child: SingleChildScrollView(
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

              /// 没有孩子
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
              ]

              /// 有孩子
              else ...[
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
              ],

              const SizedBox(height: 24),

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

              const SizedBox(height: 16),

              ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text("我的资料"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentProfilePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}