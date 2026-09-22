enum BillStatus {
  unpaid,
  partial,
  paid,
}

class Bill {
  final String id;
  final String studentId;
  final String month;

  final double breakfastAmount;
  final double lunchAmount;
  final double dinnerAmount;

  final double totalAmount;
  final double paidAmount;

  final BillStatus status;

  Bill({
    required this.id,
    required this.studentId,
    required this.month,
    required this.breakfastAmount,
    required this.lunchAmount,
    required this.dinnerAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
  });

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
      breakfastAmount:
      (map['breakfastAmount'] ?? 0).toDouble(),
      lunchAmount:
      (map['lunchAmount'] ?? 0).toDouble(),
      dinnerAmount:
      (map['dinnerAmount'] ?? 0).toDouble(),
      totalAmount:
      (map['totalAmount'] ?? 0).toDouble(),
      paidAmount:
      (map['paidAmount'] ?? 0).toDouble(),
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
      'breakfastAmount': breakfastAmount,
      'lunchAmount': lunchAmount,
      'dinnerAmount': dinnerAmount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'status': status.name,
    };
  }
}