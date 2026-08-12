// Tests for the home-screen fields EllaApiService parses out of
// GET /users/me/memory: last_time_recap and next_topics {recommended,
// alternatives}. A mock http.Client feeds canned responses; a seeded token
// skips the anonymous-auth round-trip.

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
    return EllaApiService(
      baseUrl: 'https://ella.navgurukul.org/api',
      client: client,
    );
  }

  test('getUserMemory parses next_topics (recommended + alternatives)', () async {
    final api = serviceReturning('/users/me/memory', {
      'id': 'user-1',
      'level': 'A1',
      'next_topics': {
        'recommended': {
          'name': 'Food I like',
          'label': 'Food',
          'icon': 'a1-04-food-i-like',
          'starter': 'What is your favourite food?',
        },
        'alternatives': [
          {'name': 'My family', 'label': 'Family', 'icon': 'a1-02-my-family'},
          {'name': 'My school', 'label': 'School'},
        ],
      },
    });

    final memory = await api.getUserMemory();
    expect(memory.nextTopics.recommended?.name, 'Food I like');
    expect(memory.nextTopics.recommended?.label, 'Food');
    expect(memory.nextTopics.recommended?.starter, 'What is your favourite food?');
    expect(memory.nextTopics.alternatives, hasLength(2));
    expect(memory.nextTopics.alternatives.first.name, 'My family');
    expect(memory.nextTopics.alternatives.first.label, 'Family');
    expect(memory.nextTopics.alternatives[1].display, 'School');
  });

  test('getUserMemory defaults next_topics to empty when absent', () async {
    final api = serviceReturning('/users/me/memory', {
      'id': 'user-1',
      'level': 'A1',
    });

    final memory = await api.getUserMemory();
    expect(memory.nextTopics.recommended, isNull);
    expect(memory.nextTopics.alternatives, isEmpty);
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
