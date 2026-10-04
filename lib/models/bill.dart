enum BillStatus {
  unpaid,
  partial,
  paid,
}

class Bill {
  final String id;
  final String studentId;
  final String month;

  final int breakfastCount;
  final double breakfastAmount;

  final int lunchCount;
  final double lunchAmount;

  final int dinnerCount;
  final double dinnerAmount;

  final double totalAmount;
  final double paidAmount;

  final BillStatus status;

  Bill({
    required this.id,
    required this.studentId,
    required this.month,
    this.breakfastCount = 0,
    required this.breakfastAmount,
    this.lunchCount = 0,
    required this.lunchAmount,
    this.dinnerCount = 0,
    required this.dinnerAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
  });

  int get totalMeals => breakfastCount + lunchCount + dinnerCount;

  double get remainingAmount {
    return totalAmount - paidAmount;
  }

  factory Bill.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return Bill(
      id: id,
      studentId: map['studentId'] ?? '',
      month: map['month'] ?? '',
      breakfastCount: (map['breakfastCount'] ?? 0) is num
          ? (map['breakfastCount'] as num).toInt()
          : 0,
      breakfastAmount: (map['breakfastAmount'] ?? 0).toDouble(),
      lunchCount: (map['lunchCount'] ?? 0) is num
          ? (map['lunchCount'] as num).toInt()
          : 0,
      lunchAmount: (map['lunchAmount'] ?? 0).toDouble(),
      dinnerCount: (map['dinnerCount'] ?? 0) is num
          ? (map['dinnerCount'] as num).toInt()
          : 0,
      dinnerAmount: (map['dinnerAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      status: BillStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => BillStatus.unpaid,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'month': month,
      'breakfastCount': breakfastCount,
      'breakfastAmount': breakfastAmount,
      'lunchCount': lunchCount,
      'lunchAmount': lunchAmount,
      'dinnerCount': dinnerCount,
      'dinnerAmount': dinnerAmount,
      'totalMeals': totalMeals,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'status': status.name,
    };
  }
}