import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// `true` when the device has a usable network interface AND can reach the internet.
/// Streams live updates using internet_connection_checker_plus which safely handles
/// app lifecycle events. It uses a debounce for offline states to prevent network
/// jitter (dropped packets) from causing random "offline" interruptions.
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  final checker = InternetConnection();
  
  Timer? debounceTimer;
  bool lastEmitted = true;

  void emit(bool isOnline) {
    if (lastEmitted != isOnline) {
      lastEmitted = isOnline;
      if (!controller.isClosed) {
        controller.add(isOnline);
      }
    }
  }

  // Initial check
  checker.hasInternetAccess.then((hasAccess) {
    emit(hasAccess);
  });
  
  final sub = checker.onStatusChange.listen((status) {
    final isOnline = status == InternetStatus.connected;
    
    if (isOnline) {
      // Instantly go online and cancel any pending offline debounce
      debounceTimer?.cancel();
      emit(true);
    } else {
      // Debounce the offline state by 4 seconds to ignore random jitter/dropped pings
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(seconds: 4), () {
        emit(false);
      });
    }
  });

  ref.onDispose(() {
    debounceTimer?.cancel();
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// A temporary flag that stays true for 3.5 seconds after coming back online.
final showBackOnlineProvider = StateProvider<bool>((ref) => false);
