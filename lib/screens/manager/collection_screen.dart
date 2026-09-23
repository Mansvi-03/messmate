import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() =>
      _CollectionScreenState();
}

class _CollectionScreenState
    extends State<CollectionScreen> {
  final FirestoreService _firestoreService =
  FirestoreService();

  bool _loading = true;

  int _totalStudents = 0;
  int _paidStudents = 0;
  int _unpaidStudents = 0;

  double _totalCollection = 0;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    try {
      final students =
      await _firestoreService.getAll('students');

      final bills =
      await _firestoreService.getAll('bills');

      int paid = 0;
      int unpaid = 0;
      double collection = 0;

      for (final bill in bills) {
        final status =
            bill['status']?.toString() ?? 'Unpaid';

        final amount =
            double.tryParse(
              bill['amount'].toString(),
            ) ??
                0;

        if (status == 'Paid') {
          paid++;
          collection += amount;
        } else {
          unpaid++;
        }
      }

      if (!mounted) return;

      setState(() {
        _totalStudents = students.length;
        _paidStudents = paid;
        _unpaidStudents = unpaid;
        _totalCollection = collection;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load collection: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadCollection,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Collection Summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            _summaryItem(
              'Total Students',
              _totalStudents.toString(),
            ),

            _summaryItem(
              'Paid Bills',
              _paidStudents.toString(),
            ),

            _summaryItem(
              'Unpaid Bills',
              _unpaidStudents.toString(),
            ),

            _summaryItem(
              'Total Collection',
              '₹${_totalCollection.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
      String title,
      String value,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}