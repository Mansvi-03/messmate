class Mess {
  final String id;
  final String name;
  final String address;
  final String contactNumber;
  final String managerId;

  Mess({
    required this.id,
    required this.name,
    required this.address,
    required this.contactNumber,
    required this.managerId,
  });

  factory Mess.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return Mess(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      managerId: map['managerId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'contactNumber': contactNumber,
      'managerId': managerId,
    };
  }
}