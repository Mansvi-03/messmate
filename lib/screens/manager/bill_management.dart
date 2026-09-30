import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class BillManagement extends StatefulWidget {
  const BillManagement({super.key});

  @override
  State<BillManagement> createState() => _BillManagementState();
}

class _BillManagementState extends State<BillManagement> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _bills = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      // Automatically create unpaid bills for present attendance records if missing
      final Map<String, Map<String, dynamic>> existingBillsMap = {};
      for (final bill in bills) {
        final id = bill['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          existingBillsMap[id] = bill;
        }
      }

      final List<Map<String, dynamic>> updatedBillsList = List.from(bills);

      for (final att in attendanceList) {
        if (att['present'] == true) {
          final studentId = att['studentId']?.toString() ?? '';
          final recordId = att['id']?.toString() ?? '';

          if (studentId.isNotEmpty && recordId.isNotEmpty) {
            if (!existingBillsMap.containsKey(recordId)) {
              double price = _extractNum(att['price']);
              if (price <= 0) {
                price = _extractNum(att['amount']);
              }
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
              if (price <= 0) {
                price = 60.0;
              }

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

              await _firestoreService.add('bills', recordId, newBillData);
              updatedBillsList.add(newBillData);
              existingBillsMap[recordId] = newBillData;
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _students = students;
        _bills = updatedBillsList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load bills: $e'),
        ),
      );
    }
  }

  static double _extractNum(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) {
      return double.tryParse(val.toString().trim()) ?? 0;
    }
    return 0;
  }

  String _studentName(String studentId) {
    for (final student in _students) {
      if (student['id'] == studentId) {
        return student['name'] ?? 'Unknown Student';
      }
    }
    return 'Unknown Student';
  }

  Future<void> _updateStatus(String billId, String newStatus) async {
    try {
      final String normalizedStatus = newStatus.toLowerCase();

      await _firestoreService.update('bills', billId, {
        'status': normalizedStatus,
      });

      if (!mounted) return;

      setState(() {
        for (final bill in _bills) {
          if (bill['id'] == billId) {
            bill['status'] = normalizedStatus;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${normalizedStatus.toUpperCase()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Management'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _bills.isEmpty
              ? const Center(
                  child: Text('No bills created'),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _bills.length,
                    itemBuilder: (context, index) {
                      final bill = _bills[index];
                      final billId = bill['id']?.toString() ?? '';
                      final studentId = bill['studentId']?.toString() ?? '';
                      final amountVal = _extractNum(bill['amount']);
                      final displayAmount = amountVal > 0
                          ? amountVal.toStringAsFixed(0)
                          : _extractNum(bill['price']).toStringAsFixed(0);

                      final rawStatus = (bill['status']?.toString() ?? 'unpaid').toLowerCase();
                      final currentStatus = (rawStatus == 'paid') ? 'paid' : 'unpaid';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(
                            _studentName(studentId),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Bill: ₹$displayAmount',
                            style: const TextStyle(fontSize: 15),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: currentStatus == 'paid' ? Colors.green : Colors.red,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentStatus,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: currentStatus == 'paid' ? Colors.green : Colors.red,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: currentStatus == 'paid' ? Colors.green : Colors.red,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'unpaid',
                                    child: Text(
                                      'unpaid',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'paid',
                                    child: Text(
                                      'paid',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null && val != currentStatus && billId.isNotEmpty) {
                                    _updateStatus(billId, val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}