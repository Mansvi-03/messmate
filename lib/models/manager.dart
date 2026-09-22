class Manager {
  final String id;
  final String name;
  final String email;
  final String contactNumber;

  Manager({
    required this.id,
    required this.name,
    required this.email,
    required this.contactNumber,
  });

  factory Manager.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return Manager(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'contactNumber': contactNumber,
      'role': 'manager',
    };
  }
}