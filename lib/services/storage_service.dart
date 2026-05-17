import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generic Save/Load
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setDouble(String key, double value) => _prefs.setDouble(key, value);
  double? getDouble(String key) => _prefs.getDouble(key);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  int? getInt(String key) => _prefs.getInt(key);

  // Helper for Offset (used for button positions)
  Future<void> setOffset(String key, double dx, double dy) async {
    await _prefs.setDouble('${key}_dx', dx);
    await _prefs.setDouble('${key}_dy', dy);
  }

  double? getOffsetDx(String key) => _prefs.getDouble('${key}_dx');
  double? getOffsetDy(String key) => _prefs.getDouble('${key}_dy');
}
