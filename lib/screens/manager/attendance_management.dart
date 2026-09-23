import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class AttendanceManagement extends StatefulWidget {
  const AttendanceManagement({super.key});

  @override
  State<AttendanceManagement> createState() =>
      _AttendanceManagementState();
}

class _AttendanceManagementState
    extends State<AttendanceManagement> {
  final FirestoreService _firestoreService =
  FirestoreService();

  bool _loading = true;

  List<Map<String, dynamic>> _students = [];

  final Map<String, bool> _attendance = {};

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

        for (final student in students) {
          final id = student['id']?.toString();

          if (id != null) {
            _attendance[id] = false;
          }
        }

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

  Future<void> _saveAttendance() async {
    try {
      final today = DateTime.now();

      final date =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      for (final student in _students) {
        final studentId = student['id']?.toString();

        if (studentId == null) {
          continue;
        }

        await _firestoreService.add(
          'attendance',
          '${studentId}_$date',
          {
            'studentId': studentId,
            'date': date,
            'present': _attendance[studentId] ?? false,
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attendance saved successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save attendance: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _students.isEmpty
          ? const Center(
        child: Text('No students registered'),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student =
                _students[index];

                final id =
                    student['id']?.toString() ?? '';

                final name =
                    student['name']?.toString() ??
                        'Unknown Student';

                return SwitchListTile(
                  title: Text(name),
                  subtitle: Text(
                    student['email']?.toString() ??
                        '',
                  ),
                  value: _attendance[id] ?? false,
                  onChanged: (value) {
                    setState(() {
                      _attendance[id] = value;
                    });
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveAttendance,
                child: const Text(
                  'Save Attendance',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}