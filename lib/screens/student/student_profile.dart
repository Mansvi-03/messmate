import 'package:flutter/material.dart';

class StudentProfile extends StatelessWidget {
  const StudentProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text('Name: Student Name'),
            SizedBox(height: 10),
            Text('Email: student@example.com'),
            SizedBox(height: 10),
            Text('Contact: 9876543210'),
            SizedBox(height: 10),
            Text('College: College Name'),
            SizedBox(height: 10),
            Text('Hostel: Hostel Name'),
          ],
        ),
      ),
    );
  }
}