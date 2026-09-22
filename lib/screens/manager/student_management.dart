import 'package:flutter/material.dart';

class StudentManagement extends StatelessWidget {
  const StudentManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Student 1'),
            subtitle: Text('student1@example.com'),
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Student 2'),
            subtitle: Text('student2@example.com'),
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Student 3'),
            subtitle: Text('student3@example.com'),
          ),
        ],
      ),
    );
  }
}