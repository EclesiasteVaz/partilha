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

  /// Where a user picks the device to send to.
  send('/send'),

  /// Where a user reviews the destination and selects files.
  transfer('/transfer');

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

  final List<AppRoute> _stack = <AppRoute>[AppRoute.settings];

  /// The routes below the current one, oldest first.
  ///
  /// Exposed read-only because the navigator needs to build a page per entry:
  /// a single "current route" value cannot express that going back from Transfer
  /// must reveal Discovery rather than replace it.
  List<AppRoute> get stack => List<AppRoute>.unmodifiable(_stack);

  /// Moves to [route], replacing the current entry.
  ///
  /// The equality check matters for the platform back gesture: a duplicate
  /// notification would re-push a route the user is already on, which reads as
  /// the screen sticking.
  void go(AppRoute route) {
    if (route == value) return;
    _stack[_stack.length - 1] = route;
    value = route;
  }

  /// Pushes [route] on top of the current one.
  void push(AppRoute route) {
    if (route == value) return;
    _stack.add(route);
    value = route;
  }

  /// Removes the current route, revealing the one below it.
  ///
  /// Returns `false` at the root, which is the navigator's signal that there is
  /// nothing left to pop and the platform should close the app instead
  /// (`AGENTS.md` §83).
  bool pop() {
    if (_stack.length <= 1) return false;
    _stack.removeLast();
    value = _stack.last;
    return true;
  }
}
