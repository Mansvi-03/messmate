import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('01 September 2026'),
            trailing: Text('Present'),
          ),
          ListTile(
            title: Text('02 September 2026'),
            trailing: Text('Present'),
          ),
          ListTile(
            title: Text('03 September 2026'),
            trailing: Text('Absent'),
          ),
        ],
      ),
    );
  }
}