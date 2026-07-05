// Home-screen topics provider — fetches GET /users/me/topics via the Ella API.
// Auth (anonymous token) is handled inside EllaApiService. autoDispose so the
// list refreshes when the home screen is re-entered.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home_topic.dart';
import 'service_providers.dart';

final topicsProvider = FutureProvider.autoDispose<List<HomeTopic>>((ref) async {
  final api = ref.read(ellaApiServiceProvider);
  return api.getTopics();
});
