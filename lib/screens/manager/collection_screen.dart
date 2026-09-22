import 'package:flutter/material.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collection Summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text('Total Students: 50'),
            SizedBox(height: 10),
            Text('Paid Students: 40'),
            SizedBox(height: 10),
            Text('Unpaid Students: 10'),
            SizedBox(height: 10),
            Text('Total Collection: ₹1,20,000'),
          ],
        ),
      ),
    );
  }
}