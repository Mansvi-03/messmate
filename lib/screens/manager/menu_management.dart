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
    String day,
    String meal,
  ) {
    final data = _getMealData(day, meal);
    if (data == null) return 'No menu added yet';

    final menu = data['menu']?.toString().trim();
    if (menu == null || menu.isEmpty) return 'No menu added yet';

    return menu;
  }

  double _getMealPrice(
    String day,
    String meal,
  ) {
    final data = _getMealData(day, meal);
    if (data == null) return 0;

    final price = data['price'];
    if (price is num) return price.toDouble();

    return double.tryParse(price?.toString() ?? '') ?? 0;
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
        return Icons.free_breakfast_rounded;
      case 'Lunch':
        return Icons.lunch_dining_rounded;
      case 'Dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Color _getMealColor(String meal) {
    switch (meal) {
      case 'Breakfast':
        return const Color(0xFFD97706);
      case 'Lunch':
        return const Color(0xFF0284C7);
      case 'Dinner':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF059669);
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

      if (canonicalDay.toLowerCase() != canonicalDay) {
        try {
          await _firestoreService.delete(
            'menus',
            canonicalDay.toLowerCase(),
          );
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _menu[canonicalDay] = updatedMenu;
      });

      await _loadMenu();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu and pricing updated successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update menu: $e'),
        ),
      );
    }
  }

  void _openEditMenu(
    String day,
    String meal,
  ) {
    final currentMenu = _getMealMenu(day, meal);
    final currentPrice = _getMealPrice(day, meal);

    final menuController = TextEditingController(
      text: currentMenu == 'No menu added yet' ? '' : currentMenu,
    );

    final priceController = TextEditingController(
      text: currentPrice > 0 ? currentPrice.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final mealColor = _getMealColor(meal);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: mealColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getMealIcon(meal), color: mealColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure $meal',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: menuController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '$meal Menu Items',
                        hintText: 'e.g. Dal Makhani, Paneer, Rice, Chapatis, Gulab Jamun',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price per meal',
                        hintText: '50',
                        prefixText: '₹ ',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final menu = menuController.text.trim();
                          final price = double.tryParse(priceController.text.trim());

                          if (menu.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter the menu items.'),
                              ),
                            );
                            return;
                          }

                          if (price == null || price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid meal price (> 0).'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          await _saveMenu(day, meal, menu, price);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
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
        title: const Text('Menu Management'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
        ),
      );
    }

    final editableMeals = _getEditableMeals();
    final today = _getToday();
    final tomorrow = _getTomorrow();

    final todayMeals = editableMeals.where((item) => item['day'] == today).toList();
    final tomorrowMeals = editableMeals.where((item) => item['day'] == tomorrow).toList();

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          _buildDaySection(
            title: 'Today',
            day: today,
            date: _currentDate,
            badgeText: 'Active Today',
            badgeColor: const Color(0xFF059669),
            meals: todayMeals,
          ),
          const SizedBox(height: 24),
          _buildDaySection(
            title: 'Tomorrow',
            day: tomorrow,
            date: _currentDate.add(const Duration(days: 1)),
            badgeText: 'Next Day Prep',
            badgeColor: const Color(0xFF0284C7),
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
    required String badgeText,
    required Color badgeColor,
    required List<Map<String, String>> meals,
  }) {
    final dateFormatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($day)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  dateFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        ...meals.map((item) {
          final meal = item['meal']!;
          final menu = _getMealMenu(day, meal);
          final price = _getMealPrice(day, meal);
          final mealColor = _getMealColor(meal);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: mealColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getMealIcon(meal),
                        color: mealColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        meal,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: price > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: price > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Text(
                        price > 0 ? '₹${price.toStringAsFixed(0)}' : 'No price',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: price > 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    menu,
                    style: TextStyle(
                      fontSize: 14,
                      color: menu == 'No menu added yet'
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditMenu(day, meal),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Update Menu & Price'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}