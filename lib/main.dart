import 'package:flutter/material.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/logging/logging.dart';

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

  runApp(const PartilhaApp());
}

/// Root widget.
///
/// Deliberately minimal. The design system (AGENTS.md §46), typography (§48)
/// and iconography (§47) are not implemented yet, and inventing a home screen
/// before the design tokens exist would bake throwaway choices into the first
/// real screen.
class PartilhaApp extends StatelessWidget {
  const PartilhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Partilha',
      debugShowCheckedModeBanner: false,
      home: PreImplementationNotice(),
    );
  }
}

/// States plainly that the app has no functionality yet.
///
/// Exists to replace the generated counter demo, which would otherwise make an
/// unimplemented project look like a working one. It is removed as soon as
/// the first real screen lands.
class PreImplementationNotice extends StatelessWidget {
  const PreImplementationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Partilha',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Under construction. No feature is implemented yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Architecture and protocol are documented in docs/.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
