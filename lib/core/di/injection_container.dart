import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/core/network/network.dart';
import 'package:partilha/core/platform/android_multicast_lock.dart';
import 'package:partilha/core/platform/multicast_lock.dart';
import 'package:partilha/features/discovery/application/application.dart';
import 'package:partilha/features/discovery/data/data.dart';
import 'package:partilha/features/discovery/domain/domain.dart';
import 'package:partilha/features/discovery/presentation/presentation.dart';
import 'package:partilha/features/file_transfer/application/application.dart';
import 'package:partilha/features/file_transfer/data/data.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/presentation.dart';
import 'package:partilha/features/settings/application/application.dart';
import 'package:partilha/features/settings/data/data.dart';
import 'package:partilha/features/settings/domain/domain.dart';
import 'package:partilha/features/settings/presentation/presentation.dart';

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

  /// Replaces an existing registration, for tests.
  ///
  /// `get_it` refuses to register the same type twice, so a test that wants the
  /// real graph but a fake provider — an mDNS service that does not touch the
  /// network, a picker that never opens a dialog — had no way in and could only
  /// avoid the real dependency by rebuilding the graph by hand.
  ///
  /// Lives on this wrapper rather than exposing `get_it` so the rest of the
  /// codebase keeps a single seam to the package (`AGENTS.md` §17, §60.1).
  void overrideLazySingleton<T extends Object>(T Function() factoryFunc) {
    // `unregister` may run the existing instance's disposer, which is
    // asynchronous. Overriding is a test concern and the replacement does not
    // depend on the disposal having finished, so the future is deliberately not
    // awaited: making this method async would force every caller to await a
    // teardown detail it does not care about (AGENTS.md §81, §89).
    final Object? pending = _locator.unregister<T>();
    if (pending is Future<void>) pending.ignore();
    registerLazySingleton<T>(factoryFunc);
  }

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
    ..registerLazySingleton<LogSink>(ConsoleLogSink.new)
    // A factory, not a singleton: a transport owns a socket and a frame stream,
    // so sharing one across sessions would mean two owners for the same
    // connection. Each pairing or transfer session resolves its own.
    ..registerFactory<WebSocketTransport>(
      () => DartIoWebSocketTransport(injectionContainer.resolve<AppLogger>()),
    )
    // A lazy singleton because it owns the database handle, which must be one
    // per process: a second handle would be a second connection with its own
    // cache and its own view of what is committed (§80, §81).
    ..registerLazySingleton<SettingsLocalDataSource>(
      SqliteSettingsLocalDataSource.new,
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SqliteSettingsRepository(
        injectionContainer.resolve<SettingsLocalDataSource>(),
      ),
    )
    // Factories, not singletons: a use case holds no resource, and a screen owns
    // its controller for as long as it is on screen. Making them singletons would
    // mean the container decides their lifetime, which is the opposite of §81.
    ..registerFactory<GetDeviceNameUseCase>(
      () => GetDeviceNameUseCase(
        injectionContainer.resolve<SettingsRepository>(),
      ),
    )
    ..registerFactory<SaveDeviceNameUseCase>(SaveDeviceNameUseCase.new)
    // A singleton, because the navigator keeps the Settings page alive on the
    // stack while the send flow is pushed on top of it. A factory per resolution
    // would rebuild the controller — and therefore the unsaved draft name — every
    // time the user came back from discovery, which the real back stack now
    // makes reachable (`AGENTS.md` §49, §80).
    ..registerLazySingleton<SettingsController>(
      () => SettingsController(
        getDeviceName: injectionContainer.resolve<GetDeviceNameUseCase>(),
        saveDeviceName: injectionContainer.resolve<SaveDeviceNameUseCase>(),
      ),
    )
    // The screen is a factory: it is a widget, and the navigator rebuilds it
    // whenever the page list changes. All mutable state lives in the controller,
    // so recreating the widget loses nothing.
    ..registerFactory<SettingsScreen>(
      () => SettingsScreen(
        controller: injectionContainer.resolve<SettingsController>(),
      ),
    )
    ..registerLazySingleton<MulticastLock>(MethodChannelMulticastLock.new)
    ..registerLazySingleton<DiscoveryService>(
      () => MdnsDiscoveryService(
        hostName: Platform.localHostname,
        multicastLock: injectionContainer.resolve<MulticastLock>(),
      ),
    )
    ..registerFactory<DiscoverNearbyDevicesUseCase>(
      () => DiscoverNearbyDevicesUseCase(
        injectionContainer.resolve<DiscoveryService>(),
      ),
    )
    ..registerFactory<DiscoveryController>(
      () => DiscoveryController(
        discoverNearbyDevices: injectionContainer
            .resolve<DiscoverNearbyDevicesUseCase>(),
      ),
    )
    ..registerFactory<DiscoveryScreen>(
      () => DiscoveryScreen(
        controller: injectionContainer.resolve<DiscoveryController>(),
      ),
    )
    ..registerLazySingleton<FileSelectionService>(
      () =>
          PlatformFileSelectionService(injectionContainer.resolve<AppLogger>()),
    )
    ..registerFactory<SelectFilesUseCase>(
      () => SelectFilesUseCase(
        injectionContainer.resolve<FileSelectionService>(),
      ),
    )
    // A singleton, unlike the other controllers, because it is the only holder
    // of the destination and the selection: Discovery sets the destination and
    // the Transfer screen reads it, so a factory per screen would lose the
    // selection the moment the page rebuilt (§11, §80).
    ..registerLazySingleton<TransferController>(
      () => TransferController(
        selectFiles: injectionContainer.resolve<SelectFilesUseCase>(),
      ),
    )
    ..registerFactory<TransferScreen>(
      () => TransferScreen(
        controller: injectionContainer.resolve<TransferController>(),
      ),
    );
}
