import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/data/data.dart';
import 'package:partilha/features/settings/domain/domain.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the real SQL against a real SQLite file.
///
/// The unit tests above use a fake data source, which is the right way to test
/// what the repository does with a failure. It cannot test the thing that most
/// often breaks: the schema, the upsert, and whether the file survives being
/// closed and reopened. Mocking sqflite away would defeat the point of an
/// integration test (`AGENTS.md` §60.2).
void main() {
  late Directory directory;
  late SqliteSettingsLocalDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('partilha_settings_test');
    dataSource = SqliteSettingsLocalDataSource(
      databaseName: 'test.db',
      databaseDirectory: () async => directory.path,
    );
  });

  tearDown(() async {
    await dataSource.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('reads null for a key that was never written', () async {
    expect(await dataSource.read('missing'), isNull);
  });

  test('writes then reads a value back unchanged', () async {
    await dataSource.write('a key', 'a value');

    expect(await dataSource.read('a key'), 'a value');
  });

  test('writing the same key twice replaces rather than duplicating', () async {
    await dataSource.write('a key', 'first');
    await dataSource.write('a key', 'second');

    expect(await dataSource.read('a key'), 'second');
  });

  test('keys are independent of one another', () async {
    await dataSource.write('one', '1');
    await dataSource.write('two', '2');

    expect(await dataSource.read('one'), '1');
    expect(await dataSource.read('two'), '2');
  });

  test('a value containing a quote is stored literally, not as SQL', () async {
    // The value is a bound parameter, so this must not need escaping and must not
    // be able to alter the statement.
    const String awkward = "Robert'); DROP TABLE settings;--";

    await dataSource.write('name', awkward);

    expect(await dataSource.read('name'), awkward);
  });

  test(
    'a value survives close and reopen, which is the point of persisting it',
    () async {
      await dataSource.write('survivor', 'still here');
      await dataSource.close();

      final SqliteSettingsLocalDataSource reopened =
          SqliteSettingsLocalDataSource(
            databaseName: 'test.db',
            databaseDirectory: () async => directory.path,
          );
      addTearDown(reopened.close);

      expect(await reopened.read('survivor'), 'still here');
    },
  );

  test(
    'opening the same database twice from two handles does not lose data',
    () async {
      await dataSource.write('shared', 'value');

      final SqliteSettingsLocalDataSource second =
          SqliteSettingsLocalDataSource(
            databaseName: 'test.db',
            databaseDirectory: () async => directory.path,
          );
      addTearDown(second.close);

      expect(await second.read('shared'), 'value');
    },
  );

  test(
    'the repository and the data source agree on the device name round trip',
    () async {
      // The end the feature actually cares about, through both layers, rather than
      // each layer tested against its own expectation.
      // A key mismatch between the repository's read and its write would pass
      // every unit test above and still make the name always read back as unset.
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        dataSource,
      );
      final DeviceName name =
          (DeviceName.create('Kitchen phone') as Success<DeviceName, Failure>)
              .value;

      expect(
        await repository.saveDeviceName(name),
        isA<Success<void, Failure>>(),
      );

      final Result<DeviceName, Failure> read = await repository
          .readDeviceName();

      expect((read as Success<DeviceName, Failure>).value, name);
    },
  );
}
