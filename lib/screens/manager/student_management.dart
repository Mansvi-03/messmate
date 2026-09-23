import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class StudentManagement extends StatefulWidget {
  const StudentManagement({super.key});

  @override
  State<StudentManagement> createState() => _StudentManagementState();
}

class _StudentManagementState extends State<StudentManagement> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students =
      await _firestoreService.getAll('students');

      if (!mounted) return;

      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load students: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _students.isEmpty
          ? const Center(
        child: Text('No students registered'),
      )
          : RefreshIndicator(
        onRefresh: _loadStudents,
        child: ListView.builder(
          itemCount: _students.length,
          itemBuilder: (context, index) {
            final student = _students[index];

            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(
                student['name'] ?? 'Unknown Student',
              ),
              subtitle: Text(
                student['email'] ?? '',
              ),
            );
          },
        ),
      ),
    );
  }
}