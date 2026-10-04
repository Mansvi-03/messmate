import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class AttendanceManagement extends StatefulWidget {
  const AttendanceManagement({super.key});

  @override
  State<AttendanceManagement> createState() =>
      _AttendanceManagementState();
}

class _AttendanceManagementState
    extends State<AttendanceManagement> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _students = [];
  final Map<String, bool> _attendance = {};

  String _selectedMeal = 'Breakfast';
  Map<String, dynamic>? _todayMenuData;
  double _mealPrice = 0;
  String _today = '';

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================
  // LOAD STUDENTS + TODAY MENU
  // =========================

  Future<void> _loadData() async {
    try {
      final students = await _firestoreService.getAll('students');
      final today = _getToday();
      final menuData = await _firestoreService.get(
        'menus',
        today,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _today = today;
        _todayMenuData = menuData;
        _mealPrice = _getMealPrice(
          menuData,
          _selectedMeal,
        );
        _loading = false;
        _resetAttendance();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: $e'),
        ),
      );
    }
  }

  String _getToday() {
    final today = DateTime.now();
    return _days[today.weekday - 1];
  }

  Map<String, dynamic>? _getMealData(
    Map<String, dynamic>? dayMenu,
    String meal,
  ) {
    if (dayMenu == null) return null;

    final value = dayMenu[meal.toLowerCase()];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value != null) {
      return {
        'menu': value.toString(),
        'price': 0,
      };
    }

    return null;
  }

  String _getMealMenu(
    Map<String, dynamic>? dayMenu,
    String meal,
  ) {
    final data = _getMealData(dayMenu, meal);

    if (data == null) {
      return 'No menu added';
    }

    final menu = data['menu']?.toString().trim();

    if (menu == null || menu.isEmpty) {
      return 'No menu added';
    }

    return menu;
  }

  double _getMealPrice(
    Map<String, dynamic>? dayMenu,
    String meal,
  ) {
    final data = _getMealData(dayMenu, meal);

    if (data == null) return 0;

    final price = data['price'];

    if (price is num) {
      return price.toDouble();
    }

    return double.tryParse(price?.toString() ?? '') ?? 0;
  }

  void _resetAttendance() {
    _attendance.clear();
    for (final student in _students) {
      final id = student['id']?.toString();
      if (id != null && id.isNotEmpty) {
        _attendance[id] = false;
      }
    }
  }

  void _markAll(bool present) {
    setState(() {
      for (final student in _students) {
        final id = student['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _attendance[id] = present;
        }
      }
    });
  }

  void _changeMeal(String meal) {
    setState(() {
      _selectedMeal = meal;
      _mealPrice = _getMealPrice(
        _todayMenuData,
        _selectedMeal,
      );
      _resetAttendance();
    });
  }

  Future<void> _saveAttendance() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final date = _getDateString();
      final latestMenu = await _firestoreService.get(
        'menus',
        _today,
      );

      if (latestMenu == null) {
        throw Exception('No menu found for $_today.');
      }

      final mealKey = _selectedMeal.toLowerCase();
      final mealData = _getMealData(latestMenu, _selectedMeal);

      if (mealData == null) {
        throw Exception('No $_selectedMeal menu found for $_today.');
      }

      dynamic priceValue = mealData['price'];
      priceValue ??= mealData['amount'];
      priceValue ??= mealData['mealPrice'];

      double mealPrice = 0;
      if (priceValue is num) {
        mealPrice = priceValue.toDouble();
      } else if (priceValue != null) {
        mealPrice = double.tryParse(priceValue.toString().trim()) ?? 0;
      }

      if (mealPrice <= 0) {
        throw Exception(
          'Price for $_selectedMeal on $_today is not set. '
          'Please set the meal price in Menu Management first.',
        );
      }

      if (mounted) {
        setState(() {
          _todayMenuData = latestMenu;
          _mealPrice = mealPrice;
        });
      }

      for (final student in _students) {
        final studentId = student['id']?.toString();
        if (studentId == null || studentId.isEmpty) continue;

        final isPresent = _attendance[studentId] ?? false;
        final recordId = '${studentId}_${date}_$mealKey';

        await _firestoreService.add(
          'attendance',
          recordId,
          {
            'studentId': studentId,
            'date': date,
            'day': _today,
            'meal': mealKey,
            'present': isPresent,
            'price': mealPrice,
            'menu': _getMealMenu(_todayMenuData, _selectedMeal),
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_selectedMeal attendance saved successfully (₹${mealPrice.toStringAsFixed(2)}/meal).',
          ),
        ),
      );

      setState(() {
        _resetAttendance();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _getDateString() {
    final today = DateTime.now();
    return '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
  }

  IconData _getMealIcon(String meal) {
    switch (meal) {
      case 'Breakfast':
        return Icons.free_breakfast_rounded;
      case 'Lunch':
        return Icons.lunch_dining_rounded;
      case 'Dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  int get _presentCount {
    return _attendance.values.where((v) => v == true).length;
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    final query = _searchQuery.toLowerCase();
    return _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Roll Call'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_students.isEmpty) {
      return const Center(
        child: Text('No students currently registered.'),
      );
    }

    final mealMenu = _getMealMenu(_todayMenuData, _selectedMeal);
    final isPriceConfigured = _mealPrice > 0;
    final filtered = _filteredStudents;

    return Column(
      children: [
        // Top Meal Segment & Menu Info Card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Status Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_today, ${_getDateString()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Select meal service to take roll call',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPriceConfigured
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPriceConfigured
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Text(
                      isPriceConfigured
                          ? '₹${_mealPrice.toStringAsFixed(0)} / meal'
                          : 'Price Missing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPriceConfigured
                            ? const Color(0xFF065F46)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Meal Selection Tabs
              Row(
                children: ['Breakfast', 'Lunch', 'Dinner'].map((meal) {
                  final isSelected = _selectedMeal == meal;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Material(
                        color: isSelected
                            ? const Color(0xFF059669)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _changeMeal(meal),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getMealIcon(meal),
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  meal,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Menu preview summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_selectedMeal Menu: $mealMenu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!isPriceConfigured) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Price for this meal is 0. Add price in Menu Management before taking attendance.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Search & Fast Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search student...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: isPriceConfigured ? () => _markAll(true) : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('All Present'),
              ),
              TextButton(
                onPressed: isPriceConfigured ? () => _markAll(false) : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),

        // Students Roll List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No students match your search.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final student = filtered[index];
                    final id = student['id']?.toString() ?? '';
                    final name = student['name']?.toString() ?? 'Student';
                    final email = student['email']?.toString() ?? '';
                    final isPresent = _attendance[id] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPresent
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0),
                          width: isPresent ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF1F5F9),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isPresent
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        trailing: Switch(
                          value: isPresent,
                          activeThumbColor: const Color(0xFF059669),
                          activeTrackColor: const Color(0xFFA7F3D0),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          onChanged: !isPriceConfigured
                              ? null
                              : (value) {
                                  setState(() {
                                    _attendance[id] = value;
                                  });
                                },
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Save Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving || !isPriceConfigured ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_upload_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Save $_selectedMeal Attendance ($_presentCount Present)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


