import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuManagement extends StatefulWidget {
  const MenuManagement({super.key});

  @override
  State<MenuManagement> createState() =>
      _MenuManagementState();
}

class _MenuManagementState
    extends State<MenuManagement> {
  final FirestoreService _firestoreService =
  FirestoreService();

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _meals = [
    'Breakfast',
    'Lunch',
    'Dinner',
  ];

  Map<String, Map<String, dynamic>> _menus = {};

  bool _isLoading = true;

  DateTime _currentDate = DateTime.now();

  Timer? _dateTimer;

  @override
  void initState() {
    super.initState();

    _loadMenus();

    // Keeps the displayed date up to date.
    _dateTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) {
        if (!mounted) return;

        setState(() {
          _currentDate = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------
  // LOAD MENUS
  // ----------------------------------------------------------

  Future<void> _loadMenus() async {
    try {
      final data =
      await _firestoreService.getAll(
        'menus',
      );

      final Map<String, Map<String, dynamic>>
      loadedMenus = {};

      for (final menu in data) {
        final day =
        menu['day']?.toString();

        if (day != null) {
          loadedMenus[day] = menu;
        }
      }

      if (!mounted) return;

      setState(() {
        _menus = loadedMenus;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Failed to load menus.',
      );
    }
  }

  // ----------------------------------------------------------
  // GET DATE FOR A DAY OF CURRENT WEEK
  // ----------------------------------------------------------

  DateTime _dateForDay(String day) {
    final today = _currentDate;

    final monday =
    today.subtract(
      Duration(
        days: today.weekday - 1,
      ),
    );

    final index = _days.indexOf(day);

    return DateTime(
      monday.year,
      monday.month,
      monday.day + index,
    );
  }

  // ----------------------------------------------------------
  // FORMAT DATE
  // ----------------------------------------------------------

  String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    final year =
    date.year.toString();

    return '$day/$month/$year';
  }

  // ----------------------------------------------------------
  // MEAL KEY
  // ----------------------------------------------------------

  String _mealKey(String meal) {
    return meal.toLowerCase();
  }

  // ----------------------------------------------------------
  // EDIT MENU
  // ----------------------------------------------------------

  Future<void> _editMenu(
      String day,
      ) async {
    final existing =
        _menus[day] ?? {};

    final breakfastController =
    TextEditingController(
      text:
      existing['breakfast']?.toString() ??
          '',
    );

    final lunchController =
    TextEditingController(
      text:
      existing['lunch']?.toString() ??
          '',
    );

    final dinnerController =
    TextEditingController(
      text:
      existing['dinner']?.toString() ??
          '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '$day Menu',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Text(
                  _formatDate(
                    _dateForDay(day),
                  ),
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // BREAKFAST
                TextField(
                  controller:
                  breakfastController,
                  maxLines: 2,
                  decoration:
                  const InputDecoration(
                    labelText: 'Breakfast',
                    hintText:
                    'Enter breakfast menu',
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                // LUNCH
                TextField(
                  controller:
                  lunchController,
                  maxLines: 2,
                  decoration:
                  const InputDecoration(
                    labelText: 'Lunch',
                    hintText:
                    'Enter lunch menu',
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                // DINNER
                TextField(
                  controller:
                  dinnerController,
                  maxLines: 2,
                  decoration:
                  const InputDecoration(
                    labelText: 'Dinner',
                    hintText:
                    'Enter dinner menu',
                    border:
                    OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final date =
                _dateForDay(day);

                await _firestoreService.add(
                  'menus',
                  day.toLowerCase(),
                  {
                    'day': day,
                    'date':
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    'breakfast':
                    breakfastController
                        .text
                        .trim(),
                    'lunch':
                    lunchController
                        .text
                        .trim(),
                    'dinner':
                    dinnerController
                        .text
                        .trim(),
                    'updatedAt':
                    DateTime.now()
                        .toIso8601String(),
                  },
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(context);

                await _loadMenus();

                if (!mounted) return;

                _showMessage(
                  '$day menu updated.',
                );
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    breakfastController.dispose();
    lunchController.dispose();
    dinnerController.dispose();
  }

  // ----------------------------------------------------------
  // MESSAGE
  // ----------------------------------------------------------

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final today =
        _currentDate;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu Management',
        ),
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadMenus,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            // CURRENT DATE
            Card(
              child: Padding(
                padding:
                const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 30,
                    ),
                    const SizedBox(
                      width: 15,
                    ),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          '${_days[today.weekday - 1]} • '
                              '${_formatDate(today)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Weekly Menu',
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ..._days.map(
                  (day) {
                final menu =
                _menus[day];

                final date =
                _dateForDay(day);

                return Card(
                  margin:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                          children: [
                            Text(
                              day,
                              style:
                              const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                            Text(
                              _formatDate(
                                date,
                              ),
                            ),
                          ],
                        ),

                        const Divider(),

                        _mealRow(
                          'Breakfast',
                          menu?['breakfast'],
                          Icons.free_breakfast,
                        ),

                        _mealRow(
                          'Lunch',
                          menu?['lunch'],
                          Icons.lunch_dining,
                        ),

                        _mealRow(
                          'Dinner',
                          menu?['dinner'],
                          Icons.dinner_dining,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        SizedBox(
                          width:
                          double.infinity,
                          child:
                          ElevatedButton.icon(
                            onPressed: () {
                              _editMenu(
                                day,
                              );
                            },
                            icon:
                            const Icon(
                              Icons.edit,
                            ),
                            label:
                            const Text(
                              'Edit Menu',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealRow(
      String meal,
      dynamic menu,
      IconData icon,
      ) {
    final value =
    menu?.toString().trim();

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  meal,
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value == null ||
                      value.isEmpty
                      ? 'No menu added'
                      : value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}