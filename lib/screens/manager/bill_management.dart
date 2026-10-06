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
            '${summary.studentName}\'s status updated to ${normalizedStatus.toUpperCase()}',
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

  void _showDetailedBillDialog(StudentBillSummary initialSummary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        StudentBillSummary summary = initialSummary;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isPaid = summary.status == 'paid';
            final mediaQuery = MediaQuery.of(context);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  height: mediaQuery.size.height * 0.90,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Top Drag Handle Bar
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 42,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Header Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              child: Text(
                                summary.studentName.trim().isNotEmpty
                                    ? summary.studentName.trim()[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF2563EB),
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_rounded,
                                        size: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        summary.billingPeriodLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(bottomSheetCtx),
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Scrollable Body
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          children: [
                            // Status Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                      size: 20,
                                      color: isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPaid ? 'Payment Received' : 'Payment Pending',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isPaid ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          isPaid
                                              ? 'All dues settled for this period'
                                              : 'Dues are currently unpaid',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isPaid ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () async {
                                      final next = isPaid ? 'unpaid' : 'paid';
                                      await _updateStudentBillStatus(summary, next);
                                      setSheetState(() {
                                        summary = summary.copyWith(status: next);
                                      });
                                    },
                                    child: Text(
                                      isPaid ? 'Mark UNPAID' : 'Mark PAID',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Calculation Breakdown Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Calculation Breakdown',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${summary.totalMeals} Meals Total',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Breakdown Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _calcRow(
                                    'Breakfast',
                                    summary.breakfastCount,
                                    summary.breakfastTotal,
                                  ),
                                  const SizedBox(height: 10),
                                  _calcRow(
                                    'Lunch',
                                    summary.lunchCount,
                                    summary.lunchTotal,
                                  ),
                                  const SizedBox(height: 10),
                                  _calcRow(
                                    'Dinner',
                                    summary.dinnerCount,
                                    summary.dinnerTotal,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Statement Bill',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Final calculated payable',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₹${summary.totalBill.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
                                          color: isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Meal Consumption Logs Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Meal Consumption Logs',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${summary.consumptions.length} Records',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (summary.consumptions.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.restaurant_outlined,
                                        size: 36,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No recorded meals for this period.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...summary.consumptions.map((item) {
                                final mealColor = _getMealColor(item.meal);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: mealColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _getMealIcon(item.meal),
                                          size: 20,
                                          color: mealColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  '${item.meal[0].toUpperCase()}${item.meal.substring(1)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '•  ${item.date}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item.menu.trim().isNotEmpty
                                                  ? item.menu
                                                  : 'Standard meal menu',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                height: 1.25,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '₹${item.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // Bottom Action Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(bottomSheetCtx),
                            child: const Text(
                              'Close Statement',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _calcRow(String meal, int count, double total) {
    final mealColor = _getMealColor(meal);
    final countLabel = count == 0
        ? '0 meals attended'
        : '$count meal${count > 1 ? 's' : ''} attended (per menu rate)';
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: mealColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getMealIcon(meal), size: 16, color: mealColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '₹${total.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Color _getMealColor(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return const Color(0xFFD97706);
      case 'lunch':
        return const Color(0xFF0284C7);
      case 'dinner':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF059669);
    }
  }

  IconData _getMealIcon(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Period Selector Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Billing Period:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedPeriod,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              items: _availablePeriods.map((p) {
                                return DropdownMenuItem<String>(
                                  value: p['key'],
                                  child: Text(
                                    p['label'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

                  const SizedBox(height: 12),

                  // KPI Summary Metrics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          'Total Billed',
                          '₹${totalBilled.toStringAsFixed(0)}',
                          '${_allBills.length} students',
                          const Color(0xFF2563EB),
                          const Color(0xFFEFF6FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kpiCard(
                          'Paid',
                          '₹${paidTotal.toStringAsFixed(0)}',
                          '${_allBills.where((b) => b.status == 'paid').length} settled',
                          const Color(0xFF059669),
                          const Color(0xFFECFDF5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kpiCard(
                          'Unpaid',
                          '₹${unpaidTotal.toStringAsFixed(0)}',
                          '${_allBills.where((b) => b.status != 'paid').length} pending',
                          const Color(0xFFDC2626),
                          const Color(0xFFFEF2F2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Search & Filter Controls (Mobile-Optimized)
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search student by name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All Bills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        ButtonSegment(value: 'unpaid', label: Text('Pending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        ButtonSegment(value: 'paid', label: Text('Settled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                    ),
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
                      final initial = summary.studentName.isNotEmpty
                          ? summary.studentName[0].toUpperCase()
                          : 'S';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D4ED8),
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
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        '₹${summary.totalBill.toStringAsFixed(0)} • ${summary.totalMeals} meals',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                // Toggle status button
                                Material(
                                  color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      _updateStudentBillStatus(
                                        summary,
                                        isPaid ? 'unpaid' : 'paid',
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                            size: 14,
                                            color: isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isPaid ? 'PAID' : 'UNPAID',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isPaid ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Meals count preview row (Mobile-Safe Wrap)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                runSpacing: 6,
                                spacing: 8,
                                children: [
                                  _mealMiniChip('Breakfast', summary.breakfastCount, summary.breakfastTotal, const Color(0xFFD97706)),
                                  _mealMiniChip('Lunch', summary.lunchCount, summary.lunchTotal, const Color(0xFF0284C7)),
                                  _mealMiniChip('Dinner', summary.dinnerCount, summary.dinnerTotal, const Color(0xFF7C3AED)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showDetailedBillDialog(summary),
                                icon: const Icon(Icons.receipt_rounded, size: 16),
                                label: const Text('View Detailed Statement'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _mealMiniChip(String name, int count, double total, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$name: $count (₹${total.toStringAsFixed(0)})',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}