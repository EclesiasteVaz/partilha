import 'package:get_it/get_it.dart';
import 'package:partilha/core/logging/logging.dart';

/// The application service locator.
///
/// Dependency direction is inverted here and only here: this file is the
/// composition root, so it is the one place allowed to know every concrete
/// implementation at once (`AGENTS.md` §11). Nothing else may import
/// `get_it`, and domain code must never reach for it (`AGENTS.md` §11, §18).
final InjectionContainer injectionContainer = InjectionContainer();

/// Thin wrapper over the `get_it` singleton.
///
/// Exists so the rest of the codebase depends on this type rather than on a
/// third-party global, keeping the package replaceable (`AGENTS.md` §17) and
/// giving tests one seam to reset.
class InjectionContainer {
  InjectionContainer() : _locator = GetIt.instance;

  final GetIt _locator;

  /// Resolves a registered dependency.
  ///
  /// Throws [StateError] when the type was never registered, because a missing
  /// registration is a programming error in the composition root and must not
  /// degrade into a null at the call site (`AGENTS.md` §83).
  T resolve<T extends Object>({String? instanceName}) {
    if (!isRegistered<T>(instanceName: instanceName)) {
      throw StateError(
        'Nothing is registered for $T'
        '${instanceName == null ? '' : " named '$instanceName'"}. '
        'Register it in configureDependencies().',
      );
    }
    return _locator.get<T>(instanceName: instanceName);
  }

  /// Whether [T] can be resolved.
  bool isRegistered<T extends Object>({String? instanceName}) =>
      _locator.isRegistered<T>(instanceName: instanceName);

  /// Registers a lazily created singleton, the default lifecycle for
  /// infrastructure that owns a resource such as a database handle or a
  /// listening socket (`AGENTS.md` §81).
  void registerLazySingleton<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
  }) => _locator.registerLazySingleton<T>(
    factoryFunc,
    instanceName: instanceName,
  );

  /// Registers a shared instance built eagerly, for state that must exist
  /// before the first frame.
  void registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
  }) => _locator.registerSingleton<T>(instance, instanceName: instanceName);

  /// Registers a factory, for objects that must not outlive one screen or one
  /// operation.
  void registerFactory<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
  }) => _locator.registerFactory<T>(factoryFunc, instanceName: instanceName);

  /// Disposes everything and clears the registry.
  ///
  /// Called on shutdown and between tests.
  ///
  /// `get_it` does not surface the individual errors a registered disposer may
  /// throw, so this cannot report them. Registrations are therefore expected to
  /// clean up defensively rather than rely on the locator to surface a failure
  /// (`AGENTS.md` §81).
  Future<void> reset() => _locator.reset();
}

/// Wires every dependency. Called once from `main()`.
///
/// Registration order does not matter: `registerLazySingleton` does not build
/// its dependency until the first `resolve`, so this function never triggers
/// construction. That keeps the composition root free of initialisation-order
/// bugs, which are otherwise very easy to introduce with eager singletons.
void configureDependencies({required AppLogger logger}) {
  injectionContainer
    ..registerLazySingleton<AppLogger>(() => logger)
    ..registerLazySingleton<LogSink>(ConsoleLogSink.new);
}
