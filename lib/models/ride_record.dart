
class RideRecord {
  final String id;
  final String motorcycleId;
  final String motorcycleName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceKm;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final double odometerAfterKm;

  const RideRecord({
    required this.id,
    required this.motorcycleId,
    required this.motorcycleName,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.odometerAfterKm,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motorcycleId': motorcycleId,
      'motorcycleName': motorcycleName,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'distanceKm': distanceKm,
      'averageSpeedKmh': averageSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'odometerAfterKm': odometerAfterKm,
    };
  }

  factory RideRecord.fromJson(Map<String, dynamic> json) {
    return RideRecord(
      id: json['id'] as String,
      motorcycleId: json['motorcycleId'] as String,
      motorcycleName: json['motorcycleName'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      averageSpeedKmh: (json['averageSpeedKmh'] as num).toDouble(),
      maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
      odometerAfterKm: (json['odometerAfterKm'] as num).toDouble(),
    );
  }
}
