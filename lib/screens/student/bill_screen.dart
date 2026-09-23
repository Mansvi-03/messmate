import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _bills = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'Student is not logged in.';
          _isLoading = false;
        });
        return;
      }

      final data = await _firestoreService.getAll('bills');

      final studentBills = data.where((bill) {
        return bill['studentId'] == user.uid;
      }).toList();

      studentBills.sort((a, b) {
        final dateA = a['createdAt']?.toString() ?? '';
        final dateB = b['createdAt']?.toString() ?? '';

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _bills = studentBills;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load bills.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);

      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  double _getAmount(Map<String, dynamic> bill) {
    final amount = bill['amount'];

    if (amount is num) {
      return amount.toDouble();
    }

    return double.tryParse(amount.toString()) ?? 0;
  }

  double get _totalAmount {
    return _bills.fold(
      0,
          (total, bill) => total + _getAmount(bill),
    );
  }

  double get _paidAmount {
    return _bills
        .where(
          (bill) =>
      bill['status']?.toString().toLowerCase() == 'paid',
    )
        .fold(
      0,
          (total, bill) => total + _getAmount(bill),
    );
  }

  double get _unpaidAmount {
    return _bills
        .where(
          (bill) =>
      bill['status']?.toString().toLowerCase() == 'unpaid',
    )
        .fold(
      0,
          (total, bill) => total + _getAmount(bill),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      );
    }

    if (_bills.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBills,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                'No bills found.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          _summaryCard(
            'Total Amount',
            _totalAmount,
          ),

          _summaryCard(
            'Paid Amount',
            _paidAmount,
          ),

          _summaryCard(
            'Unpaid Amount',
            _unpaidAmount,
          ),

          const SizedBox(height: 20),

          const Text(
            'Bill History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ..._bills.map(
                (bill) => _billCard(bill),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(Map<String, dynamic> bill) {
    final amount = _getAmount(bill);

    final status =
        bill['status']?.toString() ?? 'Unknown';

    final createdAt =
        bill['createdAt']?.toString() ?? '';

    final isPaid =
        status.toLowerCase() == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(
          Icons.receipt_long,
        ),
        title: Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          createdAt.isEmpty
              ? 'Date not available'
              : _formatDate(createdAt),
        ),
        trailing: Text(
          status,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPaid
                ? Colors.green
                : Colors.red,
          ),
        ),
      ),
    );
  }
}