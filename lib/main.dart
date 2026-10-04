import 'package:flutter/material.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/core/routing/routing.dart';
import 'package:partilha/core/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Errors that escape the framework are logged rather than printed, so the
  // diagnostic path is the same one the rest of the app uses (AGENTS.md §52).
  final logger = StructuredLogger(sink: const ConsoleLogSink());

  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      'Uncaught framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  configureDependencies(logger: logger);

  logger.info('Partilha starting');

  runApp(PartilhaApp(currentRoute: CurrentRoute()));
}

/// Root widget.
///
/// Owns the theme and the router, and nothing else: which screen is shown and
/// what that screen does are the router's and the feature's business. Keeping
/// the switch here would put product behaviour in the composition root, which is
/// how a placeholder becomes permanent.
class PartilhaApp extends StatelessWidget {
  const PartilhaApp({required this.currentRoute, super.key});

  /// The current route, owned here because the router delegate must not
  /// outlive the widget that hosts it.
  final CurrentRoute currentRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Partilha',
      debugShowCheckedModeBanner: false,
      // Dark is the design target (AppTheme.mode); the light palette exists
      // for users whose system requires it.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.mode,
      routerDelegate: AppRouterDelegate(currentRoute),
      routeInformationParser: const AppRouteInformationParser(),
    );
  }
}
