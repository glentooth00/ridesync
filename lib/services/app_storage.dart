
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/motorcycle.dart';
import '../models/user_profile.dart';

class AppStorage {
  static const String _userKey = 'ridesync_user';
  static const String _motorcyclesKey = 'ridesync_motorcycles';
  static const String _activeMotorcycleKey = 'ridesync_active_motorcycle';

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
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<List<Motorcycle>> loadMotorcycles() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_motorcyclesKey);

    if (data == null) return [];

    final decoded = jsonDecode(data) as List<dynamic>;

    return decoded
        .map((item) => Motorcycle.fromJson(
              item as Map<String, dynamic>,
            ))
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

  static Future<void> addMotorcycle(Motorcycle motorcycle) async {
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
}
