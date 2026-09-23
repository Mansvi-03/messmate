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

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _polls = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final requests =
      await _firestoreService.getAll(
        'menu_change_requests',
      );

      final polls =
      await _firestoreService.getAll(
        'menu_polls',
      );

      if (!mounted) return;

      setState(() {
        _requests = requests
            .where(
              (item) =>
          item['status'] == 'pending',
        )
            .toList();

        _polls = polls;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectRequest(
      String requestId,
      ) async {
    try {
      await _firestoreService.update(
        'menu_change_requests',
        requestId,
        {
          'status': 'rejected',
        },
      );

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Request rejected.',
          ),
        ),
      );
    } catch (e) {
      _showError();
    }
  }

  Future<void> _createPoll(
      Map<String, dynamic> request,
      ) async {
    final controller =
    TextEditingController(text: '6');

    final hours = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Create Voting Poll',
          ),
          content: TextField(
            controller: controller,
            keyboardType:
            TextInputType.number,
            decoration:
            const InputDecoration(
              labelText:
              'Voting duration in hours',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                int.tryParse(
                  controller.text.trim(),
                );

                if (value == null ||
                    value <= 0) {
                  return;
                }

                Navigator.pop(
                  context,
                  value,
                );
              },
              child: const Text(
                'Create Poll',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (hours == null) {
      return;
    }

    try {
      final now = DateTime.now();

      final deadline =
      now.add(
        Duration(hours: hours),
      );

      final pollId =
      DateTime.now()
          .millisecondsSinceEpoch
          .toString();

      await _firestoreService.add(
        'menu_polls',
        pollId,
        {
          'requestId':
          request['id'],
          'day':
          request['day'],
          'meal':
          request['meal'],
          'currentMenu':
          request['currentMenu'],
          'proposedMenu':
          request['proposedMenu'],
          'createdAt':
          now.toIso8601String(),
          'deadline':
          deadline.toIso8601String(),
          'status': 'active',
        },
      );

      await _firestoreService.update(
        'menu_change_requests',
        request['id'],
        {
          'status': 'poll_created',
        },
      );

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Poll created successfully.',
          ),
        ),
      );
    } catch (e) {
      _showError();
    }
  }

  Future<Map<String, int>> _getVoteCounts(
      String pollId,
      ) async {
    final votes =
    await _firestoreService.getAll(
      'menu_polls/$pollId/votes',
    );

    int currentVotes = 0;
    int proposedVotes = 0;

    for (final vote in votes) {
      if (vote['option'] == 'current') {
        currentVotes++;
      } else if (vote['option'] ==
          'proposed') {
        proposedVotes++;
      }
    }

    return {
      'current': currentVotes,
      'proposed': proposedVotes,
    };
  }

  bool _isExpired(
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

  Future<void> _applyProposedMenu(
      Map<String, dynamic> poll,
      ) async {
    try {
      final day =
      poll['day'].toString();

      await _firestoreService.add(
        'menus',
        day.toLowerCase(),
        {
          'day': day,
          'items':
          poll['proposedMenu'],
        },
      );

      await _firestoreService.update(
        'menu_polls',
        poll['id'],
        {
          'status': 'applied',
          'result': 'proposed',
        },
      );

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Proposed menu applied successfully.',
          ),
        ),
      );
    } catch (e) {
      _showError();
    }
  }

  Future<void> _keepCurrentMenu(
      Map<String, dynamic> poll,
      ) async {
    try {
      await _firestoreService.update(
        'menu_polls',
        poll['id'],
        {
          'status': 'closed',
          'result': 'current',
        },
      );

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Current menu kept.',
          ),
        ),
      );
    } catch (e) {
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Something went wrong.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            _requestsSection(),
            const SizedBox(height: 25),
            _pollsSection(),
          ],
        ),
      ),
    );
  }

  Widget _requestsSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Student Suggestions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        if (_requests.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No pending suggestions.',
              ),
            ),
          ),

        ..._requests.map(
              (request) => Card(
            margin:
            const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding:
              const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    request['studentName'] ??
                        'Student',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${request['day']} - '
                        '${request['meal']}',
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Current Menu',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    request['currentMenu'] ??
                        '',
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Proposed Menu',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    request['proposedMenu'] ??
                        '',
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Reason',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    request['reason'] ??
                        '',
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _rejectRequest(
                              request['id'],
                            );
                          },
                          child:
                          const Text(
                            'Reject',
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child:
                        ElevatedButton(
                          onPressed: () {
                            _createPoll(
                              request,
                            );
                          },
                          child:
                          const Text(
                            'Create Poll',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pollsSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Polls',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        if (_polls.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No menu polls found.',
              ),
            ),
          ),

        ..._polls.map(
              (poll) => _pollCard(poll),
        ),
      ],
    );
  }

  Widget _pollCard(
      Map<String, dynamic> poll,
      ) {
    return FutureBuilder<
        Map<String, int>>(
      future: _getVoteCounts(
        poll['id'].toString(),
      ),
      builder: (context, snapshot) {
        final counts =
            snapshot.data ??
                {
                  'current': 0,
                  'proposed': 0,
                };

        final currentVotes =
            counts['current'] ?? 0;

        final proposedVotes =
            counts['proposed'] ?? 0;

        final expired =
        _isExpired(poll);

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
                Text(
                  '${poll['day']} - '
                      '${poll['meal']}',
                  style:
                  const TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Current: '
                      '${poll['currentMenu']}',
                ),

                const SizedBox(height: 8),

                Text(
                  'Proposed: '
                      '${poll['proposedMenu']}',
                ),

                const SizedBox(height: 15),

                Text(
                  'Keep Current: '
                      '$currentVotes votes',
                ),

                Text(
                  'Change Menu: '
                      '$proposedVotes votes',
                ),

                const SizedBox(height: 10),

                Text(
                  expired
                      ? 'Voting ended'
                      : 'Voting is active',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: expired
                        ? Colors.red
                        : Colors.green,
                  ),
                ),

                if (expired &&
                    poll['status'] ==
                        'active') ...[
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child:
                        OutlinedButton(
                          onPressed: () {
                            _keepCurrentMenu(
                              poll,
                            );
                          },
                          child:
                          const Text(
                            'Keep Current',
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child:
                        ElevatedButton(
                          onPressed:
                          proposedVotes >
                              currentVotes
                              ? () {
                            _applyProposedMenu(
                              poll,
                            );
                          }
                              : null,
                          child:
                          const Text(
                            'Apply Proposed',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}