import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;

  // Stores all menus from Firestore.
  final Map<String, Map<String, dynamic>> _menus = {};

  // Stores whether the current student already has
  // a pending request for a particular day + meal.
  final Map<String, bool> _pendingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  // ------------------------------------------------------------
  // LOAD MENU AND STUDENT REQUESTS
  // ------------------------------------------------------------

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load menus
      final menuData = await _firestoreService.getAll('menus');

      _menus.clear();

      for (final menu in menuData) {
        final day = menu['day'];

        if (day != null) {
          _menus[day.toString()] = menu;
        }
      }

      // Load current student's requests
      final user = FirebaseAuth.instance.currentUser;

      _pendingRequests.clear();

      if (user != null) {
        final requests = await _firestoreService.getAll(
          'menu_change_requests',
        );

        for (final request in requests) {
          if (request['studentId'] == user.uid &&
              request['status'] == 'pending') {
            final day = request['day'];
            final meal = request['meal'];

            if (day != null && meal != null) {
              final key =
                  '${day.toString()}-${meal.toString().toLowerCase()}';

              _pendingRequests[key] = true;
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load menu: $e',
          ),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  // ------------------------------------------------------------
  // GET MEAL MENU
  // ------------------------------------------------------------

  String _getMealMenu(
      String day,
      String meal,
      ) {
    final dayMenu = _menus[day];

    if (dayMenu == null) {
      return 'No menu added';
    }

    final menu = dayMenu[meal.toLowerCase()];

    if (menu == null ||
        menu.toString().trim().isEmpty) {
      return 'No menu added';
    }

    return menu.toString();
  }

  // ------------------------------------------------------------
  // CHECK IF STUDENT ALREADY REQUESTED
  // ------------------------------------------------------------

  bool _hasPendingRequest(
      String day,
      String meal,
      ) {
    final key =
        '${day}-${meal.toLowerCase()}';

    return _pendingRequests[key] == true;
  }

  // ------------------------------------------------------------
  // REQUEST MENU CHANGE
  // ------------------------------------------------------------

  Future<void> _requestMenuChange(
      String day,
      String meal,
      ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please login first.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // CHECK IF REQUEST ALREADY EXISTS
    // ----------------------------------------------------------

    try {
      final requests = await _firestoreService.getAll(
        'menu_change_requests',
      );

      final alreadyRequested = requests.any(
            (request) {
          return request['studentId'] == user.uid &&
              request['day'] == day &&
              request['meal'] == meal &&
              request['status'] == 'pending';
        },
      );

      if (alreadyRequested) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have already requested a change for this menu.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // GET STUDENT INFORMATION
      // --------------------------------------------------------

      final studentData = await _firestoreService.get(
        'students',
        user.uid,
      );

      if (studentData == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Student profile not found.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // CREATE REQUEST
      // --------------------------------------------------------

      final requestId =
          '${user.uid}_${day}_$meal';

      await _firestoreService.add(
        'menu_change_requests',
        requestId,
        {
          'studentId': user.uid,
          'studentName': studentData['name'] ?? '',
          'day': day,
          'meal': meal,
          'currentMenu': _getMealMenu(
            day,
            meal,
          ),
          'createdAt':
          DateTime.now().toIso8601String(),
          'status': 'pending',
        },
      );

      // Mark this meal as having a pending request
      final key =
          '${day}-${meal.toLowerCase()}';

      _pendingRequests[key] = true;

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Menu change request submitted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit request: $e',
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // GET TODAY
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // GET TOMORROW
  // ------------------------------------------------------------

  String _getTomorrow() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final tomorrow =
    DateTime.now().add(
      const Duration(days: 1),
    );

    return days[tomorrow.weekday - 1];
  }

  // ------------------------------------------------------------
  // MENU CARD
  // ------------------------------------------------------------

  Widget _buildMenuCard({
    required String day,
    required String meal,
    required IconData icon,
  }) {
    final menu = _getMealMenu(
      day,
      meal,
    );

    final hasPendingRequest =
    _hasPendingRequest(
      day,
      meal,
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // MEAL NAME
            // --------------------------------------------------

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.orange,
                  ),
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

            const SizedBox(height: 16),

            // --------------------------------------------------
            // CURRENT MENU
            // --------------------------------------------------

            const Text(
              'Current Menu',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 6),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                14,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                menu,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // REQUEST BUTTON
            // --------------------------------------------------

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasPendingRequest
                    ? null
                    : () {
                  _requestMenuChange(
                    day,
                    meal,
                  );
                },
                icon: Icon(
                  hasPendingRequest
                      ? Icons.check
                      : Icons.edit,
                ),
                label: Text(
                  hasPendingRequest
                      ? 'Request Already Sent'
                      : 'Request Change',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final today = _getToday();
    final tomorrow = _getTomorrow();

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
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            // =================================================
            // TODAY
            // =================================================

            Text(
              'Today - $today',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // TODAY LUNCH
            _buildMenuCard(
              day: today,
              meal: 'Lunch',
              icon: Icons.lunch_dining,
            ),

            // TODAY DINNER
            _buildMenuCard(
              day: today,
              meal: 'Dinner',
              icon: Icons.dinner_dining,
            ),

            const SizedBox(height: 12),

            // =================================================
            // TOMORROW
            // =================================================

            Text(
              'Tomorrow - $tomorrow',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // TOMORROW BREAKFAST
            _buildMenuCard(
              day: tomorrow,
              meal: 'Breakfast',
              icon: Icons.free_breakfast,
            ),
          ],
        ),
      ),
    );
  }
}