import 'package:flutter/material.dart';

class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bill'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Bill',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text('Month: September 2026'),
            SizedBox(height: 10),
            Text('Total Amount: ₹3000'),
            SizedBox(height: 10),
            Text('Status: Unpaid'),
          ],
        ),
      ),
    );
  }
}