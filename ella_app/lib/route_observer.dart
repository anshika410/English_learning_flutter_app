// App-wide route observer. Screens that own background audio (e.g. the garden)
// subscribe as RouteAware so they can start/stop sound based on whether their
// route is actually the visible top-most page — not just mounted. This prevents
// music from bleeding into screens pushed on top (or under) them.

import 'package:flutter/widgets.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
