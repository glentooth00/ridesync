
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/motorcycle.dart';
import '../models/user_profile.dart';
import '../models/ride_record.dart';

class AppStorage {
  static const String _userKey = 'ridesync_user';
  static const String _motorcyclesKey = 'ridesync_motorcycles';
  static const String _activeMotorcycleKey =
      'ridesync_active_motorcycle';
  static const String _rideHistoryKey = 'ridesync_ride_history';

  // USER STORAGE

  static Future<UserProfile?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userKey);

    if (data == null) return null;

    return UserProfile.fromJson(
      jsonDecode(data) as Map<String, dynamic>,
    );
  }

  static Future<void> saveUser(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _userKey,
      jsonEncode(user.toJson()),
    );
  }

  // MOTORCYCLE STORAGE

  static Future<List<Motorcycle>> loadMotorcycles() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_motorcyclesKey);

    if (data == null) return [];

    final decoded = jsonDecode(data) as List<dynamic>;

    return decoded
        .map(
          (item) => Motorcycle.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> saveMotorcycles(
    List<Motorcycle> motorcycles,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _motorcyclesKey,
      jsonEncode(
        motorcycles.map((bike) => bike.toJson()).toList(),
      ),
    );
  }

  static Future<void> addMotorcycle(
    Motorcycle motorcycle,
  ) async {
    final motorcycles = await loadMotorcycles();

    motorcycles.add(motorcycle);

    await saveMotorcycles(motorcycles);

    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeMotorcycleKey);

    if (activeId == null) {
      await prefs.setString(
        _activeMotorcycleKey,
        motorcycle.id,
      );
    }
  }

  static Future<String?> loadActiveMotorcycleId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_activeMotorcycleKey);
  }

  static Future<void> setActiveMotorcycle(String id) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_activeMotorcycleKey, id);
  }

  // RIDE HISTORY

  static Future<List<RideRecord>> loadRideHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_rideHistoryKey);

    if (data == null) return [];

    final decoded = jsonDecode(data) as List<dynamic>;

    final rides = decoded
        .map(
          (item) => RideRecord.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();

    // Keep the newest rides first.
    rides.sort(
      (a, b) => b.startedAt.compareTo(a.startedAt),
    );

    return rides;
  }

  static Future<void> saveRideHistory(
    List<RideRecord> rides,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _rideHistoryKey,
      jsonEncode(
        rides.map((ride) => ride.toJson()).toList(),
      ),
    );
  }

  static Future<void> saveRide(RideRecord ride) async {
    final rides = await loadRideHistory();

    // Prevent duplicate records with the same ID.
    rides.removeWhere((item) => item.id == ride.id);

    // Put the latest ride first.
    rides.insert(0, ride);

    await saveRideHistory(rides);
  }

  static Future<void> deleteRide(String rideId) async {
    final rides = await loadRideHistory();

    rides.removeWhere((ride) => ride.id == rideId);

    await saveRideHistory(rides);
  }

  static Future<void> clearRideHistory() async {
    await saveRideHistory([]);
  }
}
