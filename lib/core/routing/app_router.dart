import 'package:flutter/material.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/routing/app_route.dart';
import 'package:partilha/features/settings/presentation/settings_screen.dart';

/// Turns [Uri]s into [AppRoute]s.
///
/// Hand-written rather than generated because the mapping is one line per route
/// and a generator would add a build step for no benefit (`AGENTS.md` §89).
class AppRouteInformationParser extends RouteInformationParser<AppRoute> {
  const AppRouteInformationParser();

  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final AppRoute? route = AppRoute.fromLocation(routeInformation.uri);
    // Unknown locations resolve to the first screen rather than throwing: a
    // stale deep link or restored state must not leave the user on a blank
    // window, and Settings is where a user can correct their device identity
    // (`AGENTS.md` §83).
    return route ?? AppRoute.settings;
  }

  @override
  RouteInformation? restoreRouteInformation(AppRoute configuration) =>
      RouteInformation(uri: Uri.parse(configuration.location));
}

/// Builds the widget for the current [AppRoute].
///
/// Flutter's own `Router` is used rather than a routing package: the app needs
/// a route table and a delegate, which is exactly what the framework provides,
/// so a dependency would buy nothing (`AGENTS.md` §54, §55).
class AppRouterDelegate extends RouterDelegate<AppRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoute> {
  AppRouterDelegate(this._currentRoute);

  final CurrentRoute _currentRoute;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  AppRoute get currentConfiguration => _currentRoute.value;

  /// Builds one page per reachable route.
  ///
  /// Only routes whose screen exists appear here. Enumerating every [AppRoute]
  /// would build a screen that does not exist yet, and shipping a route the user
  /// can reach but that renders nothing is worse than not offering it — so
  /// [AppRoute.send] stays out until it has a screen behind it.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _currentRoute,
      builder: (BuildContext context, _) => Navigator(
        key: navigatorKey,
        pages: <Page<void>>[
          // Settings is resolved from the container rather than constructed
          // here: the screen owns a controller with state, and building it in
          // build() would throw that state away on every rebuild (§80, §81).
          MaterialPage<void>(
            key: const ValueKey<String>('settings'),
            child: injectionContainer.resolve<SettingsScreen>(),
          ),
        ],
        onDidRemovePage: (Page<Object?> page) {
          // There is nothing to pop: the app has one screen and the platform
          // back gesture must leave the app rather than empty the stack.
          _currentRoute.go(AppRoute.settings);
        },
      ),
    );
  }

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _currentRoute.go(configuration);
  }

  @override
  Future<bool> popRoute() async => false;
}
