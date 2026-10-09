import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

void main() {
  /// The destination as a set of names — how a caller holding a directory
  /// listing answers [resolveFilenameConflict].
  bool Function(String candidate) existsIn(Set<String> existing) =>
      (String candidate) => existing.contains(candidate);

  group('resolveFilenameConflict', () {
    test('returns the desired name when nothing holds it', () {
      expect(
        resolveFilenameConflict('photo.jpg', existsIn(<String>{})),
        'photo.jpg',
      );
    });

    test('moves to (1) on the first conflict, as FEATURES.md §26 shows', () {
      expect(
        resolveFilenameConflict('photo.jpg', existsIn(<String>{'photo.jpg'})),
        'photo (1).jpg',
      );
    });

    test('keeps counting past a taken (1)', () {
      expect(
        resolveFilenameConflict(
          'photo.jpg',
          existsIn(<String>{'photo.jpg', 'photo (1).jpg'}),
        ),
        'photo (2).jpg',
      );
    });

    test('does not land on a suffixed name that already exists', () {
      // The conflict sequence must consult the destination every time, or it
      // would hand the receiver a name that overwrites an older transfer
      // (`AGENTS.md` §29, `FEATURE.md` §29).
      expect(
        resolveFilenameConflict(
          'photo.jpg',
          existsIn(<String>{'photo.jpg', 'photo (1).jpg', 'photo (2).jpg'}),
        ),
        'photo (3).jpg',
      );
    });

    test('preserves the extension exactly, case included', () {
      expect(
        resolveFilenameConflict('PHOTO.JPG', existsIn(<String>{'PHOTO.JPG'})),
        'PHOTO (1).JPG',
      );
    });

    test('suffixes a name that has no extension', () {
      expect(
        resolveFilenameConflict('report', existsIn(<String>{'report'})),
        'report (1)',
      );
    });

    test('treats a leading dot as part of the name, not an extension', () {
      // `.env (1)` keeps the file hidden; `.env. (1)` would not be the same
      // name to a shell.
      expect(
        resolveFilenameConflict('.env', existsIn(<String>{'.env'})),
        '.env (1)',
      );
    });

    test('splits before the last dot only, so compound extensions survive', () {
      expect(
        resolveFilenameConflict(
          'archive.tar.gz',
          existsIn(<String>{'archive.tar.gz'}),
        ),
        'archive.tar (1).gz',
      );
    });

    test('is deterministic and a pure function of its arguments', () {
      // Nothing outside the arguments may influence the answer: no clock, no
      // global counter, no dependence on the order of a directory listing.
      final Set<String> existing = <String>{'a.txt', 'a (1).txt'};

      String? first;
      for (int run = 0; run < 3; run++) {
        final String resolved = resolveFilenameConflict(
          'a.txt',
          existsIn(existing),
        );
        first ??= resolved;
        expect(resolved, first);
      }
      expect(first, 'a (2).txt');
    });
  });
}
