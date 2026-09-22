import 'package:flutter/material.dart';
import 'student_profile.dart';
import 'menu_screen.dart';
import 'attendance_screen.dart';
import 'bill_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _dashboardItem(
            context,
            'Profile',
            Icons.person,
            const StudentProfile(),
          ),
          _dashboardItem(
            context,
            'Menu',
            Icons.restaurant_menu,
            const MenuScreen(),
          ),
          _dashboardItem(
            context,
            'Attendance',
            Icons.check_circle,
            const AttendanceScreen(),
          ),
          _dashboardItem(
            context,
            'Bill',
            Icons.receipt,
            const BillScreen(),
          ),
        ],
      ),
    );
  }

  Widget _dashboardItem(
      BuildContext context,
      String title,
      IconData icon,
      Widget screen,
      ) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
  }
}