import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class BillManagement extends StatefulWidget {
  const BillManagement({super.key});

  @override
  State<BillManagement> createState() =>
      _BillManagementState();
}

class _BillManagementState
    extends State<BillManagement> {
  final FirestoreService _firestoreService =
  FirestoreService();

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
      final students =
      await _firestoreService.getAll('students');

      final bills =
      await _firestoreService.getAll('bills');

      if (!mounted) return;

      setState(() {
        _students = students;
        _bills = bills;
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

  String _studentName(String studentId) {
    for (final student in _students) {
      if (student['id'] == studentId) {
        return student['name'] ?? 'Unknown Student';
      }
    }

    return 'Unknown Student';
  }

  Future<void> _addBill() async {
    String? selectedStudentId;
    final amountController = TextEditingController();

    String status = 'Unpaid';

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Bill'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Student',
                      border: OutlineInputBorder(),
                    ),
                    items: _students.map((student) {
                      final id =
                      student['id'].toString();

                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          student['name'] ??
                              'Unknown Student',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStudentId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: amountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Paid',
                        child: Text('Paid'),
                      ),
                      DropdownMenuItem(
                        value: 'Unpaid',
                        child: Text('Unpaid'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          status = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedStudentId == null ||
                        amountController.text
                            .trim()
                            .isEmpty) {
                      return;
                    }

                    try {
                      final id = DateTime.now()
                          .millisecondsSinceEpoch
                          .toString();

                      await _firestoreService.add(
                        'bills',
                        id,
                        {
                          'studentId':
                          selectedStudentId,
                          'amount': double.parse(
                            amountController.text.trim(),
                          ),
                          'status': status,
                          'createdAt':
                          DateTime.now()
                              .toIso8601String(),
                        },
                      );

                      if (!mounted) return;

                      Navigator.pop(context);

                      await _loadData();

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Bill added successfully',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to add bill: $e',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Management'),
        actions: [
          IconButton(
            onPressed: _addBill,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _bills.isEmpty
          ? const Center(
        child: Text('No bills created'),
      )
          : ListView.builder(
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];

          final studentId =
              bill['studentId']?.toString() ?? '';

          final amount =
              bill['amount']?.toString() ?? '0';

          final status =
              bill['status']?.toString() ??
                  'Unpaid';

          return ListTile(
            title: Text(
              _studentName(studentId),
            ),
            subtitle: Text(
              'Bill: ₹$amount',
            ),
            trailing: Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: status == 'Paid'
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }
}