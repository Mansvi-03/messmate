import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuRequestsScreen extends StatefulWidget {
  const MenuRequestsScreen({super.key});

  @override
  State<MenuRequestsScreen> createState() =>
      _MenuRequestsScreenState();
}

class _MenuRequestsScreenState
    extends State<MenuRequestsScreen> {
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

  Map<String, int> _requestCounts = {};
  Map<String, Map<String, dynamic>> _menu = {};
  DateTime _currentDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData() async {
    try {
      final menuData = await _firestoreService.getAll('menus');
      final Map<String, Map<String, dynamic>> loadedMenu = {};

      for (final item in menuData) {
        final day = item['day']?.toString();
        if (day != null && day.isNotEmpty) {
          loadedMenu[day] = item;
        }
      }

      final requests = await _firestoreService.getAll(
        'menu_change_requests',
      );

      final Map<String, int> counts = {};

      for (final request in requests) {
        if (request['status'] != 'pending') {
          continue;
        }

        final day = request['day']?.toString();
        final meal = request['meal']?.toString();

        if (day == null || meal == null) {
          continue;
        }

        final key = '$day-$meal';
        counts[key] = (counts[key] ?? 0) + 1;
      }

      if (!mounted) return;

      setState(() {
        _menu = loadedMenu;
        _requestCounts = counts;
        _currentDate = DateTime.now();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load menu requests.';
      });
    }
  }

  String _getMealMenu(
    String day,
    String meal,
  ) {
    final dayMenu = _menu[day];

    if (dayMenu == null) {
      return 'No menu added yet';
    }

    final raw = dayMenu[meal.toLowerCase()];

    if (raw is Map) {
      final menu = raw['menu']?.toString().trim() ?? '';
      final price = raw['price'];
      if (menu.isEmpty) return 'No menu added yet';
      if (price != null && price != 0) {
        return '$menu (₹$price)';
      }
      return menu;
    }

    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'No menu added yet';
    }

    return value;
  }

  int _getRequestCount(
    String day,
    String meal,
  ) {
    return _requestCounts['$day-$meal'] ?? 0;
  }

  Future<void> _changeMenu(
    String day,
    String meal,
  ) async {
    final currentMenu = _getMealMenu(
      day,
      meal,
    );

    final controller = TextEditingController(
      text: currentMenu == 'No menu added yet' ? '' : currentMenu,
    );

    final formKey = GlobalKey<FormState>();

    final newMenu = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Update $meal Menu',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address student suggestions for $day $meal by updating the menu.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: controller,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'New Menu Items',
                        hintText: 'Enter new dishes...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the menu';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.pop(
                      context,
                      controller.text.trim(),
                    );
                  },
                  child: const Text('Save & Resolve Requests'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (newMenu == null || newMenu.trim().isEmpty) {
      return;
    }

    await _saveMenu(
      day,
      meal,
      newMenu.trim(),
    );
  }

  Future<void> _saveMenu(
    String day,
    String meal,
    String newMenu,
  ) async {
    try {
      final existingMenu = await _firestoreService.get(
        'menus',
        day,
      );

      final Map<String, dynamic> updatedMenu = {};

      if (existingMenu != null) {
        updatedMenu.addAll(existingMenu);
      }

      final canonicalDay = day.trim().isEmpty
          ? day
          : day.trim()[0].toUpperCase() + day.trim().substring(1).toLowerCase();

      updatedMenu['day'] = canonicalDay;

      final existingMealData = updatedMenu[meal.toLowerCase()];
      double existingPrice = 0;
      if (existingMealData is Map) {
        final p = existingMealData['price'];
        if (p is num) existingPrice = p.toDouble();
      }
      if (existingPrice <= 0) {
        existingPrice = meal.toLowerCase() == 'breakfast'
            ? 40.0
            : (meal.toLowerCase() == 'lunch' ? 60.0 : 50.0);
      }

      updatedMenu[meal.toLowerCase()] = {
        'menu': newMenu.trim(),
        'price': existingPrice,
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

      // Mark related requests as handled
      final requests = await _firestoreService.getAll(
        'menu_change_requests',
      );

      for (final request in requests) {
        if (request['status'] == 'pending' &&
            request['day'] == day &&
            request['meal'] == meal) {
          await _firestoreService.update(
            'menu_change_requests',
            request['id'],
            {
              'status': 'handled',
            },
          );
        }
      }

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$meal menu updated and student requests marked as handled.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update menu.'),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Change Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildBody(),
                ),
    );
  }

  Widget _buildBody() {
    final today = _getToday();
    final tomorrow = _getTomorrow();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      children: [
        _buildDaySection(
          title: 'Today',
          day: today,
          date: _currentDate,
          meals: const ['Lunch', 'Dinner'],
        ),
        const SizedBox(height: 24),
        _buildDaySection(
          title: 'Tomorrow',
          day: tomorrow,
          date: _currentDate.add(const Duration(days: 1)),
          meals: const ['Breakfast'],
        ),
      ],
    );
  }

  Widget _buildDaySection({
    required String title,
    required String day,
    required DateTime date,
    required List<String> meals,
  }) {
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              dateStr,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        ...meals.map((meal) => _buildMealCard(day: day, meal: meal)),
      ],
    );
  }

  Widget _buildMealCard({
    required String day,
    required String meal,
  }) {
    final currentMenu = _getMealMenu(day, meal);
    final requestCount = _getRequestCount(day, meal);
    final mealColor = _getMealColor(meal);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Meal Title + Request Count Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: mealColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getMealIcon(meal), color: mealColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    meal,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: requestCount > 0
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: requestCount > 0
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      requestCount > 0
                          ? Icons.mark_chat_unread_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: requestCount > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      requestCount == 1
                          ? '1 Request'
                          : '$requestCount Requests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: requestCount > 0
                            ? const Color(0xFF92400E)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Current Menu Label & Box
          const Text(
            'Current Planned Menu',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              currentMenu,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _changeMenu(day, meal),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Update Menu & Resolve Requests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}