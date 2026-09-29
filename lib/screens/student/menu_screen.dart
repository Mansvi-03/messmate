import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FirestoreService _firestoreService =
  FirestoreService();

  bool _isLoading = true;

  Map<String, dynamic>? _todayMenu;

  final List<String> _meals = [
    'Breakfast',
    'Lunch',
    'Dinner',
  ];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  String _getToday() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days[DateTime.now().weekday - 1];
  }

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final today = _getToday();

      final menu =
      await _firestoreService.get(
        'menus',
        today,
      );

      if (!mounted) return;

      setState(() {
        _todayMenu = menu;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load menu: $e',
          ),
        ),
      );
    }
  }

  Map<String, dynamic>? _getMealData(
      String meal,
      ) {
    if (_todayMenu == null) {
      return null;
    }

    final value =
    _todayMenu![meal.toLowerCase()];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    // Old menu format support.
    if (value != null) {
      return {
        'menu': value.toString(),
        'price': 0,
      };
    }

    return null;
  }

  String _getMenu(String meal) {
    final data = _getMealData(meal);

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

  double _getPrice(String meal) {
    final data = _getMealData(meal);

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

  Widget _buildMealCard(String meal) {
    final menu = _getMenu(meal);
    final price = _getPrice(meal);

    return Card(
      margin:
      const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 12),
                Text(
                  meal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              menu,
              style: const TextStyle(
                fontSize: 17,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              price > 0
                  ? 'Price: ₹${price.toStringAsFixed(2)}'
                  : 'Price not available',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _getToday();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mess Menu',
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadMenu,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.all(16),
          children: [
            Text(
              'Today - $today',
              style: const TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            ..._meals.map(
              _buildMealCard,
            ),
          ],
        ),
      ),
    );
  }
}