import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_options.dart';

/// Persists user profile and settings to SharedPreferences.
class UserPrefsService {
  static const _keyName = 'user_name';
  static const _keyAge = 'user_age';
  static const _keyLocation = 'user_location';
  static const _keyLevel = 'user_level';
  static const _keyLevelLabel = 'user_level_label';
  static const _keyFirstSessionDone = 'first_session_done';
  static const _keyFocusGrammar = 'focus_grammar';
  static const _keyFocusVocab = 'focus_vocabulary';
  static const _keyFocusFluency = 'focus_fluency';

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

  // ── Focus Settings ───────────────────────────────────────────────────────

  FocusSettings get focusSettings {
    final grammarStr = _prefs.getString(_keyFocusGrammar) ?? 'balanced';
    final vocabStr = _prefs.getString(_keyFocusVocab) ?? 'balanced';
    final fluencyStr = _prefs.getString(_keyFocusFluency) ?? 'balanced';

    final grammar = GrammarFocus.values.firstWhere(
      (e) => e.name == grammarStr,
      orElse: () => GrammarFocus.balanced,
    );
    final vocabulary = VocabFocus.values.firstWhere(
      (e) => e.name == vocabStr,
      orElse: () => VocabFocus.balanced,
    );
    final fluency = FluencyFocus.values.firstWhere(
      (e) => e.name == fluencyStr,
      orElse: () => FluencyFocus.balanced,
    );

    return FocusSettings(
      grammar: grammar,
      vocabulary: vocabulary,
      fluency: fluency,
    );
  }

  Future<void> saveFocusSettings(FocusSettings settings) async {
    await init();
    await _prefs.setString(_keyFocusGrammar, settings.grammar.name);
    await _prefs.setString(_keyFocusVocab, settings.vocabulary.name);
    await _prefs.setString(_keyFocusFluency, settings.fluency.name);
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
    await _prefs.remove(_keyFocusGrammar);
    await _prefs.remove(_keyFocusVocab);
    await _prefs.remove(_keyFocusFluency);
  }
}
