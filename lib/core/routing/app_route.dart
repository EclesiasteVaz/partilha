import 'package:flutter/foundation.dart';

/// Every screen the application can show.
///
/// An enum rather than a string because a route that does not exist should not
/// compile. Named routes drift: a typo in a `pushNamed` argument surfaces as a
/// runtime "route not found" on a user's device, whereas a missing case here is
/// an exhaustiveness error for the compiler (`AGENTS.md` §83).
enum AppRoute {
  /// Device name and identity settings. The first real screen.
  settings('/'),

  /// Where a user selects files to send. Not yet implemented.
  send('/send');

  const AppRoute(this.location);

  /// The URI this route answers to.
  ///
  /// Public because the platform needs it to report a deep link or a restored
  /// state, and duplicating the mapping in each consumer is how the two drift.
  final String location;

  /// The route serving [location], or `null` when nothing matches.
  ///
  /// A [Uri] rather than a [String] so a query string cannot be mistaken for
  /// part of the path, which would silently match nothing.
  static AppRoute? fromLocation(Uri location) {
    final String path = location.path;
    for (final AppRoute route in AppRoute.values) {
      if (route.location == path) return route;
    }
    return null;
  }
}

/// Which route the application is currently showing.
///
/// A [ValueNotifier] rather than a `ChangeNotifier` because there is nothing
/// derived to notify: one field, read by [AppRouterDelegate] and written by the
/// navigation callbacks. Using a full `ChangeNotifier` here would imply
/// listeners that must be disposed without there being any state to invalidate.
class CurrentRoute extends ValueNotifier<AppRoute> {
  CurrentRoute() : super(AppRoute.settings);

  /// Moves to [route], or does nothing if it is already current.
  ///
  /// The equality check matters for the platform back gesture: a duplicate
  /// notification would re-push a route the user is already on, which reads as
  /// the screen sticking.
  void go(AppRoute route) {
    if (route == value) return;
    value = route;
  }
}
