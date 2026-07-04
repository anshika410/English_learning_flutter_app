import 'package:shared_preferences/shared_preferences.dart';

/// Persists user profile and settings to SharedPreferences.
class UserPrefsService {
  static const _keyName = 'user_name';
  static const _keyAge = 'user_age';
  static const _keyLocation = 'user_location';
  static const _keyLevel = 'user_level';
  static const _keyLevelLabel = 'user_level_label';
  static const _keyFirstSessionDone = 'first_session_done';

  static SharedPreferences? _sharedPrefs;

  SharedPreferences get _prefs {
    assert(_sharedPrefs != null, 'UserPrefsService: call init() first');
    return _sharedPrefs!;
  }

  Future<void> init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  String? get userName => _prefs.getString(_keyName);
  String? get userAge => _prefs.getString(_keyAge);
  String? get userLocation => _prefs.getString(_keyLocation);
  String? get userLevel => _prefs.getString(_keyLevel);
  String? get userLevelLabel => _prefs.getString(_keyLevelLabel);

  Future<void> saveProfile({
    String? name,
    String? age,
    String? location,
    String? level,
    String? levelLabel,
  }) async {
    await init();
    if (name != null) await _prefs.setString(_keyName, name);
    if (age != null) await _prefs.setString(_keyAge, age);
    if (location != null) await _prefs.setString(_keyLocation, location);
    if (level != null) await _prefs.setString(_keyLevel, level);
    if (levelLabel != null) await _prefs.setString(_keyLevelLabel, levelLabel);
  }

  // ── First session ────────────────────────────────────────────────────────

  bool get hasCompletedFirstSession =>
      _prefs.getBool(_keyFirstSessionDone) ?? false;

  Future<void> setFirstSessionComplete() async {
    await init();
    await _prefs.setBool(_keyFirstSessionDone, true);
  }



  bool get hasCompletedPlacement => _prefs.getString(_keyLevel) != null;

  Future<void> clearAll() async {
    await init();
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyAge);
    await _prefs.remove(_keyLocation);
    await _prefs.remove(_keyLevel);
    await _prefs.remove(_keyLevelLabel);
    await _prefs.remove(_keyFirstSessionDone);
  }
}
