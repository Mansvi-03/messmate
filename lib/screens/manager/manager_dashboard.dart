import 'package:flutter/material.dart';
import 'manager_profile.dart';
import 'menu_management.dart';
import 'attendance_management.dart';
import 'student_management.dart';
import 'bill_management.dart';
import 'collection_screen.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _item(
            context,
            'Profile',
            Icons.person,
            const ManagerProfile(),
          ),
          _item(
            context,
            'Menu',
            Icons.restaurant_menu,
            const MenuManagement(),
          ),
          _item(
            context,
            'Attendance',
            Icons.check_circle,
            const AttendanceManagement(),
          ),
          _item(
            context,
            'Students',
            Icons.people,
            const StudentManagement(),
          ),
          _item(
            context,
            'Bills',
            Icons.receipt,
            const BillManagement(),
          ),
          _item(
            context,
            'Collection',
            Icons.currency_rupee,
            const CollectionScreen(),
          ),
        ],
      ),
    );
  }

  Widget _item(
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