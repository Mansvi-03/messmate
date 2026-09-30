import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();

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

  static double _extractNum(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) {
      return double.tryParse(val.toString().trim()) ?? 0;
    }
    return 0;
  }

  Future<void> _loadCollection() async {
    try {
      final students = await _firestoreService.getAll('students');
      final bills = await _firestoreService.getAll('bills');
      final attendanceList = await _firestoreService.getAll('attendance');
      final menus = await _firestoreService.getAll('menus');

      final Map<String, Map<String, dynamic>> menuByDay = {};
      for (final menu in menus) {
        final day = menu['day']?.toString();
        if (day != null && day.isNotEmpty) {
          menuByDay[day] = menu;
        }
      }

      final Map<String, Map<String, dynamic>> existingBillsMap = {};
      for (final bill in bills) {
        final id = bill['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          existingBillsMap[id] = bill;
        }
      }

      final List<Map<String, dynamic>> allBills = List.from(bills);

      for (final att in attendanceList) {
        if (att['present'] == true) {
          final studentId = att['studentId']?.toString() ?? '';
          final recordId = att['id']?.toString() ?? '';

          if (studentId.isNotEmpty && recordId.isNotEmpty) {
            if (!existingBillsMap.containsKey(recordId)) {
              double price = _extractNum(att['price']);
              if (price <= 0) price = _extractNum(att['amount']);
              if (price <= 0) {
                final mealKey = (att['meal']?.toString() ?? 'lunch').toLowerCase();
                String dayName = att['day']?.toString() ?? '';
                if (dayName.isEmpty && att['date'] != null) {
                  try {
                    final dt = DateTime.parse(att['date'].toString());
                    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                    dayName = days[dt.weekday - 1];
                  } catch (_) {}
                }
                if (menuByDay.containsKey(dayName)) {
                  final dayMenu = menuByDay[dayName]!;
                  final mealData = dayMenu[mealKey];
                  if (mealData is Map) {
                    price = _extractNum(mealData['price']);
                  }
                }
              }
              if (price <= 0) price = 60.0;

              final newBillData = {
                'id': recordId,
                'studentId': studentId,
                'date': att['date'] ?? '',
                'meal': att['meal'] ?? '',
                'amount': price,
                'price': price,
                'status': 'unpaid',
                'createdAt': DateTime.now().toIso8601String(),
              };

              allBills.add(newBillData);
              existingBillsMap[recordId] = newBillData;
            }
          }
        }
      }

      int paid = 0;
      int unpaid = 0;
      double collection = 0;

      for (final bill in allBills) {
        final status = (bill['status']?.toString() ?? 'unpaid').toLowerCase();

        double amount = _extractNum(bill['amount']);
        if (amount <= 0) {
          amount = _extractNum(bill['price']);
        }

        if (status == 'paid') {
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
                    Icons.people,
                  ),

                  _summaryItem(
                    'Paid Bills',
                    _paidStudents.toString(),
                    Icons.check_circle,
                    valueColor: Colors.green,
                  ),

                  _summaryItem(
                    'Unpaid Bills',
                    _unpaidStudents.toString(),
                    Icons.pending_actions,
                    valueColor: Colors.red,
                  ),

                  _summaryItem(
                    'Total Collection',
                    '₹${_totalCollection.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    valueColor: Colors.green.shade800,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryItem(
    String title,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ),
    );
  }
}