class Menu {
  final String id;
  final DateTime date;

  final List<String> breakfastDishes;
  final double breakfastPrice;

  final List<String> lunchDishes;
  final double lunchPrice;

  final List<String> dinnerDishes;
  final double dinnerPrice;

  Menu({
    required this.id,
    required this.date,
    required this.breakfastDishes,
    required this.breakfastPrice,
    required this.lunchDishes,
    required this.lunchPrice,
    required this.dinnerDishes,
    required this.dinnerPrice,
  });

  factory Menu.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return Menu(
      id: id,
      date: DateTime.tryParse(
        map['date'] ?? '',
      ) ??
          DateTime.now(),
      breakfastDishes: List<String>.from(
        map['breakfastDishes'] ?? [],
      ),
      breakfastPrice:
      (map['breakfastPrice'] ?? 0).toDouble(),
      lunchDishes: List<String>.from(
        map['lunchDishes'] ?? [],
      ),
      lunchPrice:
      (map['lunchPrice'] ?? 0).toDouble(),
      dinnerDishes: List<String>.from(
        map['dinnerDishes'] ?? [],
      ),
      dinnerPrice:
      (map['dinnerPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'breakfastDishes': breakfastDishes,
      'breakfastPrice': breakfastPrice,
      'lunchDishes': lunchDishes,
      'lunchPrice': lunchPrice,
      'dinnerDishes': dinnerDishes,
      'dinnerPrice': dinnerPrice,
    };
  }
}