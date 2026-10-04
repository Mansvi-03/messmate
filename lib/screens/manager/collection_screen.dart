import 'package:flutter/material.dart';

import '../../services/bill_calculator.dart';
import '../../services/firestore_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  String _selectedPeriod = '';
  List<Map<String, String>> _availablePeriods = [];

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _attendanceList = [];
  List<Map<String, dynamic>> _menus = [];

  List<StudentBillSummary> _allBills = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'paid', 'unpaid'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPeriod = BillCalculator.getMonthKey(DateTime.now());
    _loadCollection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollection() async {
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
        SnackBar(content: Text('Failed to load collection: $e')),
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

  Future<void> _togglePaymentStatus(StudentBillSummary summary) async {
    final newStatus = summary.status == 'paid' ? 'unpaid' : 'paid';
    final periodDocId = '${summary.studentId}_${summary.billingPeriod}';

    try {
      final billData = {
        'id': periodDocId,
        'studentId': summary.studentId,
        'period': summary.billingPeriod,
        'month': summary.billingPeriodLabel,
        'status': newStatus,
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

      final idx = _bills.indexWhere((b) => b['id'] == periodDocId);
      if (idx >= 0) {
        _bills[idx] = billData;
      } else {
        _bills.add(billData);
      }

      if (!mounted) return;

      setState(() {
        _allBills = _allBills.map((b) {
          if (b.studentId == summary.studentId) {
            return b.copyWith(status: newStatus);
          }
          return b;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${summary.studentName}\'s status updated to ${newStatus.toUpperCase()}',
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

  @override
  Widget build(BuildContext context) {
    final paidBills = _allBills.where((b) => b.status == 'paid').toList();
    final unpaidBills = _allBills.where((b) => b.status != 'paid').toList();

    final double totalCollection = paidBills.fold<double>(0, (sum, b) => sum + b.totalBill);
    final double pendingAmount = unpaidBills.fold<double>(0, (sum, b) => sum + b.totalBill);
    final double totalTarget = totalCollection + pendingAmount;
    final double collectionRate = totalTarget > 0 ? (totalCollection / totalTarget) : 0.0;

    final filteredBills = _allBills.where((b) {
      if (_filterStatus == 'paid' && b.status != 'paid') return false;
      if (_filterStatus == 'unpaid' && b.status == 'paid') return false;
      if (_searchQuery.isNotEmpty &&
          !b.studentName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mess Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCollection,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF059669)),
            )
          : RefreshIndicator(
              onRefresh: _loadCollection,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Period Selector Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF059669),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Billing Period:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                    ),
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

                  const SizedBox(height: 16),

                  // Hero Financial KPI Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL COLLECTED',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(collectionRate * 100).toStringAsFixed(1)}% Settled',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalCollection.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: collectionRate.clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            minHeight: 7,
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 14),

                        // 3 Quick Metrics Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _kpiMiniCol(
                              'PENDING DUES',
                              '₹${pendingAmount.toStringAsFixed(0)}',
                              const Color(0xFFF87171),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFF334155)),
                            _kpiMiniCol(
                              'PAID BILLS',
                              '${paidBills.length} / ${_allBills.length}',
                              const Color(0xFF34D399),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFF334155)),
                            _kpiMiniCol(
                              'UNPAID DUES',
                              '${unpaidBills.length} students',
                              const Color(0xFFFBBF24),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Search & Filter Controls
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                          decoration: InputDecoration(
                            hintText: 'Search student...',
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Segmented Filter Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'All (${_allBills.length})'),
                        const SizedBox(width: 8),
                        _filterChip('unpaid', 'Pending (${unpaidBills.length})', isAlert: true),
                        const SizedBox(width: 8),
                        _filterChip('paid', 'Settled (${paidBills.length})'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Student Breakdown Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Student Breakdown (${filteredBills.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (filteredBills.isNotEmpty)
                        Text(
                          'Tap action to toggle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (filteredBills.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No student matching "$_searchQuery"'
                                : 'No records found for this filter',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredBills.map((summary) {
                      final isPaid = summary.status == 'paid';
                      final initial = summary.studentName.trim().isNotEmpty
                          ? summary.studentName.trim()[0].toUpperCase()
                          : 'S';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPaid ? const Color(0xFFE2E8F0) : const Color(0xFFFECDD3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isPaid
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isPaid
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFEF4444),
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
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${summary.totalBill.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isPaid
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFE11D48),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${summary.totalMeals} meals',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _togglePaymentStatus(summary),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isPaid
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFEF4444))
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPaid ? 'PAID' : 'UNPAID',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _filterChip(String status, String label, {bool isAlert = false}) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isAlert ? const Color(0xFFDC2626) : const Color(0xFF475569)),
        ),
      ),
      selected: isSelected,
      selectedColor: isAlert ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
      backgroundColor: isAlert
          ? const Color(0xFFFEE2E2).withValues(alpha: 0.5)
          : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : (isAlert ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (val) {
        if (val) setState(() => _filterStatus = status);
      },
    );
  }

  Widget _kpiMiniCol(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}