class Payment {
  final String id;
  final String billId;
  final String studentId;
  final double amount;
  final DateTime paymentDate;

  Payment({
    required this.id,
    required this.billId,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
  });

  factory Payment.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return Payment(
      id: id,
      billId: map['billId'] ?? '',
      studentId: map['studentId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentDate: DateTime.tryParse(
        map['paymentDate'] ?? '',
      ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'studentId': studentId,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
    };
  }
}