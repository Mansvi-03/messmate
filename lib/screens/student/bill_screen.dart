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

      final allBills = await _firestoreService.getAll('bills');
      final allMenus = await _firestoreService.getAll('menus');

      final Map<String, Map<String, dynamic>> menuByDay = {};
      for (final menu in allMenus) {
        final day = menu['day']?.toString();
        if (day != null && day.isNotEmpty) {
          menuByDay[day] = menu;
        }
      }

      final studentAttendance = data.where((item) {
        return item['studentId'] == user.uid && item['present'] == true;
      }).map((item) {
        final Map<String, dynamic> enrichedItem = Map.from(item);

        double price = _extractNum(enrichedItem['price']);
        if (price <= 0) {
          price = _extractNum(enrichedItem['amount']);
        }

        // Try matching in bills collection
        if (price <= 0) {
          for (final bill in allBills) {
            if (bill['studentId'] == user.uid &&
                (bill['id'] == enrichedItem['id'] ||
                    (bill['date'] == enrichedItem['date'] &&
                        bill['meal'] == enrichedItem['meal']))) {
              price = _extractNum(bill['amount']);
              if (price <= 0) price = _extractNum(bill['price']);
              if (price > 0) break;
            }
          }
        }

        // Try matching in menus collection
        final mealKey = (enrichedItem['meal']?.toString() ?? 'lunch').toLowerCase();
        String dayName = enrichedItem['day']?.toString() ?? '';
        if (dayName.isEmpty && enrichedItem['date'] != null) {
          try {
            final dt = DateTime.parse(enrichedItem['date'].toString());
            const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
            dayName = days[dt.weekday - 1];
          } catch (_) {}
        }

        if (menuByDay.containsKey(dayName)) {
          final dayMenu = menuByDay[dayName]!;
          final mealData = dayMenu[mealKey];
          if (mealData is Map) {
            if (price <= 0) {
              price = _extractNum(mealData['price']);
            }
            if (enrichedItem['menu'] == null || enrichedItem['menu'].toString().isEmpty) {
              enrichedItem['menu'] = mealData['menu']?.toString();
            }
          }
        }

        // Default fallback price if menu price was not set
        if (price <= 0) {
          price = 60.0;
        }

        enrichedItem['price'] = price;
        return enrichedItem;
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

  static double _extractNum(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) {
      return double.tryParse(val.toString().trim()) ?? 0;
    }
    return 0;
  }

  double _getPrice(
      Map<String, dynamic> item,
      ) {
    return _extractNum(item['price']);
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