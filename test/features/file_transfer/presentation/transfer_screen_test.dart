import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/core/theme/theme.dart';
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
  const List<SelectedFile> files = <SelectedFile>[
    SelectedFile(
      name: 'report.pdf',
      path: '/tmp/report.pdf',
      sizeInBytes: 2048,
    ),
  ];

  late FakeFileSelectionService service;
  late TransferController controller;

  setUp(() {
    service = FakeFileSelectionService();
    controller = TransferController(selectFiles: SelectFilesUseCase(service));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: TransferScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the destination name and address', (tester) async {
    controller.setDestination(destination);

    await pump(tester);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('192.168.1.10:4443'), findsOneWidget);
  });

  testWidgets('says so when there is no destination', (tester) async {
    await pump(tester);

    expect(find.textContaining('No device selected'), findsOneWidget);
  });

  testWidgets('invites a selection when nothing is chosen', (tester) async {
    await pump(tester);

    expect(find.text('No files selected yet.'), findsOneWidget);
    expect(find.text('Choose files'), findsOneWidget);
  });

  testWidgets('lists each selected file with its size', (tester) async {
    service.result = const Result<List<SelectedFile>, Failure>.success(files);
    controller.setDestination(destination);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.text('report.pdf'), findsOneWidget);
    // Twice: the row and the running total, which agree because there is one
    // file. Both are correct, so this is not a duplicate-label bug.
    expect(find.text('2.0 KB'), findsNWidgets(2));
  });

  testWidgets('removes a file when its remove button is tapped', (
    tester,
  ) async {
    service.result = const Result<List<SelectedFile>, Failure>.success(files);
    controller.setDestination(destination);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove report.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('report.pdf'), findsNothing);
    expect(find.text('No files selected yet.'), findsOneWidget);
  });

  testWidgets('the remove tooltip names the file it removes', (tester) async {
    // The trailing icon alone tells a screen reader nothing about which file it
    // acts on, so the label is part of the contract (AGENTS.md §50).
    service.result = const Result<List<SelectedFile>, Failure>.success(files);
    controller.setDestination(destination);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove report.pdf'), findsOneWidget);
  });

  testWidgets('renders the failure message when the picker fails', (
    tester,
  ) async {
    service.result = const Result<List<SelectedFile>, Failure>.failure(
      UnknownFailure(userMessage: 'The files could not be opened.'),
    );
    controller.setDestination(destination);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.text('The files could not be opened.'), findsOneWidget);
  });

  testWidgets('never renders a raw exception message', (tester) async {
    service.result = Result<List<SelectedFile>, Failure>.failure(
      UnknownFailure(
        userMessage: 'The files could not be opened.',
        cause: StateError('boom: /Users/someone/secret/report.pdf'),
      ),
    );

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    // The cause holds a filesystem path and must never reach the UI
    // (AGENTS.md §52, §83).
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('offers Add more files once something is chosen', (tester) async {
    service.result = const Result<List<SelectedFile>, Failure>.success(files);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.text('Add more files'), findsOneWidget);
  });

  testWidgets('leaves Send disabled when destination is not paired', (
    tester,
  ) async {
    service.result = const Result<List<SelectedFile>, Failure>.success(files);
    controller.setDestination(destination);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    final Finder send = find.widgetWithText(FilledButton, 'Send');
    expect(send, findsOneWidget);
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    expect(
      find.text('Pair with this device to enable transfer.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the total for the selection', (tester) async {
    service.result =
        const Result<List<SelectedFile>, Failure>.success(<SelectedFile>[
          SelectedFile(name: 'a.bin', path: '/tmp/a.bin', sizeInBytes: 1024),
          SelectedFile(
            name: 'b.bin',
            path: '/tmp/b.bin',
            sizeInBytes: 1024 * 1024,
          ),
        ]);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.text('1.0 MB'), findsWidgets);
  });

  testWidgets('says the total is unknown rather than guessing it', (
    tester,
  ) async {
    service.result =
        const Result<List<SelectedFile>, Failure>.success(<SelectedFile>[
          SelectedFile(name: 'a.bin', path: '/tmp/a.bin', sizeInBytes: 10),
          SelectedFile(name: 'b.bin', path: '/tmp/b.bin', sizeInBytes: null),
        ]);

    await pump(tester);
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.text('Total unknown'), findsOneWidget);
    expect(find.text('Size unknown'), findsOneWidget);
  });

  testWidgets(
    'shows Clear completed button when terminal items exist in queue and calls clearCompleted',
    (tester) async {
      final StreamController<List<TransferItem>> streamController =
          StreamController<List<TransferItem>>.broadcast();
      bool cleared = false;
      final _FakeTransferQueue fakeQueue = _FakeTransferQueue(
        stream: streamController.stream,
        initialItems: <TransferItem>[
          TransferItem(
            request: TransferRequest(
              id: '1',
              destination: destination,
              file: files.first,
            ),
            status: TransferStatus.completed,
          ),
        ],
        onClearCompleted: () => cleared = true,
      );

      controller = TransferController(
        selectFiles: SelectFilesUseCase(service),
        clearCompletedTransfersUseCase: ClearCompletedTransfersUseCase(
          fakeQueue,
        ),
        transferQueue: fakeQueue,
      );

      await pump(tester);

      expect(find.text('Clear completed'), findsOneWidget);
      await tester.tap(find.text('Clear completed'));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      await streamController.close();
    },
  );

  testWidgets('shows Add more files button and queue items simultaneously', (
    tester,
  ) async {
    final StreamController<List<TransferItem>> streamController =
        StreamController<List<TransferItem>>.broadcast();
    final _FakeTransferQueue fakeQueue = _FakeTransferQueue(
      stream: streamController.stream,
      initialItems: <TransferItem>[
        TransferItem(
          request: TransferRequest(
            id: '1',
            destination: destination,
            file: files.first,
          ),
          status: TransferStatus.transferring,
        ),
      ],
    );

    controller = TransferController(
      selectFiles: SelectFilesUseCase(service),
      transferQueue: fakeQueue,
    );

    await pump(tester);

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('Add more files'), findsOneWidget);

    await streamController.close();
  });

  testWidgets('renders disconnect button and tapping it when idle disconnects', (
    tester,
  ) async {
    controller.setDestination(destination);
    await pump(tester);

    expect(find.byTooltip('Disconnect'), findsOneWidget);
    await tester.tap(find.byTooltip('Disconnect'));
    await tester.pumpAndSettle();

    expect(controller.state.destination, isNull);
    expect(find.textContaining('No device selected'), findsOneWidget);
    expect(find.text('Choose another device'), findsOneWidget);
  });

  testWidgets(
    'tapping disconnect with active transfers prompts confirmation',
    (tester) async {
      final StreamController<List<TransferItem>> streamController =
          StreamController<List<TransferItem>>.broadcast();
      final _FakeTransferQueue fakeQueue = _FakeTransferQueue(
        stream: streamController.stream,
        initialItems: <TransferItem>[
          TransferItem(
            request: TransferRequest(
              id: '1',
              destination: destination,
              file: files.first,
            ),
            status: TransferStatus.transferring,
          ),
        ],
      );

      controller = TransferController(
        selectFiles: SelectFilesUseCase(service),
        transferQueue: fakeQueue,
      );
      controller.setDestination(destination);

      await pump(tester);

      await tester.tap(find.byTooltip('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect from device?'), findsOneWidget);
      expect(
        find.text(
          'A file transfer is in progress. Disconnecting will cancel ongoing transfers.',
        ),
        findsOneWidget,
      );

      // Cancel dismissal
      await tester.tap(find.text('Keep connected'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect from device?'), findsNothing);
      expect(controller.state.destination, destination);

      // Confirm disconnect
      await tester.tap(find.byTooltip('Disconnect'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
      await tester.pumpAndSettle();

      expect(controller.state.destination, isNull);
      await streamController.close();
    },
  );
}

class _FakeTransferQueue implements TransferQueue {
  _FakeTransferQueue({
    this.initialItems = const <TransferItem>[],
    Stream<List<TransferItem>>? stream,
    this.onClearCompleted,
  }) : _stream = stream ?? const Stream<List<TransferItem>>.empty();

  final List<TransferItem> initialItems;
  final Stream<List<TransferItem>> _stream;
  final void Function()? onClearCompleted;

  @override
  void enqueue({
    required TransferDestination destination,
    required List<SelectedFile> files,
  }) {}

  @override
  void clearCompleted() {
    onClearCompleted?.call();
  }

  @override
  void cancel(String transferId) {}

  @override
  void reset() {}

  @override
  Future<void> dispose() async {}

  @override
  List<TransferItem> get items => initialItems;

  @override
  Stream<List<TransferItem>> get updates => _stream;
}
