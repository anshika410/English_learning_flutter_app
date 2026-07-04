// Tests for the two home-screen additions to EllaApiService: getTopics()
// (GET /users/me/topics, returned as a bare JSON array) and last_time_recap
// parsing in getUserMemory (GET /users/me/memory). A mock http.Client feeds
// canned responses; a seeded token skips the anonymous-auth round-trip.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ella_app/services/ella_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ella_api_access_token': 'test-token',
      'ella_api_user_id': 'user-1',
    });
  });

  EllaApiService serviceReturning(String path, Object json) {
    final client = MockClient((req) async {
      if (req.url.path.endsWith(path)) {
        // Bytes + charset header, mirroring the real server: without the
        // charset, http decodes .body as latin1 and mangles emoji.
        return http.Response.bytes(
          utf8.encode(jsonEncode(json)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });
    return EllaApiService(client: client);
  }

  test('getTopics parses a bare JSON array of topic cards', () async {
    final api = serviceReturning('/users/me/topics', [
      {
        'id': 'my_family',
        'name': 'My family',
        'theme': 'Self',
        'description': 'Talk about your family.',
        'icon': '👨‍👩‍👧',
        'color': '#E0EDFF',
      },
      {'id': 'my_school', 'name': 'My school'},
    ]);

    final topics = await api.getTopics();
    expect(topics, hasLength(2));
    expect(topics.first.name, 'My family');
    expect(topics.first.icon, '👨‍👩‍👧');
    expect(topics.first.color, '#E0EDFF');
    expect(topics[1].name, 'My school');
  });

  test('getUserMemory reads last_time_recap', () async {
    final api = serviceReturning('/users/me/memory', {
      'id': 'user-1',
      'level': 'A1',
      'owned': <String>[],
      'emerging': <String>[],
      'last_topics': ['My family'],
      'last_time_recap': 'Last time, we talked about your dog Rex!',
    });

    final memory = await api.getUserMemory();
    expect(memory.lastTimeRecap, 'Last time, we talked about your dog Rex!');
  });

  test('getUserMemory defaults last_time_recap to empty when absent', () async {
    final api = serviceReturning('/users/me/memory', {
      'id': 'user-1',
      'level': 'A1',
    });

    final memory = await api.getUserMemory();
    expect(memory.lastTimeRecap, '');
  });
}
