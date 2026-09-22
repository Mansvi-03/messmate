import 'package:flutter/material.dart';

class AttendanceManagement extends StatelessWidget {
  const AttendanceManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
      ),
      body: ListView(
        children: [
          _student('Student 1'),
          _student('Student 2'),
          _student('Student 3'),
        ],
      ),
    );
  }

  Widget _student(String name) {
    return ListTile(
      title: Text(name),
      trailing: Switch(
        value: true,
        onChanged: (value) {},
      ),
    );
  }
}