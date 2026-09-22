class Student {
  final String id;
  final String name;
  final String email;
  final String contactNumber;
  final String college;
  final String hostel;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.contactNumber,
    required this.college,
    required this.hostel,
  });

  factory Student.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return Student(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      college: map['college'] ?? '',
      hostel: map['hostel'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'contactNumber': contactNumber,
      'college': college,
      'hostel': hostel,
      'role': 'student',
    };
  }
}