import 'package:flutter/material.dart';

import '../../services/bill_calculator.dart';
import '../../services/firestore_service.dart';

class BillManagement extends StatefulWidget {
  const BillManagement({super.key});

  @override
  State<BillManagement> createState() => _BillManagementState();
}

class _BillManagementState extends State<BillManagement> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  String _selectedPeriod = '';
  List<Map<String, String>> _availablePeriods = [];

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _attendanceList = [];
  List<Map<String, dynamic>> _menus = [];

  List<StudentBillSummary> _allBills = [];
  String _statusFilter = 'all'; // 'all', 'paid', 'unpaid'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedPeriod = BillCalculator.getMonthKey(DateTime.now());
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final students = await _firestoreService.getAll('students');
      final bills = await _firestoreService.getAll('bills');
      final attendance = await _firestoreService.getAll('attendance');
      final menus = await _firestoreService.getAll('menus');

      final periods = BillCalculator.getAvailableBillingPeriods(attendance);

      // Default to current month or first available
      String activePeriod = _selectedPeriod;
      if (activePeriod.isEmpty || !periods.any((p) => p['key'] == activePeriod)) {
        activePeriod = periods.isNotEmpty ? periods.first['key']! : 'all';
      }

      final computedBills = BillCalculator.calculateAllBills(
        students: students,
        attendanceList: attendance,
        billsList: bills,
        menusList: menus,
        billingPeriod: activePeriod,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _bills = bills;
        _attendanceList = attendance;
        _menus = menus;
        _availablePeriods = periods;
        _selectedPeriod = activePeriod;
        _allBills = computedBills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load bills: $e')),
      );
    }
  }

  void _onPeriodChanged(String newPeriod) {
    if (newPeriod == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = newPeriod;
      _allBills = BillCalculator.calculateAllBills(
        students: _students,
        attendanceList: _attendanceList,
        billsList: _bills,
        menusList: _menus,
        billingPeriod: newPeriod,
      );
    });
  }

  Future<void> _updateStudentBillStatus(
    StudentBillSummary summary,
    String newStatus,
  ) async {
    final String normalizedStatus = newStatus.toLowerCase();
    if (summary.status == normalizedStatus) return;

    try {
      final periodDocId = '${summary.studentId}_${summary.billingPeriod}';

      final billData = {
        'id': periodDocId,
        'studentId': summary.studentId,
        'period': summary.billingPeriod,
        'month': summary.billingPeriodLabel,
        'status': normalizedStatus,
        'totalAmount': summary.totalBill,
        'totalMeals': summary.totalMeals,
        'breakfastCount': summary.breakfastCount,
        'breakfastAmount': summary.breakfastTotal,
        'lunchCount': summary.lunchCount,
        'lunchAmount': summary.lunchTotal,
        'dinnerCount': summary.dinnerCount,
        'dinnerAmount': summary.dinnerTotal,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestoreService.add('bills', periodDocId, billData);

      // Also update matching legacy records for this period if any exist
      for (final b in _bills) {
        if (b['studentId'] == summary.studentId &&
            b['date'] != null &&
            (summary.billingPeriod == 'all' ||
                b['date'].toString().startsWith(summary.billingPeriod))) {
          final id = b['id']?.toString() ?? '';
          if (id.isNotEmpty && id != periodDocId) {
            try {
              await _firestoreService.update('bills', id, {'status': normalizedStatus});
              b['status'] = normalizedStatus;
            } catch (_) {}
          }
        }
      }

      // Update in cached bills
      final existingIndex = _bills.indexWhere((b) => b['id'] == periodDocId);
      if (existingIndex >= 0) {
        _bills[existingIndex] = billData;
      } else {
        _bills.add(billData);
      }

      if (!mounted) return;

      setState(() {
        _allBills = _allBills.map((b) {
          if (b.studentId == summary.studentId) {
            return b.copyWith(status: normalizedStatus);
          }
          return b;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${summary.studentName}\'s bill marked as ${normalizedStatus.toUpperCase()}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  void _showDetailedBillDialog(StudentBillSummary summary) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isPaid = summary.status == 'paid';

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.studentName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          summary.billingPeriodLabel,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status & Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payment Status:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isPaid ? Colors.green : Colors.red,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: summary.status,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: isPaid ? Colors.green : Colors.red,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.green : Colors.red,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'unpaid',
                                    child: Text('unpaid', style: TextStyle(color: Colors.red)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'paid',
                                    child: Text('paid', style: TextStyle(color: Colors.green)),
                                  ),
                                ],
                                onChanged: (val) async {
                                  if (val != null && val != summary.status) {
                                    await _updateStudentBillStatus(summary, val);
                                    setDialogState(() {
                                      summary = summary.copyWith(status: val);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // R.5.2 & R.5.3 Breakdown Section
                      const Text(
                        'R.5.3 Student Bill Calculation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _calcRow(
                              'Breakfast',
                              summary.breakfastUnitPrice,
                              summary.breakfastCount,
                              summary.breakfastTotal,
                            ),
                            const SizedBox(height: 6),
                            _calcRow(
                              'Lunch',
                              summary.lunchUnitPrice,
                              summary.lunchCount,
                              summary.lunchTotal,
                            ),
                            const SizedBox(height: 6),
                            _calcRow(
                              'Dinner',
                              summary.dinnerUnitPrice,
                              summary.dinnerCount,
                              summary.dinnerTotal,
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Bill',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '₹${summary.totalBill.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Total Meals: ${summary.totalMeals} (${summary.breakfastTotal.toStringAsFixed(0)} + ${summary.lunchTotal.toStringAsFixed(0)} + ${summary.dinnerTotal.toStringAsFixed(0)})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // R.5.1 Meal Consumption History
                      const Text(
                        'R.5.1 Meal Consumption History',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      if (summary.consumptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No meals recorded for this period.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ...summary.consumptions.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getMealIcon(item.meal),
                                  size: 20,
                                  color: Colors.blueGrey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.meal[0].toUpperCase()}${item.meal.substring(1)} • ${item.date}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        item.menu,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _calcRow(String meal, double unitPrice, int count, double total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$meal = ₹${unitPrice.toStringAsFixed(0)} × $count days',
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          '₹${total.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  IconData _getMealIcon(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  List<StudentBillSummary> get _filteredBills {
    return _allBills.where((b) {
      if (_statusFilter == 'paid' && b.status != 'paid') return false;
      if (_statusFilter == 'unpaid' && b.status == 'paid') return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = b.studentName.toLowerCase().contains(query);
        final matchEmail = b.studentEmail.toLowerCase().contains(query);
        if (!matchName && !matchEmail) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBills;

    final totalBilled = _allBills.fold<double>(0, (sum, b) => sum + b.totalBill);
    final paidTotal = _allBills
        .where((b) => b.status == 'paid')
        .fold<double>(0, (sum, b) => sum + b.totalBill);
    final unpaidTotal = _allBills
        .where((b) => b.status != 'paid')
        .fold<double>(0, (sum, b) => sum + b.totalBill);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Management'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // R.5.4 Billing Period Selector
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.blue),
                          const SizedBox(width: 12),
                          const Text(
                            'Billing Period:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedPeriod,
                                items: _availablePeriods.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p['key'],
                                    child: Text(
                                      p['label'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) _onPeriodChanged(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Summary KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          'Total Billed',
                          '₹${totalBilled.toStringAsFixed(0)}',
                          '${_allBills.length} students',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kpiCard(
                          'Paid',
                          '₹${paidTotal.toStringAsFixed(0)}',
                          '${_allBills.where((b) => b.status == 'paid').length} paid',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kpiCard(
                          'Unpaid',
                          '₹${unpaidTotal.toStringAsFixed(0)}',
                          '${_allBills.where((b) => b.status != 'paid').length} pending',
                          Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Search & Filter
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search student...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'unpaid', label: Text('Unpaid')),
                          ButtonSegment(value: 'paid', label: Text('Paid')),
                        ],
                        selected: {_statusFilter},
                        onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No student bills found.')),
                    )
                  else
                    ...filtered.map((summary) {
                      final isPaid = summary.status == 'paid';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      summary.studentName.isNotEmpty
                                          ? summary.studentName[0].toUpperCase()
                                          : 'S',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          summary.studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Bill: ₹${summary.totalBill.toStringAsFixed(0)}  •  ${summary.totalMeals} meals',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Paid / Unpaid dropdown option
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isPaid ? Colors.green : Colors.red,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: isPaid ? 'paid' : 'unpaid',
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color: isPaid ? Colors.green : Colors.red,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isPaid ? Colors.green : Colors.red,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'unpaid',
                                            child: Text(
                                              'unpaid',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'paid',
                                            child: Text(
                                              'paid',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            _updateStudentBillStatus(summary, val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Meal Breakdown row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Breakfast: ${summary.breakfastCount}d (₹${summary.breakfastTotal.toStringAsFixed(0)})',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                    Text(
                                      'Lunch: ${summary.lunchCount}d (₹${summary.lunchTotal.toStringAsFixed(0)})',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                    Text(
                                      'Dinner: ${summary.dinnerCount}d (₹${summary.dinnerTotal.toStringAsFixed(0)})',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _showDetailedBillDialog(summary),
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('View Bill'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}