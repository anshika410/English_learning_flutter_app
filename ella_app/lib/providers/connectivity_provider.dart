import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/analytics_service.dart';

/// `true` when the device has a usable network interface (Wi-Fi, Cellular, etc).
/// Streams live updates using connectivity_plus which hooks into the OS for instant,
/// battery-efficient network state reporting.
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  final checker = Connectivity();
  bool lastEmitted = true;

  void emit(List<ConnectivityResult> results) {
    // If there is ANY connection other than 'none', we consider it online.
    final online = results.any((result) => result != ConnectivityResult.none);
    
    if (lastEmitted != online) {
      lastEmitted = online;
      if (online) {
        AnalyticsService.logNetworkRestored();
      } else {
        AnalyticsService.logNetworkOffline();
      }
      if (!controller.isClosed) {
        controller.add(online);
      }
    }
  }

  // Initial check
  checker.checkConnectivity().then((results) {
    emit(results);
  });
  
  final sub = checker.onConnectivityChanged.listen((results) {
    emit(results);
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
