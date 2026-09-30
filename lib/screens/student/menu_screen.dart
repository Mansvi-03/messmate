import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> _requestMenuChange(String meal) async {
    final user = FirebaseAuth.instance.currentUser;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final today = _getToday();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Request Menu Change ($meal)'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Suggested Menu / Request Details',
                    hintText: 'e.g. Please add Paneer Butter Masala',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your request details';
                    }
                    return null;
                  },
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
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          try {
                            String studentName = 'Student';
                            if (user != null) {
                              final sData = await _firestoreService.get('students', user.uid);
                              if (sData != null) {
                                studentName = sData['name'] ?? 'Student';
                              }
                            }

                            final id = DateTime.now().millisecondsSinceEpoch.toString();
                            await _firestoreService.add('menu_change_requests', id, {
                              'id': id,
                              'studentId': user?.uid ?? '',
                              'studentName': studentName,
                              'day': today,
                              'meal': meal,
                              'request': controller.text.trim(),
                              'status': 'pending',
                              'createdAt': DateTime.now().toIso8601String(),
                            });

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menu change request submitted to manager.'),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to submit request: $e'),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _buildMealCard(String meal) {
    final menu = _getMenu(meal);
    final price = _getPrice(meal);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontWeight: FontWeight.bold,
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

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _requestMenuChange(meal),
                icon: const Icon(Icons.edit_note),
                label: const Text('Request Menu Change'),
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