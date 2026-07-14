// Tests for previousGardenProvider — the per-level garden fetch behind the
// garden switcher (GET /users/me/garden?level=<code>). A mock http.Client
// feeds canned responses; a seeded token skips the anonymous-auth round-trip.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ella_app/providers/garden_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/services/ella_api_service.dart';

Map<String, dynamic> _gardenJson(String level) => {
  'level': level,
  'recommended_topic': 'Old favourites',
  'units': [
    {
      'unit': 1,
      'name': 'Describing the world',
      'focus': 'Moving from naming things to describing them.',
      'skills': [
        {
          'id': 'U1-VOC-01',
          'strand': 'VOC',
          'text': 'I can describe what people look like and how they feel.',
          'status': 'owned',
          'sightings': 3,
          'evidence': [
            {
              'evidence': 'My friend is tall and happy.',
              'confidence': 0.95,
              'prompted': true,
              'topic': 'My friends',
              'created_at': '2026-07-10T09:42:10+00:00',
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ella_api_access_token': 'test-token',
      'ella_api_user_id': 'user-1',
    });
  });

  ProviderContainer containerReturning(
    Object json, {
    void Function(http.Request request)? onRequest,
  }) {
    final client = MockClient((req) async {
      onRequest?.call(req);
      return http.Response.bytes(
        utf8.encode(jsonEncode(json)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final container = ProviderContainer(
      overrides: [
        ellaApiServiceProvider.overrideWithValue(
          EllaApiService(
            baseUrl: 'https://ella.navgurukul.org/api',
            client: client,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('requests /users/me/garden with the level query param', () async {
    http.Request? seen;
    final container = containerReturning(
      _gardenJson('A1'),
      onRequest: (req) => seen = req,
    );

    final garden = await container.read(previousGardenProvider('A1').future);

    expect(seen, isNotNull);
    expect(seen!.url.path, endsWith('/users/me/garden'));
    expect(seen!.url.queryParameters['level'], 'A1');
    expect(garden.level, 'A1');
    expect(garden.steps.single.name, 'Describing the world');
    final skill = garden.steps.single.skills.single;
    expect(skill.sightings, 3);
    expect(skill.evidence.single.quote, 'My friend is tall and happy.');
    expect(skill.evidence.single.topic, 'My friends');
  });

  test('throws when the backend echoes back a different level', () async {
    final container = containerReturning(_gardenJson('B2'));

    await expectLater(
      container.read(previousGardenProvider('A1').future),
      throwsA(isA<EllaApiException>()),
    );
  });

  test('throws when the backend returns no units', () async {
    final container = containerReturning({'level': 'A1', 'units': const []});

    await expectLater(
      container.read(previousGardenProvider('A1').future),
      throwsA(isA<EllaApiException>()),
    );
  });
}
