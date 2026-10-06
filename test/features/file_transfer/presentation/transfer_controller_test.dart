import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/application/application.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/presentation.dart';

import '../domain/fake_file_selection_service.dart';

void main() {
  const TransferDestination destination = TransferDestination(
    deviceId: 'id-1',
    deviceName: 'Alice',
    address: '192.168.1.10',
    port: 4443,
  );
  const List<SelectedFile> twoFiles = <SelectedFile>[
    SelectedFile(name: 'a.txt', path: '/tmp/a.txt', sizeInBytes: 10),
    SelectedFile(name: 'b.txt', path: '/tmp/b.txt', sizeInBytes: 32),
  ];

  late FakeFileSelectionService service;
  late TransferController controller;

  setUp(() {
    service = FakeFileSelectionService();
    controller = TransferController(selectFiles: SelectFilesUseCase(service));
  });

  test('starts empty, before anything has been chosen', () {
    expect(controller.state.status, TransferStatus.initial);
    expect(controller.state.destination, isNull);
    expect(controller.state.files, isEmpty);
    expect(controller.totalBytes, 0);
  });

  group('setDestination', () {
    test('records the destination', () {
      controller.setDestination(destination);

      expect(controller.state.destination, destination);
    });

    test('notifies listeners', () {
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.setDestination(destination);

      expect(notifications, 1);
    });

    test('leaves the status alone, because a destination is not readiness', () {
      controller.setDestination(destination);

      // Readiness depends on having files, not on naming a device; letting this
      // flip to `ready` would enable Send with an empty queue.
      expect(controller.state.status, TransferStatus.initial);
    });
  });

  group('pickFiles', () {
    test('publishes selectingFiles while the picker is open', () async {
      TransferStatus? seenDuringPick;
      controller.addListener(() {
        if (controller.state.status == TransferStatus.selectingFiles) {
          seenDuringPick = controller.state.status;
        }
      });

      await controller.pickFiles();

      expect(seenDuringPick, TransferStatus.selectingFiles);
    });

    test('adopts the selection and becomes ready', () async {
      service.result = const Result<List<SelectedFile>, Failure>.success(
        twoFiles,
      );

      await controller.pickFiles();

      expect(controller.state.status, TransferStatus.ready);
      expect(controller.state.files, twoFiles);
    });

    test('sums the selected sizes', () async {
      service.result = const Result<List<SelectedFile>, Failure>.success(
        twoFiles,
      );

      await controller.pickFiles();

      expect(controller.totalBytes, 42);
    });

    test('reports an unknown total when any size is unknown', () async {
      // Adding up only the sizes that happen to be known would produce a
      // plausible-looking total that is wrong, and progress built on it would
      // overstate the denominator (features/file_transfer/FEATURE.md §20).
      service.result =
          const Result<List<SelectedFile>, Failure>.success(<SelectedFile>[
            SelectedFile(name: 'a.txt', path: '/tmp/a.txt', sizeInBytes: 10),
            SelectedFile(name: 'b.txt', path: '/tmp/b.txt', sizeInBytes: null),
          ]);

      await controller.pickFiles();

      expect(controller.totalBytes, isNull);
    });

    test('a cancelled picker leaves an existing selection alone', () async {
      service.result = const Result<List<SelectedFile>, Failure>.success(
        twoFiles,
      );
      await controller.pickFiles();

      service.result = const Result<List<SelectedFile>, Failure>.success(
        <SelectedFile>[],
      );
      await controller.pickFiles();

      // Treating a cancel as "empty selection" would silently discard files the
      // user had already chosen, which contradicts their intent (§28).
      expect(controller.state.files, twoFiles);
      expect(controller.state.status, TransferStatus.ready);
    });

    test('a failure surfaces the failure and keeps the selection', () async {
      service.result = const Result<List<SelectedFile>, Failure>.success(
        twoFiles,
      );
      await controller.pickFiles();

      service.result = const Result<List<SelectedFile>, Failure>.failure(
        UnknownFailure(userMessage: 'The files could not be opened.'),
      );
      await controller.pickFiles();

      expect(controller.state.status, TransferStatus.error);
      expect(controller.state.error, isNotNull);
      expect(
        controller.state.error!.userMessage,
        'The files could not be opened.',
      );
      expect(controller.state.files, twoFiles);
    });

    test('a later success clears a previous error', () async {
      service.result = const Result<List<SelectedFile>, Failure>.failure(
        UnknownFailure(),
      );
      await controller.pickFiles();
      expect(controller.state.error, isNotNull);

      service.result = const Result<List<SelectedFile>, Failure>.success(
        twoFiles,
      );
      await controller.pickFiles();

      expect(controller.state.error, isNull);
    });

    test('opens the picker once per call', () async {
      await controller.pickFiles();

      expect(service.callCount, 1);
    });
  });

  group('removeFile', () {
    setUp(() async {
      service.result = const Result<List<SelectedFile>, Failure>.success(
        twoFiles,
      );
      await controller.pickFiles();
    });

    test('drops only the named file', () {
      controller.removeFile(twoFiles.first);

      expect(controller.state.files, <SelectedFile>[twoFiles.last]);
    });

    test('recomputes the total', () {
      controller.removeFile(twoFiles.first);

      expect(controller.totalBytes, 32);
    });

    test('returns to not-ready when the last file goes', () {
      controller
        ..removeFile(twoFiles.first)
        ..removeFile(twoFiles.last);

      // Send must never be reachable with an empty queue.
      expect(controller.state.status, TransferStatus.initial);
      expect(controller.state.files, isEmpty);
    });
  });
}
