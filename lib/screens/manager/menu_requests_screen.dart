import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuRequestsScreen extends StatefulWidget {
  const MenuRequestsScreen({super.key});

  @override
  State<MenuRequestsScreen> createState() => _MenuRequestsScreenState();
}

class _MenuRequestsScreenState extends State<MenuRequestsScreen> {
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
  Map<String, List<Map<String, dynamic>>> _pendingRequests = {};
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
    final tomorrow = _currentDate.add(const Duration(days: 1));
    return _days[tomorrow.weekday - 1];
  }

  String _canonicalDay(String day) {
    if (day.trim().isEmpty) return day;
    return day.trim()[0].toUpperCase() + day.trim().substring(1).toLowerCase();
  }

  Future<void> _loadData() async {
    try {
      final menuData = await _firestoreService.getAll('menus');
      final Map<String, Map<String, dynamic>> loadedMenu = {};

      for (final item in menuData) {
        final day = item['day']?.toString();
        if (day != null && day.isNotEmpty) {
          loadedMenu[_canonicalDay(day)] = item;
        }
      }

      final requests = await _firestoreService.getAll('menu_change_requests');

      final Map<String, int> counts = {};
      final Map<String, List<Map<String, dynamic>>> requestsByMeal = {};

      for (final request in requests) {
        if (request['status'] != 'pending') {
          continue;
        }

        final day = request['day']?.toString();
        final meal = request['meal']?.toString();

        if (day == null || meal == null) {
          continue;
        }

        final key = '${_canonicalDay(day)}-${meal.toLowerCase()}';
        counts[key] = (counts[key] ?? 0) + 1;

        requestsByMeal.putIfAbsent(key, () => []).add(request);
      }

      if (!mounted) return;

      setState(() {
        _menu = loadedMenu;
        _requestCounts = counts;
        _pendingRequests = requestsByMeal;
        _currentDate = DateTime.now();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load menu requests: $e';
      });
    }
  }

  String _cleanMenuText(String text) {
    // Strip any trailing price tag like (₹180) that might have been saved in the text previously
    return text.replaceAll(RegExp(r'\s*\(₹[0-9]+(?:\.[0-9]+)?\)\s*$'), '').trim();
  }

  String _getMealMenu(String day, String meal) {
    final dayMenu = _menu[_canonicalDay(day)];
    if (dayMenu == null) {
      return 'No menu added yet';
    }

    final raw = dayMenu[meal.toLowerCase()];

    if (raw is Map) {
      final menu = raw['menu']?.toString().trim() ?? '';
      if (menu.isEmpty) return 'No menu added yet';
      return _cleanMenuText(menu);
    }

    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'No menu added yet';
    }

    return _cleanMenuText(value);
  }

  double _getMealPrice(String day, String meal) {
    final dayMenu = _menu[_canonicalDay(day)];
    if (dayMenu == null) return _defaultPrice(meal);

    final raw = dayMenu[meal.toLowerCase()];
    if (raw is Map) {
      final price = raw['price'];
      if (price is num && price > 0) return price.toDouble();
    }

    return _defaultPrice(meal);
  }

  double _defaultPrice(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return 40.0;
      case 'lunch':
        return 60.0;
      case 'dinner':
        return 50.0;
      default:
        return 50.0;
    }
  }

  int _getRequestCount(String day, String meal) {
    return _requestCounts['${_canonicalDay(day)}-${meal.toLowerCase()}'] ?? 0;
  }

  List<Map<String, dynamic>> _getMealRequests(String day, String meal) {
    return _pendingRequests['${_canonicalDay(day)}-${meal.toLowerCase()}'] ?? [];
  }

  Future<void> _openUpdateAndResolveDialog(String day, String meal) async {
    final currentMenu = _getMealMenu(day, meal);
    final currentPrice = _getMealPrice(day, meal);
    final requests = _getMealRequests(day, meal);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _UpdateMenuAndResolveDialog(
        day: _canonicalDay(day),
        meal: meal,
        initialMenu: currentMenu == 'No menu added yet' ? '' : currentMenu,
        initialPrice: currentPrice,
        requests: requests,
        onSave: (newMenu, newPrice) async {
          await _saveMenuAndResolve(day, meal, newMenu, newPrice);
        },
      ),
    );

    if (result == true && mounted) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$meal menu & price updated, and student requests marked as handled.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _saveMenuAndResolve(
    String day,
    String meal,
    String newMenu,
    double newPrice,
  ) async {
    final canonicalDay = _canonicalDay(day);

    final existingMenu = await _firestoreService.get('menus', canonicalDay);
    final Map<String, dynamic> updatedMenu = {};

    if (existingMenu != null) {
      updatedMenu.addAll(existingMenu);
    }

    updatedMenu['day'] = canonicalDay;
    updatedMenu[meal.toLowerCase()] = {
      'menu': newMenu.trim(),
      'price': newPrice,
    };

    await _firestoreService.add('menus', canonicalDay, updatedMenu);

    if (canonicalDay.toLowerCase() != canonicalDay) {
      try {
        await _firestoreService.delete('menus', canonicalDay.toLowerCase());
      } catch (_) {}
    }

    // Mark related requests as handled
    final requests = await _firestoreService.getAll('menu_change_requests');
    for (final request in requests) {
      if (request['status'] == 'pending' &&
          request['day']?.toString().toLowerCase() == day.toLowerCase() &&
          request['meal']?.toString().toLowerCase() == meal.toLowerCase()) {
        final docId = request['id']?.toString();
        if (docId != null && docId.isNotEmpty) {
          await _firestoreService.update(
            'menu_change_requests',
            docId,
            {'status': 'handled'},
          );
        }
      }
    }
  }

  IconData _getMealIcon(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Color _getMealColor(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return const Color(0xFFD97706);
      case 'lunch':
        return const Color(0xFF0284C7);
      case 'dinner':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Menu Change Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
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
        const SizedBox(height: 40),
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
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
    final currentPrice = _getMealPrice(day, meal);
    final requestCount = _getRequestCount(day, meal);
    final mealRequests = _getMealRequests(day, meal);
    final mealColor = _getMealColor(meal);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: requestCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: requestCount > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Meal Name, Price Tag, Request Badge
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${currentPrice.toStringAsFixed(0)} / meal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: requestCount > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: requestCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
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
                      requestCount == 1 ? '1 Request' : '$requestCount Requests',
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

          // Current Planned Dishes
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Student Requests Preview (if any)
          if (mealRequests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.feedback_outlined, size: 15, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Text(
                        'Student Suggestion${mealRequests.length > 1 ? 's' : ''}:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...mealRequests.take(2).map((req) {
                    final student = req['studentName'] ?? 'Student';
                    final text = req['request'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• "$text" — $student',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78350F),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openUpdateAndResolveDialog(day, meal),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Update Menu & Resolve Requests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DEDICATED UPDATE MENU & AMOUNT DIALOG
// ============================================================================
class _UpdateMenuAndResolveDialog extends StatefulWidget {
  final String day;
  final String meal;
  final String initialMenu;
  final double initialPrice;
  final List<Map<String, dynamic>> requests;
  final Future<void> Function(String newMenu, double newPrice) onSave;

  const _UpdateMenuAndResolveDialog({
    required this.day,
    required this.meal,
    required this.initialMenu,
    required this.initialPrice,
    required this.requests,
    required this.onSave,
  });

  @override
  State<_UpdateMenuAndResolveDialog> createState() => _UpdateMenuAndResolveDialogState();
}

class _UpdateMenuAndResolveDialogState extends State<_UpdateMenuAndResolveDialog> {
  late final TextEditingController _menuController;
  late final TextEditingController _priceController;
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _menuController = TextEditingController(text: widget.initialMenu);
    _priceController = TextEditingController(
      text: widget.initialPrice > 0 ? widget.initialPrice.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newMenu = _menuController.text.trim();
    final newPrice = double.tryParse(_priceController.text.trim()) ?? 0;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSave(newMenu, newPrice);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Failed to save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update ${widget.meal} Menu',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.day,
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Requests Info
              if (widget.requests.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Request (${widget.requests.length}):',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${widget.requests.first['request']}"',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78350F),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Text(
                  'Modify dishes and meal pricing to keep the mess schedule updated.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),

              const SizedBox(height: 12),

              // Menu Items Field
              TextFormField(
                controller: _menuController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Menu Dishes / Items *',
                  hintText: 'e.g. Dal Makhani, Paneer, Rice, Chapatis',
                  prefixIcon: Icon(Icons.restaurant_menu_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the menu items';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Meal Price / Amount Field
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price per meal (Amount) *',
                  hintText: 'e.g. 60',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the meal price';
                  }
                  final p = double.tryParse(value.trim());
                  if (p == null || p <= 0) {
                    return 'Please enter a valid price greater than 0';
                  }
                  return null;
                },
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save & Resolve Requests'),
        ),
      ],
    );
  }
}