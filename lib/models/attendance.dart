class Attendance {
  final String id;
  final String studentId;
  final DateTime date;

  final bool breakfast;
  final bool lunch;
  final bool dinner;

  Attendance({
    required this.id,
    required this.studentId,
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  factory Attendance.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return Attendance(
      id: id,
      studentId: map['studentId'] ?? '',
      date: DateTime.tryParse(
        map['date'] ?? '',
      ) ??
          DateTime.now(),
      breakfast: map['breakfast'] ?? false,
      lunch: map['lunch'] ?? false,
      dinner: map['dinner'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'date': date.toIso8601String(),
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
    };
  }
}