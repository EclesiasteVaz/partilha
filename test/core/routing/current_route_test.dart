import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/routing/routing.dart';

void main() {
  group('push', () {
    test('puts the route on top of the stack', () {
      final CurrentRoute route = CurrentRoute()
        ..push(AppRoute.send)
        ..push(AppRoute.transfer);

      expect(route.value, AppRoute.transfer);
      expect(route.stack, <AppRoute>[
        AppRoute.settings,
        AppRoute.send,
        AppRoute.transfer,
      ]);
    });

    test('ignores a push of the route already showing', () {
      final CurrentRoute route = CurrentRoute()..push(AppRoute.send);

      route.push(AppRoute.send);

      expect(route.stack, <AppRoute>[AppRoute.settings, AppRoute.send]);
    });
  });

  group('pop', () {
    test('reveals the route below', () {
      final CurrentRoute route = CurrentRoute()
        ..push(AppRoute.send)
        ..push(AppRoute.transfer);

      expect(route.pop(), isTrue);

      expect(route.value, AppRoute.send);
    });

    test('refuses at the root so the platform closes the app', () {
      final CurrentRoute route = CurrentRoute();

      expect(route.pop(), isFalse);
      expect(route.value, AppRoute.settings);
    });

    test('unwinds all the way back to the root', () {
      final CurrentRoute route = CurrentRoute()
        ..push(AppRoute.send)
        ..push(AppRoute.transfer);

      expect(route.pop(), isTrue);
      expect(route.pop(), isTrue);
      expect(route.pop(), isFalse);
      expect(route.value, AppRoute.settings);
    });
  });

  group('go', () {
    test('replaces the current entry instead of stacking', () {
      // Used for deep links and restored state, where the platform states the
      // whole destination rather than one step forward.
      final CurrentRoute route = CurrentRoute()..push(AppRoute.send);

      route.go(AppRoute.transfer);

      expect(route.stack, <AppRoute>[AppRoute.settings, AppRoute.transfer]);
    });

    test('does not notify when the route is already showing', () {
      final CurrentRoute route = CurrentRoute();
      int notifications = 0;
      route.addListener(() => notifications++);

      route.go(AppRoute.settings);

      expect(notifications, 0);
    });
  });

  test('the stack cannot be mutated from outside', () {
    final CurrentRoute route = CurrentRoute()..push(AppRoute.send);

    expect(() => route.stack.add(AppRoute.transfer), throwsUnsupportedError);
  });

  group('fromLocation', () {
    test('resolves every route', () {
      for (final AppRoute value in AppRoute.values) {
        expect(AppRoute.fromLocation(Uri.parse(value.location)), value);
      }
    });

    test('returns null for an unknown path', () {
      expect(AppRoute.fromLocation(Uri.parse('/nope')), isNull);
    });
  });
}
