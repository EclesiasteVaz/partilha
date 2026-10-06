import 'dart:async';

import 'package:flutter/material.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/routing/app_route.dart';
import 'package:partilha/features/discovery/presentation/discovery_screen.dart';
import 'package:partilha/features/file_transfer/presentation/presentation.dart';
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

  /// Builds one page per entry on the stack.
  ///
  /// A page list rather than a single swapped page, because the send flow is
  /// three steps deep (Settings → Discovery → Transfer) and the platform back
  /// gesture has to walk back through them instead of closing the app
  /// (`AGENTS.md` §49).
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _currentRoute,
      builder: (BuildContext context, _) => Navigator(
        key: navigatorKey,
        pages: <Page<void>>[
          for (final AppRoute route in _currentRoute.stack) _pageFor(route),
        ],
        // The stack lives in [CurrentRoute], which is the single source of
        // truth. Flutter removes pages declaratively from [pages], so this
        // callback only has to reconcile: a page disappearing here is the result
        // of `popRoute` already having updated the stack.
        onDidRemovePage: (_) {},
      ),
    );
  }

  /// Resolves a route to its screen.
  ///
  /// Every route resolves to something, because the enum is closed and each
  /// value appears here. A route without a screen would be a screen the user can
  /// reach that renders nothing, which is worse than not offering it.
  Page<void> _pageFor(AppRoute route) => switch (route) {
    AppRoute.settings => MaterialPage<void>(
      key: const ValueKey<String>('settings'),
      child: injectionContainer.resolve<SettingsScreen>(),
    ),
    AppRoute.send => MaterialPage<void>(
      key: const ValueKey<String>('send'),
      child: injectionContainer.resolve<DiscoveryScreen>(),
    ),
    AppRoute.transfer => MaterialPage<void>(
      key: const ValueKey<String>('transfer'),
      child: injectionContainer.resolve<TransferScreen>(),
    ),
  };

  /// Replaces the whole stack with [configuration].
  ///
  /// Used for deep links and restored state, where the platform is telling us
  /// the complete destination rather than a step forward from where we are.
  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _currentRoute.go(configuration);
  }

  /// Pushes [route] on top of the current one.
  ///
  /// Separate from [setNewRoutePath] on purpose: that one replaces the stack,
  /// which is right for a deep link and wrong for moving forward through the
  /// send flow, because it would make Back skip the screen the user came from.
  void push(AppRoute route) => _currentRoute.push(route);

  @override
  Future<bool> popRoute() async => _currentRoute.pop();
}

/// Pushes [route] onto the navigation stack.
///
/// The cast is the cost of building on Flutter's own `Router` instead of a
/// routing package: `Router.of(context).routerDelegate` is typed as
/// `RouterDelegate<Object?>`, so this project's typed [AppRouterDelegate] cannot
/// be reached through it. Confined to this function so no screen has to cast,
/// and so the fallback lives next to it (`AGENTS.md` §54, §56).
///
/// Falls back to replacing the route when the delegate is not ours. Losing the
/// back stack is a degraded navigation, not a reason to leave the user on the
/// screen they tapped from (`AGENTS.md` §83).
void pushRoute(BuildContext context, AppRoute route) {
  final RouterDelegate<Object?> delegate = Router.of(context).routerDelegate;
  if (delegate is AppRouterDelegate) {
    delegate.push(route);
    return;
  }
  unawaited(delegate.setNewRoutePath(route));
}
