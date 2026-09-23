import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import 'menu_change_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
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

  Map<String, Map<String, dynamic>> _menu = {};

  List<Map<String, dynamic>> _polls = [];

  bool _isLoading = true;

  String? _errorMessage;

  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ----------------------------------------------------------
  // LOAD DATA
  // ----------------------------------------------------------

  Future<void> _loadData() async {
    try {
      final menuData =
      await _firestoreService.getAll('menus');

      final Map<String, Map<String, dynamic>>
      loadedMenu = {};

      for (final item in menuData) {
        final day = item['day']?.toString();

        if (day != null) {
          loadedMenu[day] = item;
        }
      }

      final pollData =
      await _firestoreService.getAll('menu_polls');

      final activePolls = pollData.where((poll) {
        return poll['status'] == 'active';
      }).toList();

      if (!mounted) return;

      setState(() {
        _menu = loadedMenu;
        _polls = activePolls;
        _currentDate = DateTime.now();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load menu.';
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------------
  // GET TODAY'S DAY
  // ----------------------------------------------------------

  String _getToday() {
    return _days[_currentDate.weekday - 1];
  }

  // ----------------------------------------------------------
  // GET MEAL MENU
  // ----------------------------------------------------------

  String _getMealMenu(
      String day,
      String meal,
      ) {
    final menu = _menu[day];

    if (menu == null) {
      return 'No menu added';
    }

    final value =
    menu[meal.toLowerCase()]
        ?.toString()
        .trim();

    if (value == null || value.isEmpty) {
      return 'No menu added';
    }

    return value;
  }

  // ----------------------------------------------------------
  // CHECK POLL EXPIRY
  // ----------------------------------------------------------

  bool _isPollExpired(
      Map<String, dynamic> poll,
      ) {
    final deadline =
    poll['deadline']?.toString();

    if (deadline == null) {
      return true;
    }

    try {
      return DateTime.now().isAfter(
        DateTime.parse(deadline),
      );
    } catch (e) {
      return true;
    }
  }

  // ----------------------------------------------------------
  // CURRENT USER
  // ----------------------------------------------------------

  String? _getCurrentUserId() {
    return FirebaseAuth
        .instance
        .currentUser
        ?.uid;
  }

  // ----------------------------------------------------------
  // CHECK VOTE
  // ----------------------------------------------------------

  Future<bool> _hasVoted(
      String pollId,
      ) async {
    final uid = _getCurrentUserId();

    if (uid == null) {
      return false;
    }

    final vote =
    await _firestoreService.get(
      'menu_polls/$pollId/votes',
      uid,
    );

    return vote != null;
  }

  // ----------------------------------------------------------
  // SAVE VOTE
  // ----------------------------------------------------------

  Future<void> _saveVote(
      String pollId,
      String option,
      ) async {
    final uid = _getCurrentUserId();

    if (uid == null) {
      if (!mounted) return;

      _showMessage(
        'Please login before voting.',
      );

      return;
    }

    try {
      final poll =
      await _firestoreService.get(
        'menu_polls',
        pollId,
      );

      if (poll == null) {
        return;
      }

      if (_isPollExpired(poll)) {
        if (!mounted) return;

        _showMessage(
          'Voting time has ended.',
        );

        return;
      }

      final existingVote =
      await _firestoreService.get(
        'menu_polls/$pollId/votes',
        uid,
      );

      if (existingVote != null) {
        if (!mounted) return;

        _showMessage(
          'You have already voted.',
        );

        return;
      }

      await _firestoreService.add(
        'menu_polls/$pollId/votes',
        uid,
        {
          'studentId': uid,
          'option': option,
          'votedAt':
          DateTime.now()
              .toIso8601String(),
        },
      );

      if (!mounted) return;

      _showMessage(
        'Your vote has been recorded.',
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to record vote.',
      );
    }
  }

  // ----------------------------------------------------------
  // SHOW POLL
  // ----------------------------------------------------------

  Future<void> _showPoll(
      Map<String, dynamic> poll,
      ) async {
    final pollId =
    poll['id'].toString();

    final hasVoted =
    await _hasVoted(pollId);

    if (!mounted) return;

    final expired =
    _isPollExpired(poll);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${poll['day']} - '
                '${poll['meal']}',
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Menu',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                poll['currentMenu'] ?? '',
              ),

              const SizedBox(height: 15),

              const Text(
                'Proposed Menu',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                poll['proposedMenu'] ?? '',
              ),

              const SizedBox(height: 15),

              if (expired)
                const Text(
                  'Voting has ended.',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                )
              else if (hasVoted)
                const Text(
                  'You have already voted.',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
            ],
          ),

          actions: [
            if (!expired && !hasVoted)
              TextButton(
                onPressed: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _saveVote(
                    pollId,
                    'current',
                  );
                },
                child: const Text(
                  'Keep Current',
                ),
              ),

            if (!expired && !hasVoted)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _saveVote(
                    pollId,
                    'proposed',
                  );
                },
                child: const Text(
                  'Change Menu',
                ),
              ),

            if (expired || hasVoted)
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'Close',
                ),
              ),
          ],
        );
      },
    );
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
    final today = _getToday();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Today\'s Menu',
        ),
      ),

      body: _buildBody(today),
    );
  }

  Widget _buildBody(
      String today,
      ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,

      child: ListView(
        padding:
        const EdgeInsets.all(16),

        children: [
          // --------------------------------------------------
          // TODAY'S DATE
          // --------------------------------------------------

          Card(
            child: Padding(
              padding:
              const EdgeInsets.all(16),

              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 28,
                  ),

                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        today,
                        style:
                        const TextStyle(
                          fontSize: 22,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${_currentDate.day.toString().padLeft(2, '0')}/'
                            '${_currentDate.month.toString().padLeft(2, '0')}/'
                            '${_currentDate.year}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --------------------------------------------------
          // TODAY'S MEALS
          // --------------------------------------------------

          const Text(
            'Today\'s Meals',
            style: TextStyle(
              fontSize: 24,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ..._meals.map(
                (meal) {
              final menu =
              _getMealMenu(
                today,
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
                    CrossAxisAlignment.start,

                    children: [
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
                              FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        menu,
                        style:
                        const TextStyle(
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Align(
                        alignment:
                        Alignment.centerRight,

                        child:
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                    MenuChangeScreen(
                                      day: today,
                                      meal: meal,
                                      currentMenu:
                                      menu,
                                    ),
                              ),
                            );
                          },

                          icon: const Icon(
                            Icons
                                .change_circle,
                          ),

                          label: const Text(
                            'Suggest Change',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // --------------------------------------------------
          // ACTIVE POLLS FOR TODAY
          // --------------------------------------------------

          const SizedBox(height: 10),

          ..._buildTodayPolls(today),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // ONLY SHOW TODAY'S POLLS
  // ----------------------------------------------------------

  List<Widget> _buildTodayPolls(
      String today,
      ) {
    final todayPolls =
    _polls.where((poll) {
      return poll['day'] == today;
    }).toList();

    if (todayPolls.isEmpty) {
      return [];
    }

    return [
      const SizedBox(height: 10),

      const Text(
        'Active Menu Polls',
        style: TextStyle(
          fontSize: 22,
          fontWeight:
          FontWeight.bold,
        ),
      ),

      const SizedBox(height: 10),

      ...todayPolls.map(
            (poll) {
          return Card(
            child: ListTile(
              leading: const Icon(
                Icons.how_to_vote,
              ),

              title: Text(
                '${poll['day']} - '
                    '${poll['meal']}',
              ),

              subtitle:
              const Text(
                'Vote on proposed menu change',
              ),

              trailing:
              const Icon(
                Icons.arrow_forward_ios,
              ),

              onTap: () {
                _showPoll(poll);
              },
            ),
          );
        },
      ),
    ];
  }
}