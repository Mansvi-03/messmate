import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuManagement extends StatefulWidget {
  const MenuManagement({super.key});

  @override
  State<MenuManagement> createState() => _MenuManagementState();
}

class _MenuManagementState extends State<MenuManagement> {
  final FirestoreService _firestoreService = FirestoreService();

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Map<String, Map<String, dynamic>> _menu = {};

  DateTime _currentDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  static String _canonicalDay(String day) {
    if (day.trim().isEmpty) return day;
    final d = day.trim();
    return d[0].toUpperCase() + d.substring(1).toLowerCase();
  }

  Future<void> _loadMenu() async {
    try {
      final menuData = await _firestoreService.getAll('menus');

      final Map<String, Map<String, dynamic>> loadedMenu = {};

      for (final item in menuData) {
        final rawDay = item['day']?.toString() ?? item['id']?.toString() ?? '';
        final canonical = _canonicalDay(rawDay);

        if (canonical.isNotEmpty && _days.contains(canonical)) {
          final docId = item['id']?.toString() ?? '';
          // Prefer document whose ID exactly matches canonical day, or add if missing
          if (docId == canonical || !loadedMenu.containsKey(canonical)) {
            loadedMenu[canonical] = item;
          }
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
        _errorMessage = 'Failed to load menu.';
      });
    }
  }

  String _getToday() {
    return _days[_currentDate.weekday - 1];
  }

  String _getTomorrow() {
    final tomorrow = _currentDate.add(
      const Duration(days: 1),
    );

    return _days[tomorrow.weekday - 1];
  }

  Map<String, dynamic>? _getMealData(
      String day,
      String meal,
      ) {
    final dayMenu = _menu[day];

    if (dayMenu == null) {
      return null;
    }

    final value = dayMenu[meal.toLowerCase()];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    // Supports your old format:
    // "lunch": "dal, chaval"
    if (value != null) {
      return {
        'menu': value.toString(),
        'price': 0,
      };
    }

    return null;
  }

  String _getMealMenu(
      String day,
      String meal,
      ) {
    final data = _getMealData(day, meal);

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
      String day,
      String meal,
      ) {
    final data = _getMealData(day, meal);

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

  List<Map<String, String>> _getEditableMeals() {
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

  Future<void> _saveMenu(
      String day,
      String meal,
      String menuText,
      double price,
      ) async {
    try {
      final canonicalDay = _canonicalDay(day);

      final existingMenu = await _firestoreService.get(
        'menus',
        canonicalDay,
      );

      final Map<String, dynamic> updatedMenu = {};

      if (existingMenu != null) {
        updatedMenu.addAll(existingMenu);
      }

      updatedMenu['day'] = canonicalDay;

      updatedMenu[meal.toLowerCase()] = {
        'menu': menuText.trim(),
        'price': price,
      };

      await _firestoreService.add(
        'menus',
        canonicalDay,
        updatedMenu,
      );

      // Clean up legacy lowercase document if different
      if (canonicalDay.toLowerCase() != canonicalDay) {
        try {
          await _firestoreService.delete(
            'menus',
            canonicalDay.toLowerCase(),
          );
        } catch (_) {}
      }

      if (!mounted) return;

      // Update local state immediately
      setState(() {
        _menu[canonicalDay] = updatedMenu;
      });

      await _loadMenu();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Menu updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update menu: $e',
          ),
        ),
      );
    }
  }

  void _openEditMenu(
      String day,
      String meal,
      ) {
    final currentMenu = _getMealMenu(
      day,
      meal,
    );

    final currentPrice = _getMealPrice(
      day,
      meal,
    );

    final menuController = TextEditingController(
      text: currentMenu == 'No menu added'
          ? ''
          : currentMenu,
    );

    final priceController = TextEditingController(
      text: currentPrice > 0
          ? currentPrice.toString()
          : '',
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: menuController,
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

                    const SizedBox(height: 16),

                    TextField(
                      controller:
                      priceController,
                      keyboardType:
                      const TextInputType
                          .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                      const InputDecoration(
                        labelText: 'Price',
                        hintText:
                        'Enter meal price',
                        prefixText: '₹ ',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final menu =
                    menuController
                        .text
                        .trim();

                    final price =
                    double.tryParse(
                      priceController
                          .text
                          .trim(),
                    );

                    if (menu.isEmpty) {
                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter the menu.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (price == null ||
                        price <= 0) {
                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid price.',
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
                      menu,
                      price,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(
                        dialogContext,
                      );
                    }
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
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu Management',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
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

    final today = _getToday();
    final tomorrow = _getTomorrow();

    final todayMeals = editableMeals
        .where(
          (item) => item['day'] == today,
    )
        .toList();

    final tomorrowMeals = editableMeals
        .where(
          (item) => item['day'] == tomorrow,
    )
        .toList();

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDaySection(
            title: 'Today',
            day: today,
            date: _currentDate,
            meals: todayMeals,
          ),

          const SizedBox(height: 24),

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
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          '$day • '
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}',
          style: const TextStyle(
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 12),

        ...meals.map(
              (item) {
            final meal = item['meal']!;

            final menu = _getMealMenu(
              day,
              meal,
            );

            final price = _getMealPrice(
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
                const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getMealIcon(meal),
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
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      menu,
                      style:
                      const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    if (price > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Price: ₹${price.toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child:
                      OutlinedButton.icon(
                        onPressed: () {
                          _openEditMenu(
                            day,
                            meal,
                          );
                        },
                        icon: const Icon(
                          Icons.edit,
                        ),
                        label: const Text(
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