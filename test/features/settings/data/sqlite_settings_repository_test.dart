import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/data/data.dart';
import 'package:partilha/features/settings/domain/domain.dart';

/// A data source that is not SQLite, to prove the repository depends on the
/// contract rather than on the implementation.
///
/// If these tests used the real database they would pass for the wrong reason:
/// the interesting behaviour is what the repository does when storage throws.
class _FailingDataSource implements SettingsLocalDataSource {
  _FailingDataSource(this.error);

  final Exception error;

  @override
  Future<void> open() async {}

  @override
  Future<String?> read(String key) async => throw error;

  @override
  Future<void> write(String key, String value) async => throw error;

  @override
  Future<void> close() async {}
}

class _MapDataSource implements SettingsLocalDataSource {
  final Map<String, String> rows = <String, String>{};

  @override
  Future<void> open() async {}

  @override
  Future<String?> read(String key) async => rows[key];

  @override
  Future<void> write(String key, String value) async => rows[key] = value;

  @override
  Future<void> close() async {}
}

void main() {
  DeviceName name(String value) =>
      (DeviceName.create(value) as Success<DeviceName, Failure>).value;

  group('readDeviceName', () {
    test('returns the stored name', () async {
      final _MapDataSource source = _MapDataSource();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        source,
      );
      await repository.saveDeviceName(name('Desk'));

      final result = await repository.readDeviceName();

      expect((result as Success<DeviceName, Failure>).value.value, 'Desk');
    });

    test('returns the fallback on a first run, not a failure', () async {
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        _MapDataSource(),
      );

      final result = await repository.readDeviceName();

      expect(result, isA<Success<DeviceName, Failure>>());
      expect(
        (result as Success<DeviceName, Failure>).value,
        DeviceName.fallback,
      );
    });

    test('falls back when the stored value no longer validates', () async {
      // A row written before a rule tightened must not be advertised as a valid
      // name just because it is what happens to be in the database.
      final _MapDataSource source = _MapDataSource()
        ..rows[SqliteSettingsRepository.deviceNameKey] =
            'a' * (DeviceName.maxLength + 1);
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        source,
      );

      final result = await repository.readDeviceName();

      expect(
        (result as Success<DeviceName, Failure>).value,
        DeviceName.fallback,
      );
    });

    test('turns a storage exception into a typed StorageFailure', () async {
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        _FailingDataSource(Exception('disk gone')),
      );

      final result = await repository.readDeviceName();

      expect(
        result,
        isA<Err<DeviceName, Failure>>().having(
          (Err<DeviceName, Failure> e) => e.error,
          'error',
          isA<StorageFailure>(),
        ),
      );
    });

    test('never leaks the underlying exception type to the caller', () async {
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        _FailingDataSource(Exception('disk gone')),
      );

      final Err<DeviceName, Failure> result =
          await repository.readDeviceName() as Err<DeviceName, Failure>;

      expect(result.error, isNot(isA<Exception>()));
      expect(result.error.userMessage, isNot(contains('disk gone')));
    });
  });

  group('saveDeviceName', () {
    test('reports success', () async {
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        _MapDataSource(),
      );

      expect(
        await repository.saveDeviceName(name('Phone')),
        isA<Success<void, Failure>>(),
      );
    });

    test('replaces the previous value rather than accumulating rows', () async {
      final _MapDataSource source = _MapDataSource();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        source,
      );

      await repository.saveDeviceName(name('First'));
      await repository.saveDeviceName(name('Second'));

      expect(source.rows[SqliteSettingsRepository.deviceNameKey], 'Second');
      expect(source.rows, hasLength(1));
    });

    test('turns a storage exception into a typed StorageFailure', () async {
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        _FailingDataSource(Exception('read only')),
      );

      final result = await repository.saveDeviceName(name('Phone'));

      expect(
        result,
        isA<Err<void, Failure>>().having(
          (Err<void, Failure> e) => e.error,
          'error',
          isA<StorageFailure>(),
        ),
      );
    });

    test(
      'a write failure is not retryable, since retrying cannot help',
      () async {
        final SqliteSettingsRepository repository = SqliteSettingsRepository(
          _FailingDataSource(Exception('read only')),
        );

        final Err<void, Failure> result =
            await repository.saveDeviceName(name('Phone'))
                as Err<void, Failure>;

        expect(result.error.isRetryable, isFalse);
      },
    );
  });
}
