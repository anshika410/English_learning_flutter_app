// Network connectivity — a proactive online/offline signal for the whole app.
// Wraps connectivity_plus so the offline screen can appear the instant the
// device drops its network (not only after a request fails). Note: this reports
// whether a network interface is up, not true internet reachability — enough for
// a "check your network" prompt.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _connectivity = Connectivity();

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// `true` when the device has a usable network interface, `false` when offline.
/// Streams live updates and seeds with an initial check so the first frame is
/// correct. Errors are treated as "assume online" so a connectivity glitch can
/// never trap the user behind the offline screen.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  try {
    yield _isOnline(await _connectivity.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* _connectivity.onConnectivityChanged
      .map(_isOnline)
      .handleError((_) => true);
});
