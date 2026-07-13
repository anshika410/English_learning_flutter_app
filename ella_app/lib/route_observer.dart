// App-wide route observer. Screens that own background audio (e.g. the garden)
// subscribe as RouteAware so they can start/stop sound based on whether their
// route is actually the visible top-most page — not just mounted. This prevents
// music from bleeding into screens pushed on top (or under) them.

import 'package:flutter/widgets.dart';
import 'services/native_tts_service.dart';

class TtsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _stopTts() {
    NativeTtsService.instance?.stop();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _stopTts();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute) {
      _stopTts();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _stopTts();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PageRoute) {
      _stopTts();
    }
  }
}

final TtsRouteObserver appRouteObserver = TtsRouteObserver();
