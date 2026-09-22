import 'package:flutter/material.dart';

class BillManagement extends StatelessWidget {
  const BillManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Management'),
      ),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Student 1'),
            subtitle: Text('Bill: ₹3000'),
            trailing: Text('Unpaid'),
          ),
          ListTile(
            title: Text('Student 2'),
            subtitle: Text('Bill: ₹3000'),
            trailing: Text('Paid'),
          ),
          ListTile(
            title: Text('Student 3'),
            subtitle: Text('Bill: ₹3000'),
            trailing: Text('Unpaid'),
          ),
        ],
      ),
    );
  }
}