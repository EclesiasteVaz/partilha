import 'package:sqflite/sqflite.dart';

/// Reads and writes settings rows in SQLite.
///
/// The only place in the application that imports `sqflite` (§43, §22). Its
/// methods speak in [String] rather than in domain types on purpose: this is the
/// persistence contract, and translating at the repository boundary is what keeps
/// a database row from becoming a domain object by accident (§8).
abstract interface class SettingsLocalDataSource {
  /// Opens the database, creating or migrating it if needed.
  Future<void> open();

  /// The stored value for [key], or `null` when it was never written.
  Future<String?> read(String key);

  /// Writes [value] for [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Closes the database and releases the handle.
  Future<void> close();
}

/// SQLite implementation of [SettingsLocalDataSource].
///
/// One key/value table rather than a table per setting. The MVP stores exactly
/// one setting, and a table with a single column would encode the shape of
/// `value` as if it were the shape of every setting added later.
class SqliteSettingsLocalDataSource implements SettingsLocalDataSource {
  SqliteSettingsLocalDataSource({
    this.databaseName = 'partilha.db',
    this.version = 1,
    Future<String> Function()? databaseDirectory,
  }) : _databaseDirectory = databaseDirectory ?? getDatabasesPath;

  final String databaseName;

  /// Schema version, bumped with an explicit migration on every change (§44).
  final int version;

  final Future<String> Function() _databaseDirectory;

  Database? _database;

  /// The open handle, or a failure describing why it could not be opened.
  ///
  /// Opens on demand rather than in the constructor so that merely resolving this
  /// dependency does not touch the filesystem. Resolving happens during startup,
  /// and a database that cannot open must surface when it is used, with the
  /// failure, instead of crashing before the first frame (§83).
  Future<Database> _open() async {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final String directory = await _databaseDirectory();
    final Database opened = await openDatabase(
      '$directory/$databaseName',
      version: version,
      onCreate: (Database db, int _) async {
        await db.execute(
          'CREATE TABLE settings ('
          'key TEXT NOT NULL PRIMARY KEY, '
          'value TEXT NOT NULL'
          ')',
        );
      },
    );
    _database = opened;
    return opened;
  }

  @override
  Future<void> open() async => _open();

  @override
  Future<String?> read(String key) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    final Database db = await _open();
    // An upsert rather than delete-then-insert so a crash between the two cannot
    // leave the setting missing entirely.
    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    await db?.close();
  }
}
