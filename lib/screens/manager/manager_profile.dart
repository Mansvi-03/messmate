import 'package:flutter/material.dart';

class ManagerProfile extends StatelessWidget {
  const ManagerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Profile'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text('Name: Manager Name'),
            SizedBox(height: 10),
            Text('Email: manager@example.com'),
            SizedBox(height: 10),
            Text('Contact: 9876543210'),
            SizedBox(height: 10),
            Text('Mess Name: My Mess'),
            SizedBox(height: 10),
            Text('Address: Mess Address'),
          ],
        ),
      ),
    );
  }
}