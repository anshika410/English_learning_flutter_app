// Garden data provider — fetches GET /users/me/garden via the Ella API.
// Auth (anonymous token) is handled inside EllaApiService. Refreshable so the
// Garden tab can pull fresh state after a session ends.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/garden.dart';
import 'service_providers.dart';

final gardenProvider = FutureProvider.autoDispose<GardenData>((ref) async {
  final api = ref.read(ellaApiServiceProvider);
  return api.getGarden();
});
