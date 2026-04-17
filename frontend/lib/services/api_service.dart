import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Central service for all calls to the Ella backend.
///
/// Auth flow:
///   1. On first launch, generate a UUID device_id and call POST /auth/anonymous
///   2. Store the returned JWT token in SharedPreferences
///   3. Attach the token as Bearer on every subsequent request
class ApiService {
  static String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  static const String _keyToken = 'api_token';
  static const String _keyDeviceId = 'device_id';
  static const String _keyUserId = 'user_id';

  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Token management ────────────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(_keyToken);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_keyToken, token);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await _sharedPrefs;
    String? id = prefs.getString(_keyDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  Future<String?> getUserId() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(_keyUserId);
  }

  // ── Auth ────────────────────────────────────────────────────────────────

  /// Ensures the user is authenticated. Calls /auth/anonymous if no token.
  /// Returns true if successful.
  Future<bool> ensureAuthenticated() async {
    final token = await getToken();
    if (token != null) return true;
    return _anonymousAuth();
  }

  Future<bool> _anonymousAuth() async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/anonymous'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveToken(data['access_token'] as String);
        final prefs = await _sharedPrefs;
        await prefs.setString(_keyUserId, data['user_id'] as String);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── HTTP helpers ────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _get(String path) async {
    return http.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    return http.put(
      Uri.parse('$_baseUrl$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
  }

  // ── Users ───────────────────────────────────────────────────────────────

  /// Fetch the current user's profile from the backend.
  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final response = await _get('/users/me');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Update name, age, location on the backend.
  Future<bool> updateProfile({
    String? name,
    String? age,
    String? location,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (age != null) body['age'] = age;
      if (location != null) body['location'] = location;
      if (body.isEmpty) return true;

      final response = await _put('/users/me', body);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Placements ──────────────────────────────────────────────────────────

  /// Save a completed placement result to the backend.
  Future<bool> savePlacement({
    required String level,
    required String levelLabel,
    required String highlight,
    List<Map<String, String>>? transcript,
  }) async {
    try {
      final response = await _post('/placements', {
        'level': level,
        'level_label': levelLabel,
        'highlight': highlight,
        if (transcript != null) 'transcript_json': transcript,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get the latest placement result from the backend.
  Future<Map<String, dynamic>?> getLatestPlacement() async {
    try {
      final response = await _get('/placements/latest');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Health ──────────────────────────────────────────────────────────────

  /// Quick connectivity check.
  Future<bool> isReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
