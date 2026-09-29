
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
          final FirestoreService _firestoreService =
          FirestoreService();

          bool _loading = true;
          bool _saving = false;

          List<Map<String, dynamic>> _students = [];

          final Map<String, bool> _attendance = {};

          String _selectedMeal = 'Breakfast';

          Map<String, dynamic>? _todayMenuData;

          double _mealPrice = 0;

          String _today = '';

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

          // =========================
          // LOAD STUDENTS + TODAY MENU
          // =========================

          Future<void> _loadData() async {
          try {
          final students =
          await _firestoreService.getAll('students');

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
          content: Text(
          'Failed to load data: $e',
          ),
          ),
          );
          }
          }

          // =========================
          // TODAY
          // =========================

          String _getToday() {
          final today = DateTime.now();

          return _days[today.weekday - 1];
          }

          // =========================
          // GET MEAL DATA
          // =========================

          Map<String, dynamic>? _getMealData(
          Map<String, dynamic>? dayMenu,
          String meal,
          ) {
          if (dayMenu == null) {
          return null;
          }

          final value =
          dayMenu[meal.toLowerCase()];

          if (value is Map) {
          return Map<String, dynamic>.from(value);
          }

          // Supports the old menu format too.
          if (value != null) {
          return {
          'menu': value.toString(),
          'price': 0,
          };
          }

          return null;
          }

          // =========================
          // GET MEAL MENU
          // =========================

          String _getMealMenu(
          Map<String, dynamic>? dayMenu,
          String meal,
          ) {
          final data = _getMealData(
          dayMenu,
          meal,
          );

          if (data == null) {
          return 'No menu added';
          }

          final menu =
          data['menu']?.toString().trim();

          if (menu == null || menu.isEmpty) {
          return 'No menu added';
          }

          return menu;
          }

          // =========================
          // GET MEAL PRICE
          // =========================

          double _getMealPrice(
          Map<String, dynamic>? dayMenu,
          String meal,
          ) {
          final data = _getMealData(
          dayMenu,
          meal,
          );

          if (data == null) {
          return 0;
          }

          final price = data['price'];

          if (price is num) {
          return price.toDouble();
          }

          return double.tryParse(
          price?.toString() ?? '',
          ) ??
          0;
          }

          // =========================
          // RESET ATTENDANCE
          // =========================

          void _resetAttendance() {
          _attendance.clear();

          for (final student in _students) {
          final id = student['id']?.toString();

          if (id != null && id.isNotEmpty) {
          _attendance[id] = false;
          }
          }
          }

          // =========================
          // CHANGE MEAL
          // =========================

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

          // =========================
          // SAVE ATTENDANCE + BILL
          // =========================
          
          Future<void> _saveAttendance() async {
            if (_saving) {
              return;
            }

            setState(() {
              _saving = true;
            });

            try {
              final date = _getDateString();

              // ==========================================
              // GET LATEST MENU FROM FIRESTORE
              // ==========================================

              final latestMenu = await _firestoreService.get(
                'menus',
                _today,
              );

              if (latestMenu == null) {
                throw Exception(
                  'No menu found for $_today.',
                );
              }

              // ==========================================
              // GET SELECTED MEAL DATA
              // ==========================================

              final mealKey = _selectedMeal.toLowerCase();

              final mealData = _getMealData(
                latestMenu,
                _selectedMeal,
              );

              if (mealData == null) {
                throw Exception(
                  'No $_selectedMeal menu found for $_today.',
                );
              }

              // ==========================================
              // GET PRICE
              // ==========================================

              dynamic priceValue = mealData['price'];

              // Support "amount" if the menu uses that field.
              if (priceValue == null) {
                priceValue = mealData['amount'];
              }

              // Support "mealPrice" if used in menu data.
              if (priceValue == null) {
                priceValue = mealData['mealPrice'];
              }

              double mealPrice = 0;

              if (priceValue is num) {
                mealPrice = priceValue.toDouble();
              } else if (priceValue != null) {
                mealPrice =
                    double.tryParse(
                      priceValue.toString().trim(),
                    ) ??
                        0;
              }

              // ==========================================
              // NEVER SAVE A ZERO-PRICE BILL
              // ==========================================

              if (mealPrice <= 0) {
                throw Exception(
                  'Price for $_selectedMeal on $_today is not set. '
                      'Please add the meal price in Menu Management first.',
                );
              }

              // ==========================================
              // UPDATE LOCAL PRICE
              // ==========================================

              if (mounted) {
                setState(() {
                  _todayMenuData = latestMenu;
                  _mealPrice = mealPrice;
                });
              }

              // ==========================================
              // SAVE EACH STUDENT
              // ==========================================

              for (final student in _students) {
                final studentId =
                student['id']?.toString();

                if (studentId == null ||
                    studentId.isEmpty) {
                  continue;
                }

                final isPresent =
                    _attendance[studentId] ?? false;

                // Example:
                //
                // abc123_2026-09-29_lunch
                //
                final recordId =
                    '${studentId}_${date}_$mealKey';

                // ==========================================
                // SAVE ATTENDANCE
                // ==========================================

                await _firestoreService.add(
                  'attendance',
                  recordId,
                  {
                    'studentId': studentId,
                    'date': date,
                    'day': _today,
                    'meal': mealKey,
                    'present': isPresent,
                  },
                );

                // ==========================================
                // PRESENT -> CREATE / UPDATE BILL
                // ==========================================

                if (isPresent) {
                  await _firestoreService.add(
                    'bills',
                    recordId,
                    {
                      'studentId': studentId,
                      'date': date,
                      'day': _today,
                      'meal': mealKey,

                      // The actual meal price.
                      'amount': mealPrice,

                      // Store price as well for clarity.
                      'price': mealPrice,

                      'status': 'unpaid',

                      'createdAt':
                      DateTime.now()
                          .toIso8601String(),
                    },
                  );
                }

                // ==========================================
                // ABSENT -> DELETE BILL
                // ==========================================

                else {
                  try {
                    await _firestoreService.delete(
                      'bills',
                      recordId,
                    );
                  } catch (_) {
                    // Bill may not exist.
                  }
                }
              }

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$_selectedMeal attendance saved successfully. '
                        'Price: ₹${mealPrice.toStringAsFixed(2)}',
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
                  content: Text(
                    'Failed to save attendance: $e',
                  ),
                ),
              );
            } finally {
              if (!mounted) return;

              setState(() {
                _saving = false;
              });
            }
          }



          // =========================
          // DATE STRING
          // =========================

          String _getDateString() {
          final today = DateTime.now();

          return '${today.year}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
          }

          // =========================
          // MEAL ICON
          // =========================

          IconData _getMealIcon(String meal) {
          switch (meal) {
          case 'Breakfast':
          return Icons.free_breakfast;

          case 'Lunch':
          return Icons.lunch_dining;

          case 'Dinner':
          return Icons.dinner_dining;

          default:
          return Icons.restaurant;
          }
          }

          // =========================
          // BUILD
          // =========================

          @override
          Widget build(BuildContext context) {
          return Scaffold(
          appBar: AppBar(
          title: const Text(
          'Attendance Management',
          ),
          ),
          body: _loading
          ? const Center(
          child: CircularProgressIndicator(),
          )
              : _buildBody(),
          );
          }

          // =========================
          // BODY
          // =========================

          Widget _buildBody() {
          if (_students.isEmpty) {
          return const Center(
          child: Text(
          'No students registered',
          ),
          );
          }

          final mealMenu = _getMealMenu(
          _todayMenuData,
          _selectedMeal,
          );

          return Column(
          children: [
          // =========================
          // TODAY + MEAL
          // =========================

          Padding(
          padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          8,
          ),
          child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
          Text(
          'Today',
          style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          ),
          ),

          const SizedBox(height: 4),

          Text(
          '$_today • ${_getDateString()}',
          style: const TextStyle(
          fontSize: 16,
          ),
          ),

          const SizedBox(height: 16),

          // =========================
          // MEAL DROPDOWN
          // =========================

          DropdownButtonFormField<String>(
          value: _selectedMeal,
          decoration:
          const InputDecoration(
          labelText: 'Select Meal',
          border: OutlineInputBorder(),
          ),
          items: const [
          DropdownMenuItem(
          value: 'Breakfast',
          child: Text('Breakfast'),
          ),
          DropdownMenuItem(
          value: 'Lunch',
          child: Text('Lunch'),
          ),
          DropdownMenuItem(
          value: 'Dinner',
          child: Text('Dinner'),
          ),
          ],
          onChanged: (value) {
          if (value == null) {
          return;
          }

          _changeMeal(value);
          },
          ),

          const SizedBox(height: 16),

          // =========================
          // MENU INFORMATION
          // =========================

          Card(
          child: Padding(
          padding:
          const EdgeInsets.all(16),
          child: Row(
          children: [
          Icon(
          _getMealIcon(
          _selectedMeal,
          ),
          size: 30,
          ),

          const SizedBox(width: 12),

          Expanded(
          child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
          Text(
          _selectedMeal,
          style:
          const TextStyle(
          fontSize: 18,
          fontWeight:
          FontWeight.bold,
          ),
          ),

          const SizedBox(height: 4),

          Text(
          mealMenu,
          ),

          const SizedBox(height: 4),

          Text(
          _mealPrice > 0
          ? 'Price: ₹${_mealPrice.toStringAsFixed(2)}'
              : 'Price not added',
          style:
          const TextStyle(
          fontWeight:
          FontWeight.bold,
          ),
          ),
          ],
          ),
          ),
          ],
          ),
          ),
          ),
          ],
          ),
          ),

          // =========================
          // STUDENTS
          // =========================

          Expanded(
          child: ListView.builder(
          itemCount: _students.length,
          itemBuilder: (
          context,
          index,
          ) {
          final student =
          _students[index];

          final id =
          student['id']
              ?.toString() ??
          '';

          final name =
          student['name']
              ?.toString() ??
          'Unknown Student';

          final email =
          student['email']
              ?.toString() ??
          '';

          return SwitchListTile(
          title: Text(name),
          subtitle: Text(email),
          value:
          _attendance[id] ??
          false,
          onChanged:
          _mealPrice <= 0
          ? null
              : (value) {
          setState(() {
          _attendance[id] =
          value;
          });
          },
          );
          },
          ),
          ),

          // =========================
          // SAVE BUTTON
          // =========================

          Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
          onPressed:
          _saving ||
          _mealPrice <= 0
          ? null
              : _saveAttendance,
          child: _saving
          ? const SizedBox(
          height: 22,
          width: 22,
          child:
          CircularProgressIndicator(
          strokeWidth: 2,
          ),
          )
              : const Text(
          'Save Attendance',
          ),
          ),
          ),
          ),
          ],
          );
          }
          }

