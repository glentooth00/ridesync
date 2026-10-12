
class Motorcycle {
  final String id;
  final String nickname;
  final String make;
  final String model;
  final int? year;
  final String type;
  final int odometerKm;
  final int oilChangeIntervalKm;

  const Motorcycle({
    required this.id,
    required this.nickname,
    required this.make,
    required this.model,
    this.year,
    required this.type,
    required this.odometerKm,
    required this.oilChangeIntervalKm,
  });

  String get displayName => '$make $model';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'make': make,
      'model': model,
      'year': year,
      'type': type,
      'odometerKm': odometerKm,
      'oilChangeIntervalKm': oilChangeIntervalKm,
    };
  }

  factory Motorcycle.fromJson(Map<String, dynamic> json) {
    return Motorcycle(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '',
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int?,
      type: json['type'] as String? ?? 'Other',
      odometerKm: json['odometerKm'] as int? ?? 0,
      oilChangeIntervalKm:
          json['oilChangeIntervalKm'] as int? ?? 1500,
    );
  }
}
