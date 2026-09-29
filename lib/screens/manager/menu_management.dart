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

  // ----------------------------------------------------------
  // DAYS
  // ----------------------------------------------------------

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // ----------------------------------------------------------
  // MENU DATA
  // ----------------------------------------------------------

  Map<String, Map<String, dynamic>> _menu = {};

  DateTime _currentDate = DateTime.now();

  bool _isLoading = true;

  String? _errorMessage;

  // ----------------------------------------------------------
  // INITIALIZE
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  // ----------------------------------------------------------
  // LOAD MENU
  // ----------------------------------------------------------

  Future<void> _loadMenu() async {
    try {
      final menuData =
      await _firestoreService.getAll('menus');

      final Map<String, Map<String, dynamic>>
      loadedMenu = {};

      for (final item in menuData) {
        final day = item['day']?.toString();

        if (day != null && day.isNotEmpty) {
          loadedMenu[day] = item;
        }
      }

      if (!mounted) return;

      setState(() {
        _menu = loadedMenu;
        _currentDate = DateTime.now();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Failed to load menu.';
      });
    }
  }

  // ----------------------------------------------------------
  // GET TODAY
  // ----------------------------------------------------------

  String _getToday() {
    return _days[_currentDate.weekday - 1];
  }

  // ----------------------------------------------------------
  // GET TOMORROW
  // ----------------------------------------------------------

  String _getTomorrow() {
    final tomorrow =
    _currentDate.add(
      const Duration(days: 1),
    );

    return _days[tomorrow.weekday - 1];
  }

  // ----------------------------------------------------------
  // GET MENU
  // ----------------------------------------------------------

  String _getMealMenu(
      String day,
      String meal,
      ) {
    final dayMenu = _menu[day];

    if (dayMenu == null) {
      return 'No menu added';
    }

    final value =
    dayMenu[meal.toLowerCase()]
        ?.toString()
        .trim();

    if (value == null || value.isEmpty) {
      return 'No menu added';
    }

    return value;
  }

  // ----------------------------------------------------------
  // GET EDITABLE MEALS
  //
  // NO TIME LIMIT
  //
  // TODAY:
  // Lunch
  // Dinner
  //
  // TOMORROW:
  // Breakfast
  // ----------------------------------------------------------

  List<Map<String, String>>
  _getEditableMeals() {
    final today = _getToday();
    final tomorrow = _getTomorrow();

    return [
      {
        'day': today,
        'meal': 'Lunch',
      },
      {
        'day': today,
        'meal': 'Dinner',
      },
      {
        'day': tomorrow,
        'meal': 'Breakfast',
      },
    ];
  }

  // ----------------------------------------------------------
  // MEAL ICON
  // ----------------------------------------------------------

  IconData _getMealIcon(
      String meal,
      ) {
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

  // ----------------------------------------------------------
  // SAVE MENU
  // ----------------------------------------------------------

  Future<void> _saveMenu(
      String day,
      String meal,
      String menuText,
      ) async {
    try {
      final existingMenu =
      await _firestoreService.get(
        'menus',
        day,
      );

      final Map<String, dynamic>
      updatedMenu = {};

      // Keep existing data.
      if (existingMenu != null) {
        updatedMenu.addAll(
          existingMenu,
        );
      }

      // Store day.
      updatedMenu['day'] = day;

      // Update only selected meal.
      updatedMenu[
      meal.toLowerCase()] =
          menuText.trim();

      await _firestoreService.add(
        'menus',
        day,
        updatedMenu,
      );

      if (!mounted) return;

      await _loadMenu();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Menu updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to update menu.',
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // EDIT MENU
  // ----------------------------------------------------------

  void _openEditMenu(
      String day,
      String meal,
      ) {
    final currentMenu =
    _getMealMenu(
      day,
      meal,
    );

    final controller =
    TextEditingController(
      text: currentMenu ==
          'No menu added'
          ? ''
          : currentMenu,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: Text(
                'Edit $meal',
              ),

              content:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextField(
                      controller:
                      controller,

                      maxLines: 4,

                      decoration:
                      InputDecoration(
                        labelText:
                        '$meal Menu',

                        hintText:
                        'Enter $meal menu',

                        border:
                        const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed:
                  isSaving
                      ? null
                      : () {
                    controller
                        .dispose();

                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final value =
                    controller
                        .text
                        .trim();

                    if (value.isEmpty) {
                      ScaffoldMessenger
                          .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content:
                          Text(
                            'Please enter the menu.',
                          ),
                        ),
                      );

                      return;
                    }

                    setDialogState(() {
                      isSaving = true;
                    });

                    await _saveMenu(
                      day,
                      meal,
                      value,
                    );

                    if (!mounted) {
                      return;
                    }

                    controller
                        .dispose();

                    Navigator.pop(
                      dialogContext,
                    );
                  },

                  child: isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu Management',
        ),
      ),

      body: _buildBody(),
    );
  }

  // ----------------------------------------------------------
  // BODY
  // ----------------------------------------------------------

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
        ),
      );
    }

    final editableMeals =
    _getEditableMeals();

    final today =
    _getToday();

    final tomorrow =
    _getTomorrow();

    final todayMeals =
    editableMeals
        .where(
          (item) =>
      item['day'] ==
          today,
    )
        .toList();

    final tomorrowMeals =
    editableMeals
        .where(
          (item) =>
      item['day'] ==
          tomorrow,
    )
        .toList();

    return RefreshIndicator(
      onRefresh: _loadMenu,

      child: ListView(
        padding:
        const EdgeInsets.all(16),

        children: [
          // --------------------------------------------------
          // TODAY
          // --------------------------------------------------

          _buildDaySection(
            title: 'Today',
            day: today,
            date: _currentDate,
            meals: todayMeals,
          ),

          const SizedBox(
            height: 24,
          ),

          // --------------------------------------------------
          // TOMORROW
          // --------------------------------------------------

          _buildDaySection(
            title: 'Tomorrow',
            day: tomorrow,
            date: _currentDate.add(
              const Duration(days: 1),
            ),
            meals: tomorrowMeals,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // DAY SECTION
  // ----------------------------------------------------------

  Widget _buildDaySection({
    required String title,
    required String day,
    required DateTime date,
    required List<Map<String, String>>
    meals,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        // ----------------------------------------------------
        // TITLE
        // ----------------------------------------------------

        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          '$day • '
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}',
          style: const TextStyle(
            fontSize: 16,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        // ----------------------------------------------------
        // MEALS
        // ----------------------------------------------------

        ...meals.map(
              (item) {
            final meal =
            item['meal']!;

            final menu =
            _getMealMenu(
              day,
              meal,
            );

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
                    // ----------------------------------------
                    // MEAL
                    // ----------------------------------------

                    Row(
                      children: [
                        Icon(
                          _getMealIcon(
                            meal,
                          ),
                          size: 30,
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Text(
                          meal,
                          style:
                          const TextStyle(
                            fontSize: 19,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ----------------------------------------
                    // CURRENT MENU
                    // ----------------------------------------

                    Text(
                      menu,
                      style:
                      const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ----------------------------------------
                    // EDIT BUTTON
                    // ----------------------------------------

                    SizedBox(
                      width:
                      double.infinity,

                      child:
                      OutlinedButton
                          .icon(
                        onPressed: () {
                          _openEditMenu(
                            day,
                            meal,
                          );
                        },

                        icon: const Icon(
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
    );
  }
}