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

  Map<String, int> _requestCounts = {};

  Map<String, Map<String, dynamic>> _menu = {};

  DateTime _currentDate = DateTime.now();

  bool _isLoading = true;

  String? _errorMessage;

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // ----------------------------------------------------------
  // TODAY
  // ----------------------------------------------------------

  String _getToday() {
    return _days[_currentDate.weekday - 1];
  }

  // ----------------------------------------------------------
  // TOMORROW
  // ----------------------------------------------------------

  String _getTomorrow() {
    final tomorrow =
    _currentDate.add(
      const Duration(days: 1),
    );

    return _days[tomorrow.weekday - 1];
  }

  // ----------------------------------------------------------
  // LOAD DATA
  // ----------------------------------------------------------

  Future<void> _loadData() async {
    try {
      // ------------------------------------------------------
      // LOAD MENUS
      // ------------------------------------------------------

      final menuData =
      await _firestoreService.getAll(
        'menus',
      );

      final Map<String,
          Map<String, dynamic>>
      loadedMenu = {};

      for (final item in menuData) {
        final day =
        item['day']?.toString();

        if (day != null &&
            day.isNotEmpty) {
          loadedMenu[day] = item;
        }
      }

      // ------------------------------------------------------
      // LOAD REQUESTS
      // ------------------------------------------------------

      final requests =
      await _firestoreService.getAll(
        'menu_change_requests',
      );

      final Map<String, int> counts = {};

      for (final request in requests) {
        if (request['status'] != 'pending') {
          continue;
        }

        final day =
        request['day']?.toString();

        final meal =
        request['meal']?.toString();

        if (day == null ||
            meal == null) {
          continue;
        }

        final key =
            '$day-$meal';

        counts[key] =
            (counts[key] ?? 0) + 1;
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
        _errorMessage =
        'Failed to load menu requests.';
      });
    }
  }

  // ----------------------------------------------------------
  // GET CURRENT MENU
  // ----------------------------------------------------------

  String _getMealMenu(
      String day,
      String meal,
      ) {
    final dayMenu =
    _menu[day];

    if (dayMenu == null) {
      return 'No menu added';
    }

    final value =
    dayMenu[
    meal.toLowerCase()
    ]
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'No menu added';
    }

    return value;
  }

  // ----------------------------------------------------------
  // GET REQUEST COUNT
  // ----------------------------------------------------------

  int _getRequestCount(
      String day,
      String meal,
      ) {
    return _requestCounts[
    '$day-$meal'] ??
        0;
  }

  // ----------------------------------------------------------
  // CHANGE MENU
  // ----------------------------------------------------------

  Future<void> _changeMenu(
      String day,
      String meal,
      ) async {
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

    final formKey =
    GlobalKey<FormState>();

    final newMenu =
    await showDialog<String>(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: Text(
                'Change $meal Menu',
              ),

              content:
              Form(
                key: formKey,

                child:
                TextFormField(
                  controller:
                  controller,

                  maxLines: 4,

                  decoration:
                  const InputDecoration(
                    labelText:
                    'Menu',

                    hintText:
                    'Enter new menu',

                    border:
                    OutlineInputBorder(),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter menu';
                    }

                    return null;
                  },
                ),
              ),

              actions: [
                TextButton(
                  onPressed:
                  isSaving
                      ? null
                      : () {
                    Navigator.pop(
                      context,
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
                      : () {
                    if (!formKey
                        .currentState!
                        .validate()) {
                      return;
                    }

                    Navigator.pop(
                      context,
                      controller.text
                          .trim(),
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

    controller.dispose();

    if (newMenu == null ||
        newMenu.trim().isEmpty) {
      return;
    }

    await _saveMenu(
      day,
      meal,
      newMenu.trim(),
    );
  }

  // ----------------------------------------------------------
  // SAVE MENU
  // ----------------------------------------------------------

  Future<void> _saveMenu(
      String day,
      String meal,
      String newMenu,
      ) async {
    try {
      final existingMenu =
      await _firestoreService.get(
        'menus',
        day,
      );

      final Map<String, dynamic>
      updatedMenu = {};

      if (existingMenu != null) {
        updatedMenu.addAll(
          existingMenu,
        );
      }

      updatedMenu['day'] =
          day;

      updatedMenu[
      meal.toLowerCase()] =
          newMenu;

      // ------------------------------------------------------
      // UPDATE ACTUAL MENU
      // ------------------------------------------------------

      await _firestoreService.add(
        'menus',
        day,
        updatedMenu,
      );

      // ------------------------------------------------------
      // MARK RELATED REQUESTS AS HANDLED
      // ------------------------------------------------------

      final requests =
      await _firestoreService.getAll(
        'menu_change_requests',
      );

      for (final request in requests) {
        if (request['status'] ==
            'pending' &&
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

      // ------------------------------------------------------
      // RELOAD
      // ------------------------------------------------------

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$meal menu updated successfully.',
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
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu Change Requests',
        ),
      ),

      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  // ----------------------------------------------------------
  // BODY
  // ----------------------------------------------------------

  Widget _buildBody() {
    final today =
    _getToday();

    final tomorrow =
    _getTomorrow();

    return ListView(
      padding:
      const EdgeInsets.all(16),

      children: [
        // ====================================================
        // TODAY
        // ====================================================

        _buildDaySection(
          title: 'Today',
          day: today,
          date: _currentDate,
          meals: const [
            'Lunch',
            'Dinner',
          ],
        ),

        const SizedBox(
          height: 25,
        ),

        // ====================================================
        // TOMORROW
        // ====================================================

        _buildDaySection(
          title: 'Tomorrow',
          day: tomorrow,
          date: _currentDate.add(
            const Duration(days: 1),
          ),
          meals: const [
            'Breakfast',
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // DAY SECTION
  // ----------------------------------------------------------

  Widget _buildDaySection({
    required String title,
    required String day,
    required DateTime date,
    required List<String> meals,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 18,
            ),

            const SizedBox(
              width: 8,
            ),

            Text(
              '$day • '
                  '${date.day.toString().padLeft(2, '0')}/'
                  '${date.month.toString().padLeft(2, '0')}/'
                  '${date.year}',
              style:
              const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        ...meals.map(
              (meal) {
            return _buildMealCard(
              day: day,
              meal: meal,
            );
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // MEAL CARD
  // ----------------------------------------------------------

  Widget _buildMealCard({
    required String day,
    required String meal,
  }) {
    final currentMenu =
    _getMealMenu(
      day,
      meal,
    );

    final requestCount =
    _getRequestCount(
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
            // ------------------------------------------------
            // MEAL
            // ------------------------------------------------

            Row(
              children: [
                _getMealIcon(meal),

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

            const SizedBox(
              height: 15,
            ),

            // ------------------------------------------------
            // CURRENT MENU
            // ------------------------------------------------

            const Text(
              'Current Menu',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 15,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Container(
              width: double.infinity,

              padding:
              const EdgeInsets.all(
                12,
              ),

              decoration:
              BoxDecoration(
                border: Border.all(
                  color:
                  Colors.grey,
                ),
                borderRadius:
                BorderRadius.circular(
                  8,
                ),
              ),

              child: Text(
                currentMenu,
                style:
                const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ------------------------------------------------
            // REQUEST COUNT
            // ------------------------------------------------

            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 22,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  requestCount == 1
                      ? '1 Change Request'
                      : '$requestCount Change Requests',

                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            // ------------------------------------------------
            // CHANGE MENU BUTTON
            // ------------------------------------------------

            SizedBox(
              width: double.infinity,

              child:
              ElevatedButton.icon(
                onPressed: () {
                  _changeMenu(
                    day,
                    meal,
                  );
                },

                icon: const Icon(
                  Icons.edit,
                ),

                label:
                const Text(
                  'Change Menu',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // ICON
  // ----------------------------------------------------------

  Widget _getMealIcon(
      String meal,
      ) {
    switch (meal) {
      case 'Breakfast':
        return const Icon(
          Icons.free_breakfast,
          size: 30,
        );

      case 'Lunch':
        return const Icon(
          Icons.lunch_dining,
          size: 30,
        );

      case 'Dinner':
        return const Icon(
          Icons.dinner_dining,
          size: 30,
        );

      default:
        return const Icon(
          Icons.restaurant,
          size: 30,
        );
    }
  }
}