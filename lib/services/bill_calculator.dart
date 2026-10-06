class StudentMealConsumption {
  final String date;
  final String day;
  final String meal; // 'breakfast', 'lunch', 'dinner'
  final String menu;
  final double price;

  const StudentMealConsumption({
    required this.date,
    required this.day,
    required this.meal,
    required this.menu,
    required this.price,
  });
}

class StudentBillSummary {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String billingPeriod;
  final String billingPeriodLabel;

  final int breakfastCount;
  final double breakfastUnitPrice;
  final double breakfastTotal;

  final int lunchCount;
  final double lunchUnitPrice;
  final double lunchTotal;

  final int dinnerCount;
  final double dinnerUnitPrice;
  final double dinnerTotal;

  final int totalMeals;
  final double totalBill;

  final String status; // 'paid' or 'unpaid'
  final List<StudentMealConsumption> consumptions;

  const StudentBillSummary({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.billingPeriod,
    required this.billingPeriodLabel,
    required this.breakfastCount,
    required this.breakfastUnitPrice,
    required this.breakfastTotal,
    required this.lunchCount,
    required this.lunchUnitPrice,
    required this.lunchTotal,
    required this.dinnerCount,
    required this.dinnerUnitPrice,
    required this.dinnerTotal,
    required this.totalMeals,
    required this.totalBill,
    required this.status,
    required this.consumptions,
  });

  StudentBillSummary copyWith({
    String? status,
  }) {
    return StudentBillSummary(
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      billingPeriod: billingPeriod,
      billingPeriodLabel: billingPeriodLabel,
      breakfastCount: breakfastCount,
      breakfastUnitPrice: breakfastUnitPrice,
      breakfastTotal: breakfastTotal,
      lunchCount: lunchCount,
      lunchUnitPrice: lunchUnitPrice,
      lunchTotal: lunchTotal,
      dinnerCount: dinnerCount,
      dinnerUnitPrice: dinnerUnitPrice,
      dinnerTotal: dinnerTotal,
      totalMeals: totalMeals,
      totalBill: totalBill,
      status: status ?? this.status,
      consumptions: consumptions,
    );
  }
}

class BillCalculator {
  static const List<String> monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static double extractNum(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) {
      return double.tryParse(val.toString().trim()) ?? 0;
    }
    return 0;
  }

  static String getMonthKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  static String getMonthLabel(String yearMonth) {
    if (yearMonth == 'all') {
      return 'All Periods';
    }
    final parts = yearMonth.split('-');
    if (parts.length >= 2) {
      final y = int.tryParse(parts[0]) ?? 2026;
      final m = int.tryParse(parts[1]) ?? 1;
      if (m >= 1 && m <= 12) {
        return '${monthNames[m]} $y';
      }
    }
    return yearMonth;
  }

  static List<Map<String, String>> getAvailableBillingPeriods(
    List<Map<String, dynamic>> attendanceList,
  ) {
    final Set<String> keys = {};

    final currentKey = getMonthKey(DateTime.now());
    keys.add(currentKey);

    for (final att in attendanceList) {
      final date = att['date']?.toString() ?? '';
      if (date.length >= 7) {
        final key = date.substring(0, 7);
        if (key.contains('-')) {
          keys.add(key);
        }
      }
    }

    final sortedKeys = keys.toList()..sort((a, b) => b.compareTo(a));

    final List<Map<String, String>> periods = [];
    for (final k in sortedKeys) {
      periods.add({
        'key': k,
        'label': getMonthLabel(k),
      });
    }

    periods.add({
      'key': 'all',
      'label': 'All Periods',
    });

    return periods;
  }

  static String normalizeMeal(String raw) {
    final m = raw.trim().toLowerCase();
    if (m.contains('break')) return 'breakfast';
    if (m.contains('dinn')) return 'dinner';
    return 'lunch';
  }

  static double getFallbackMealPrice(String meal) {
    switch (meal) {
      case 'breakfast':
        return 40.0;
      case 'dinner':
        return 50.0;
      case 'lunch':
      default:
        return 60.0;
    }
  }

  static StudentBillSummary calculateStudentBill({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> attendanceList,
    required List<Map<String, dynamic>> billsList,
    required Map<String, Map<String, dynamic>> menusByDay,
    required String billingPeriod,
  }) {
    final studentId = (student['id'] ?? student['studentId'] ?? student['uid'] ?? '').toString();
    final studentName = student['name']?.toString() ?? 'Student';
    final studentEmail = student['email']?.toString() ?? '';
    final periodLabel = getMonthLabel(billingPeriod);

    final matchingAttendance = attendanceList.where((item) {
      final itemStudentId = (item['studentId'] ?? item['student_id'] ?? item['userId'] ?? '').toString();
      if (itemStudentId != studentId) return false;
      if (item['present'] != true) return false;
      if (billingPeriod != 'all') {
        final date = item['date']?.toString() ?? '';
        if (!date.startsWith(billingPeriod)) return false;
      }
      return true;
    }).toList();

    // Sort chronologically
    matchingAttendance.sort((a, b) {
      final da = a['date']?.toString() ?? '';
      final db = b['date']?.toString() ?? '';
      return da.compareTo(db);
    });

    int bCount = 0;
    double bTotal = 0;
    int lCount = 0;
    double lTotal = 0;
    int dCount = 0;
    double dTotal = 0;

    final List<StudentMealConsumption> consumptions = [];

    for (final att in matchingAttendance) {
      final date = att['date']?.toString() ?? '';
      final rawMeal = att['meal']?.toString() ?? '';
      final meal = normalizeMeal(rawMeal);
      final day = att['day']?.toString() ?? '';

      double price = extractNum(att['price']);
      if (price <= 0) price = extractNum(att['amount']);

      String menu = att['menu']?.toString().trim() ?? '';

      if (price <= 0 || menu.isEmpty) {
        if (menusByDay.containsKey(day)) {
          final dayMenu = menusByDay[day]!;
          final mealData = dayMenu[meal];
          if (mealData is Map) {
            if (price <= 0) price = extractNum(mealData['price']);
            if (menu.isEmpty) menu = mealData['menu']?.toString().trim() ?? '';
          }
        }
      }

      if (price <= 0) {
        price = getFallbackMealPrice(meal);
      }
      if (menu.isEmpty) {
        menu = '${meal[0].toUpperCase()}${meal.substring(1)} meal';
      }

      consumptions.add(StudentMealConsumption(
        date: date,
        day: day,
        meal: meal,
        menu: menu,
        price: price,
      ));

      if (meal == 'breakfast') {
        bCount++;
        bTotal += price;
      } else if (meal == 'dinner') {
        dCount++;
        dTotal += price;
      } else {
        lCount++;
        lTotal += price;
      }
    }

    final double bUnitPrice = bCount > 0 ? (bTotal / bCount) : 0.0;
    final double lUnitPrice = lCount > 0 ? (lTotal / lCount) : 0.0;
    final double dUnitPrice = dCount > 0 ? (dTotal / dCount) : 0.0;

    final int totalMeals = bCount + lCount + dCount;
    final double totalBill = bTotal + lTotal + dTotal;

    // Determine status from bills collection
    String status = 'unpaid';

    final periodDocId = '${studentId}_$billingPeriod';
    for (final b in billsList) {
      final bStudentId = (b['studentId'] ?? b['student_id'] ?? '').toString();
      if (b['id'] == periodDocId ||
          (bStudentId == studentId &&
              b['period'] == billingPeriod &&
              b['period'] != null)) {
        final s = (b['status']?.toString() ?? '').toLowerCase();
        if (s == 'paid') {
          status = 'paid';
          break;
        }
      }
    }

    // Fallback: check legacy single-meal bills if no period bill found
    if (status == 'unpaid' && matchingAttendance.isNotEmpty) {
      int legacyPaidCount = 0;
      int legacyTotalCount = 0;
      for (final att in matchingAttendance) {
        final recId = att['id']?.toString() ?? '';
        for (final b in billsList) {
          final bStudentId = (b['studentId'] ?? b['student_id'] ?? '').toString();
          if (b['id'] == recId ||
              (bStudentId == studentId &&
                  b['date'] == att['date'] &&
                  b['meal'] == att['meal'])) {
            legacyTotalCount++;
            if ((b['status']?.toString() ?? '').toLowerCase() == 'paid') {
              legacyPaidCount++;
            }
          }
        }
      }
      if (legacyTotalCount > 0 && legacyPaidCount == legacyTotalCount) {
        status = 'paid';
      }
    }

    return StudentBillSummary(
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      billingPeriod: billingPeriod,
      billingPeriodLabel: periodLabel,
      breakfastCount: bCount,
      breakfastUnitPrice: bUnitPrice,
      breakfastTotal: bTotal,
      lunchCount: lCount,
      lunchUnitPrice: lUnitPrice,
      lunchTotal: lTotal,
      dinnerCount: dCount,
      dinnerUnitPrice: dUnitPrice,
      dinnerTotal: dTotal,
      totalMeals: totalMeals,
      totalBill: totalBill,
      status: status,
      consumptions: consumptions,
    );
  }

  static List<StudentBillSummary> calculateAllBills({
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> attendanceList,
    required List<Map<String, dynamic>> billsList,
    required List<Map<String, dynamic>> menusList,
    required String billingPeriod,
  }) {
    final Map<String, Map<String, dynamic>> menusByDay = {};
    for (final menu in menusList) {
      final day = menu['day']?.toString();
      if (day != null && day.isNotEmpty) {
        menusByDay[day] = menu;
      }
    }

    final List<StudentBillSummary> results = [];

    for (final student in students) {
      final summary = calculateStudentBill(
        student: student,
        attendanceList: attendanceList,
        billsList: billsList,
        menusByDay: menusByDay,
        billingPeriod: billingPeriod,
      );
      results.add(summary);
    }

    // Sort by name
    results.sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

    return results;
  }
}
