import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final FirestoreService _firestoreService =
  FirestoreService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _attendance =
  [];

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _errorMessage =
          'Student is not logged in.';
          _isLoading = false;
        });

        return;
      }

      final data =
      await _firestoreService.getAll(
        'attendance',
      );

      final studentAttendance =
      data.where((item) {
        return item['studentId'] ==
            user.uid &&
            item['present'] == true;
      }).toList();

      studentAttendance.sort((a, b) {
        final dateA =
            a['date']?.toString() ?? '';

        final dateB =
            b['date']?.toString() ?? '';

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _attendance =
            studentAttendance;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Failed to load bill: $e';
        _isLoading = false;
      });
    }
  }

  double _getPrice(
      Map<String, dynamic> item,
      ) {
    final price = item['price'];

    if (price is num) {
      return price.toDouble();
    }

    return double.tryParse(
      price?.toString() ?? '',
    ) ??
        0;
  }

  double get _totalAmount {
    return _attendance.fold(
      0,
          (total, item) {
        return total + _getPrice(item);
      },
    );
  }

  String _formatDate(String date) {
    try {
      final dateTime =
      DateTime.parse(date);

      return '${dateTime.day.toString().padLeft(2, '0')}/'
          '${dateTime.month.toString().padLeft(2, '0')}/'
          '${dateTime.year}';
    } catch (_) {
      return date;
    }
  }

  String _formatMeal(String meal) {
    if (meal.isEmpty) {
      return 'Meal';
    }

    return meal[0].toUpperCase() +
        meal.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Bill',
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
          style: const TextStyle(
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_attendance.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBill,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            Center(
              child: Text(
                'No meals taken yet.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBill,
      child: ListView(
        padding:
        const EdgeInsets.all(20),
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 24,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding:
              const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  const Text(
                    'Total Bill',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Meal History',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ..._attendance.map(
                (item) {
              final date =
                  item['date']?.toString() ??
                      '';

              final meal =
                  item['meal']?.toString() ??
                      '';

              final menu =
                  item['menu']?.toString() ??
                      '';

              final price =
              _getPrice(item);

              return Card(
                margin:
                const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.restaurant,
                  ),
                  title: Text(
                    _formatMeal(meal),
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_formatDate(date)}\n'
                        '$menu',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '₹${price.toStringAsFixed(2)}',
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}