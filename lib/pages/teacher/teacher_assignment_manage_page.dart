import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/assignment.dart';
import 'teacher_create_question_page.dart';
import 'teacher_edit_assignment_page.dart';
import 'teacher_question_manage_page.dart';
import 'teacher_submission_status_page.dart';

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