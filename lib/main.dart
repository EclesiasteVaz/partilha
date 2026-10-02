import 'package:flutter/material.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/logging/logging.dart';
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

  runApp(const PartilhaApp());
}

/// Root widget.
///
/// Deliberately minimal. No home screen is invented: the first real screen
/// belongs to a feature, and building one here would put product behaviour in
/// the composition root. The design system (`AGENTS.md` §46) is wired up so
/// feature screens inherit it.
class PartilhaApp extends StatelessWidget {
  const PartilhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Partilha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const PreImplementationNotice(),
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const AppIcon(AppIcons.info, size: AppIconSizes.xl),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Partilha',
                  style: context.textStyles.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Under construction. No feature is implemented yet.',
                  style: context.textStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Architecture and protocol are documented in docs/.',
                  style: context.textStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
