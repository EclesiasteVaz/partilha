# File Transfer

> Derivado de [`FEATURES.md`](../../FEATURES.md) §16–§31.
> Não substitui o master. Onde houver conflito, `FEATURES.md` prevalece.
>
> Este documento é também o local onde a máquina de estados de transferência
> tem de estar escrita, como exigido por `FEATURES.md` §18.

## 1. Purpose

File Transfer is the central data-transfer capability of Partilha.

The MVP supports transferring files between nearby paired devices.

## 2. Scope

Supported:

- individual files;
- multiple files;
- queued transfers;
- progress;
- dynamic transfer speed;
- automatic retry;
- cancellation;
- filename conflict resolution;
- destination storage validation.

Not supported in the MVP:

- folder transfer;
- pause/resume;
- persistent transfer history;
- background transfer;
- persistent known-device history.

## 3. Current Status

**PARTIALLY IMPLEMENTED — selection and the local queue. No bytes are transferred yet.**

Implemented:

- the file selection step, end to end on Android and macOS: contract
  `FileSelectionService`, `PlatformFileSelectionService`, `SelectFilesUseCase`,
  `TransferController` and `TransferScreen`;
- the destination handoff from discovery, as `TransferDestination`;
- multi-file selection, per-file removal and the running total;
- the per-transfer state machine: `TransferStatus` and `TransferItem` enforce
  §8 and §9, including terminal-state enforcement and the rule that only a
  transition to `failed` may carry a failure;
- the application-level queue: `TransferQueue` runs one file at a time in
  selection order, records byte-accurate progress, retries within 3 attempts
  with the approved `1s → 2s` backoff, and cancels queued, active and
  backing-off transfers. Exposed through `QueueTransfersUseCase` and
  `CancelTransferUseCase`, registered in the dependency graph.

The Send action is rendered **disabled** with an explanation rather than hidden,
so the flow does not appear finished when it is not. The queue is therefore
built and tested but not reachable from the UI yet: a send needs the pairing
context, which does not exist (§34).

Partially implemented: receiver scaffolding exists (TransferServer contract +
DartIoTransferServer placeholder) enforcing the framing surface (text/binary
discrimination, 64 KiB guard), and `WebSocketTransferRepository` is a placeholder
that reports no bytes. Not implemented: pairing, the sender over the transport,
the full receiver (control parsing, writing files, storage validation in the
flow), live speed, filename conflicts, and the controller → queue wiring. The
transfer step is behind the same blockers listed below.

Two previously blocking decisions are now approved:

- wire framing: control in text frames, file bytes in binary frames
  (`docs/PROTOCOL.md` §33.2);
- transport encryption: `wss://` with the certificate fingerprint pinned from
  the QR (`docs/SECURITY.md` §26.1).

The transport foundation is now implemented in `core/network`: pinned `wss://`,
the control/data frame split, the 64 KiB limit, and the serialized-transfer
constraint. It depends on no open question, and is covered by integration tests
against a real TLS WebSocket server, including a certificate that is refused when
it does not match the pin.

Still blocked on: the integrity mechanism, the transfer identifier format, the
handshake, the reconnection policy, and the retryability classification. There is
also no receiver to pair with yet, because per-device certificate generation is
itself undecided (`docs/SECURITY.md` §26.1). See Open Questions.

## 4. User Problem

Sending a file over a local network by hand requires an IP address, a port, and
a file server. Partilha removes all of that: select files, pick a device, and the
transfer happens with visible progress.

## 5. User Flow

```text
Select one or more files
   ↓
Pairing already established
   ↓
Enqueue
   ↓
Validate destination storage        ← receiver checks free space first
   ↓
Transfer (streamed, progress reported)
   ↓
Save to Downloads / Transfers
   ↓
Completed
```

Cancellation is available from `queued`, `starting`, and `transferring`.

## 6. Functional Requirements

- transfer individual and multiple files;
- queue them;
- report progress from actual bytes;
- report dynamic transfer speed;
- validate destination storage before starting;
- resolve filename conflicts deterministically without overwriting;
- retry automatically within a bound;
- cancel cleanly and remove partial files.

## 7. Non-Functional Requirements

- memory usage must not scale with file size;
- progress must be derived from real byte counts, never estimated from chunk
  count or elapsed time;
- a single failed file must not terminate the queue;
- no incomplete file may be presented as complete;
- large files must remain usable.

## 8. States

Per-transfer states, as defined by `FEATURES.md` §18:

```text
created
validating
queued
starting
transferring
retrying
completed
failed
cancelled
```

`paused` is deliberately **absent**: pause/resume is out of scope.

## 9. State Transitions

```text
created     → validating
validating  → queued
validating  → failed
queued      → starting
queued      → cancelled
starting    → transferring
starting    → failed
starting    → cancelled
transferring→ completed
transferring→ retrying
transferring→ failed
transferring→ cancelled
retrying    → transferring
retrying    → failed
retrying    → cancelled
```

Terminal states: `completed`, `failed`, `cancelled`.

`completed`, `failed` and `cancelled` must not have outgoing transitions.

Enforced by `TransferItem.canTransitionTo` / `TransferItem.transitionTo`
(`lib/features/file_transfer/domain/transfer_item.dart`), and covered by an
exhaustive test over every state pair, so an edit to the machine cannot drift
from this table. A transition into `failed` must carry a failure; no other
transition may carry one. The queue is the only code that transitions items
(§18), and a refused transition is a no-op rather than an error, because a
race — the user cancelling while a send completes — is normal use (§15, §83 of
`AGENTS.md`).

The queue enqueues items as `queued`, not `created`: the only transition out of
`created` is `validating`, and validation is receiver-side (§12) and unreachable
until the control protocol exists (§34). Creating an item in the state it
actually is avoids a transition that performs nothing.

## 10. Inputs

- a set of selected files with paths and sizes;
- the pairing context from Pairing;
- user cancellation.

File metadata received over the wire is **untrusted** and must be validated
before use.

## 11. Outputs

- files written to the system Downloads / Transfers location;
- progress, speed, and state updates;
- typed failures.

## 12. Validation

Receiver-side, before any bytes are accepted:

- **storage validation**: sufficient free space must exist. If not, the transfer
  must not start at all.
- filename safety: reject names containing path separators, traversal segments,
  or control characters;
- declared size must be consistent with what is actually received;
- completed-file integrity must be verified before the file is presented as
  successful.

Never begin a transfer and discover insufficient storage after partially
writing the file.

## 13. Success Behavior

The file is fully written to the destination, integrity is confirmed, and the
transfer state becomes `completed`.

After successful receipt:

- save the file;
- do **not** automatically open it;
- do **not** introduce notifications unless explicitly specified;
- do **not** create transfer history unless explicitly specified.

## 14. Failure Behavior

Failures are typed and explicit. Retryable and non-retryable must be
distinguished:

| Failure | Retryable |
|---|---|
| transient network failure | yes |
| connection dropped mid-transfer | yes |
| insufficient storage | **no** — never start |
| invalid token / rejected by peer | **no** |
| filename rejected as unsafe | **no** |
| peer unavailable after pairing | depends on cause — **OPEN** |

The UI must distinguish, where appropriate: loading, success, failure,
cancelled, retrying, insufficient storage, permission denied, and unavailable
device.

Raw exception messages must not be shown to users.

## 15. Cancellation Behavior

Cancellation must, in order:

1. stop the active transfer;
2. stop streaming;
3. **delete the partial destination file**;
4. update the state to `cancelled`.

Leaving a corrupted or incomplete file in the user's Downloads directory is not
acceptable.

Cancellation must be immediate from the application's perspective.

## 16. Architecture

```text
TransferController (presentation)
        ↓
QueueTransfersUseCase / CancelTransferUseCase (application)
        ↓
TransferRepository (domain contract) + TransferQueue
        ↓
WebSocketTransferRepository (data)
        ↓
WebSocketTransport → dart:io WebSocket
        ↓
dart:io File streams
```

Implemented today:

```text
TransferScreen (presentation)
        ↓
TransferController (presentation)     ← selection only; Send is disabled
        ↓
SelectFilesUseCase (application)
        ↓
FileSelectionService (domain contract)
        ↓
PlatformFileSelectionService (data) → file_picker


TransferQueue (application)           ← order, retry, cancel, progress
        ↓
SendFileUseCase (application)
        ↓
TransferRepository (domain contract)
        ↓
WebSocketTransferRepository (data)    ← placeholder: reports no bytes
```

`QueueTransfersUseCase` and `CancelTransferUseCase` sit between the controller
and the queue, and all of it is registered in the dependency graph. What is
missing is the last link: the controller does not call the queue yet, because a
send needs the pairing context and the handshake, both still open (§34).

The destination arrives as `TransferDestination`, projected from the discovery
entity by the discovery screen. The projection is deliberate: transfer must not
depend on `capabilities`, which is untrusted advertised metadata
(`features/discovery/FEATURE.md` §26). It keeps the dependency one-directional —
discovery knows about transfer, transfer knows nothing about discovery.

Separation required by `docs/PROTOCOL.md` §38:

```text
Transfer Queue
      ↓
Transfer Application Service
      ↓
Protocol / Communication Contract
      ↓
Transport
```

The queue is an application concern and must **not** live inside the transport
client.

## 17. Domain Contracts

Implemented:

```text
TransferDestination
    deviceId, deviceName, address, port

SelectedFile
    name, path, sizeInBytes (int? — null when the platform does not report it)

FileSelectionService
    Future<Result<List<SelectedFile>, Failure>> pickFiles()

TransferRequest
    id, destination, file, type — one unit of send work

TransferStatus / TransferItem
    the per-transfer state machine (§8, §9), immutable, with byte progress

TransferRepository
    Stream<FileTransferProgress> send(TransferRequest request)

FileTransferProgress
    transferId, bytesTransferred, totalBytes

QueueTransfersUseCase
    Future<Result<void, Failure>> call({destination, files})
    — empty selection is a ValidationFailure, not a silent success

CancelTransferUseCase
    void call(String transferId)
    — idempotent; unknown or already-terminal ids are no-ops

StorageValidationService
    Future<Result<StorageStatus, Failure>> check(...)
```

`TransferRequest.id` is a local queue identifier, not a wire identifier: the
transfer id format is open (§34).

`StorageValidationService` has a `DartIoStorageValidationService` placeholder,
but is not called from the send path yet — storage validation is receiver-side
(§12) and depends on the control protocol.

Not yet implemented:

```text
the sender over WebSocketTransport
the receiver control layer (parsing, writing files, filename conflicts)
```

Final contracts are fixed at implementation time and recorded here.

`pickFiles` returns an **empty list when the user cancels**. Cancellation is an
explicit choice, not an error, so the controller leaves the existing selection
untouched rather than clearing it (`AGENTS.md` §28, §83).

## 18. Application Layer

Owns the queue, retry policy, cancellation, and progress aggregation. Owns no
socket and no filesystem handles.

Implemented as `TransferQueue`:

- **order**: one file at a time, in selection order; the next file starts only
  when the previous one is terminal (`FEATURES.md` §23 — a failed file is
  marked and the queue moves on);
- **state ownership**: the queue is the only code that transitions a
  `TransferItem` (§9), and it publishes an immutable snapshot of the whole
  queue after every change;
- **progress**: taken from the repository's real byte counts, never estimated
  (§20 of `AGENTS.md`); an item whose size is unknown keeps a `null` total;
- **retry**: up to 3 attempts per file, backoff `1s → 2s`, driven by
  `Failure.isRetryable` rather than by catching every exception — a
  non-retryable failure fails the file at once and the queue continues;
- **early close is a failure**: a stream that ends before the declared size is
  `TransferFailure.connectionLost`, not a completed file (§7, §14);
- **cancellation**: reachable from `queued`, `starting`, `transferring` and
  `retrying`; it releases the active subscription, wins over a backoff that is
  already running, and is a no-op for unknown or terminal ids (§15).

The retry delay is injectable so tests assert the approved backoff without
spending three real seconds.

Not yet implemented here: speed calculation, storage validation before a send
(receiver-side, §12), and the controller → queue wiring (§3).

## 19. Data Layer

- owns `dart:io` file streams and `WebSocketTransport`;
- converts `SocketException` and `FileSystemException` into failures;
- performs storage validation against the destination filesystem;
- applies the deterministic filename conflict policy.

## 20. Presentation Layer

- `TransferController` (ChangeNotifier) with immutable Freezed state;
- queue list with per-file state, progress and speed;
- explicit failure, retrying, cancelled and insufficient-storage rendering;
- `ListenableBuilder` binding, controllers from GetIt.

Implemented today:

- `TransferController` with immutable Freezed `TransferState`, bound through
  `ListenableBuilder`, resolved from GetIt;
- `TransferScreen`: destination, file list with per-file removal, running total,
  failure banner, and a disabled Send action with an explanation;
- `TransferSetupStatus` covers only `initial`, `selectingFiles`, `ready` and
  `error`, because those are the only states that exist. `sending`, `completed`
  and `cancelled` are not declared until there is behaviour behind them
  (`AGENTS.md` §89). The name is deliberately `TransferSetupStatus`, not
  `TransferStatus`: the per-transfer lifecycle of §8 is owned by the domain
  (`TransferStatus`), and one name must not mean two things.

`TransferController` is a `lazySingleton`, unlike the other controllers in the
app. It is the only holder of the destination and the selection: discovery sets
the destination and the transfer screen reads it, so a factory per screen would
drop the selection on every rebuild (`AGENTS.md` §11, §80).

Accessibility: the failure banner is a live region, the per-file remove control
names the file it removes, and the total is announced as bytes rather than read
as a stray formatted string (§50).

## 21. External Dependencies

```text
dart:io (File, WebSocket, HttpServer)
getit
freezed
file_picker (file selection only)
```

No file-transfer third-party package — `file_picker` opens a dialog and returns
paths; it does not move bytes. No HTTP client
(`docs/decisions/0004-sem-dio-no-mvp.md`).

`file_picker` is recorded in
`docs/decisions/0007-file-picker-para-escolha-de-ficheiros.md`, including why
the official `file_selector` was rejected: on Android it loads the whole file
into memory, which this feature cannot do (§19, §21).

## 22. Package Isolation

```text
dart:io WebSocket → WebSocketTransport
file_picker       → FileSelectionService
```

`dart:io` socket mechanics must not appear in domain, application, or
presentation.

`PlatformFileSelectionService` is the only file that imports `file_picker`.
Presentation asks for a `FileSelectionService` and never sees
`FilePicker` or `PlatformFile` (`AGENTS.md` §22, §51).

`withData` must stay off. It makes the picker return file content as bytes,
which on Android is the whole file in RAM (`AGENTS.md` §21).

## 23. Persistence

**None.**

Transfer state is ephemeral application state. Do not create a table for it.

The persistence question that must always be asked:

> Does this information need to survive application termination?

For transfers, the answer is no.

## 24. Platform Considerations

- Android and macOS are priority targets.
- destination location is the system Downloads / Transfers location; do not
  invent a custom location;
- macOS requires the necessary entitlement for user-selected or Downloads
  paths;
- file handles must be closed deterministically on every path, including
  cancellation.

Resolved in this change:

- **macOS**: `com.apple.security.files.user-selected.read-only` is now declared
  in both `macos/Runner/DebugProfile.entitlements` and
  `macos/Runner/Release.entitlements`, and
  `com.apple.security.network.server` in `Release.entitlements`. Without the
  first one the picker cannot read what the user selected.

Outstanding, and **not** covered by this change:

- **macOS**: `com.apple.security.network.client` is still absent from both
  entitlements files. Discovery advertising and an outbound transfer will be
  refused by the sandbox until it is added. It is deliberately not added here,
  because it is not needed for file selection and §24 requires a platform
  requirement to be registered with the change that introduces the behaviour that
  needs it.

Android file selection behaviour, inherited from the package and recorded in
`docs/decisions/0007-file-picker-para-escolha-de-ficheiros.md`:

- the plugin caches each selected file into `cacheDir/file_picker/` and returns
  that path. Memory stays flat because the copy is streamed in 8 KiB blocks;
- peak disk use during selection is roughly twice the size of the selection;
- `clearTemporaryFiles()` exists and is the supported cleanup path. Nothing calls
  it yet, because nothing owns a transfer that would clean up after itself — that
  belongs with the queue and cancellation;
- a cache copy that fails is dropped from the result with no error, so a
  selection can be shorter than what the user picked and the data layer cannot
  detect it.

## 25. Performance Requirements

**Streaming is mandatory.**

```text
File
 ↓
Stream<List<int>>
 ↓
Network
 ↓
Progressive write
 ↓
Destination file
```

Required:

- never `readAsBytes()` a whole large file;
- avoid intermediate copies;
- apply stream backpressure; never buffer an entire payload;
- progress = `bytesTransferred / totalBytes`;
- speed derived from actual transfer activity, not constants.

## 26. Security Requirements

- filenames from the network are untrusted: reject traversal and separators;
- transferred file content is never executed or interpreted;
- no incomplete file is exposed as complete;
- destination writes are confined to the approved directory;
- the token is validated before any transfer operation;
- transport may be plaintext — see `docs/SECURITY.md` §26.1, **OPEN**;
- frame and message size limits must be enforced so a hostile peer cannot
  exhaust memory.

## 27. Accessibility Requirements

- progress must be announced through semantics, not only a visual bar;
- state changes (queued, transferring, retrying, completed, failed, cancelled)
  must be announced to assistive technology;
- failure must not be conveyed by color alone;
- each queue row needs an accessible name and an accessible cancel control;
- speed and remaining-time text must scale with text size;
- status must remain understandable with animations disabled.

## 28. Edge Cases

- destination already contains the filename → generate a new one, never
  overwrite;
- filename with no extension, or with multiple extensions;
- zero-byte file;
- file changes size during transfer → declared vs actual mismatch;
- disk full mid-transfer despite passing pre-validation → remove the partial
  file;
- user cancels during retry backoff;
- peer disconnects mid-transfer;
- connection drops repeatedly and the retry budget is exhausted;
- queue with 50 items and several failures;
- device goes to sleep mid-transfer;
- filename conflict numbering must remain deterministic and not collide with an
  existing `photo (1).jpg`.

## 29. Testing Requirements

**Unit**

- state machine transitions, including terminal-state enforcement;
- retry policy: attempt count, backoff `1s → 2s`, and non-retryable bypass;
- progress and speed calculation;
- filename conflict resolution, including pre-existing suffixed names;
- cancellation cleanup.

**Integration**

- real file transfer over a real WebSocket between two processes or devices;
- large-file streaming with memory held flat;
- storage validation against a real filesystem;
- cancellation mid-transfer leaves no partial file;
- queue continues after an individual failure.

**UI**

- queue states render distinctly;
- progress is announced;
- failure reasons are specific and actionable;
- cancellation is reachable.

## 30. Known Limitations

- **No bytes are transferred.** Selection and the local queue are implemented
  (§3), but `WebSocketTransferRepository` is a placeholder and the Send action
  is disabled, so no file leaves the device.
- **The queue is not reachable from the UI.** `TransferQueue`,
  `QueueTransfersUseCase` and `CancelTransferUseCase` exist, are registered and
  are tested, but `TransferController` does not call them yet — a send needs the
  pairing context and the handshake, both open (§34).
- **Items are born `queued`, never `created` or `validating`.** Receiver-side
  storage validation (§12) needs the control protocol, so the two leading
  states of §8 exist in the state machine but are never entered (§9).
- No pause/resume.
- No folder transfer.
- No transfer history — the user cannot review past transfers.
- No background transfer: closing the app cancels the transfer.
- Token-based authentication over a possibly plaintext transport.
- **A file's size can be unknown.** The picker reports a size only for some
  providers, and `SelectedFile.sizeInBytes` is therefore `int?`. The total is
  `null` rather than a partial sum, and progress will have to be shown as
  indeterminate until a total is known. It is never estimated (§20).
- **Android duplicates the selection on disk.** The picker caches each selected
  file before returning its path. Peak disk use during selection is roughly twice
  the selection, and there is no progress indication for the copy — only
  `picking`/`done` from the plugin.
- **A failed cache copy silently drops a file on Android.** The plugin returns
  `null` for it, so the returned list can be shorter than what the user picked
  and this layer has no way to detect it. Surfacing it would require the
  platform API to report how many files were asked for.
- **Caches are not cleaned yet.** `clearTemporaryFiles()` is available but
  nothing calls it, so the copies live until the OS reclaims the cache
  directory. The cleanup belongs with the queue and cancellation, which own the
  lifecycle of a transfer.

## 31. Out of Scope

- folder transfer;
- pause/resume;
- persistent transfer history;
- background transfer and OS transfer daemons;
- known-device management;
- cloud relay;
- resume-after-reconnect across app restarts.

## 32. Future Work

- pause/resume;
- folder transfer;
- transfer history;
- background transfer;
- advanced transfer controls;
- stronger transport authentication.

None is scheduled.

## 33. Architectural Decisions

| Decision | Where |
|---|---|
| Raw WebSocket over `dart:io`, no third-party networking package | `docs/decisions/0001-transporte-websocket-dart-io.md` |
| Streaming, never whole-file buffering | `AGENTS.md` §19, §21 |
| 3 attempts, backoff `1s → 2s` | `FEATURES.md` §24 |
| Queue is application-level, not transport-level | `docs/PROTOCOL.md` §38 |
| No HTTP client in MVP | `docs/decisions/0004-sem-dio-no-mvp.md` |
| `file_picker` for file selection, behind a project-owned contract | `docs/decisions/0007-file-picker-para-escolha-de-ficheiros.md` |
| A separate `send` feature was rejected; the flow belongs to file_transfer | `FEATURES.md` §5, `AGENTS.md` §6 |

## 34. Open Questions

Resolved:

- wire framing: control in text frames, file bytes in binary frames
  (`docs/PROTOCOL.md` §33.2);
- a text frame during a file stream is a protocol violation (§33.3);
- maximum frame size: 64 KiB fixed, rejected before buffering (§33.4);
- ordering: send order, guaranteed by the underlying stream (§33.5);
- concurrency: serialized, one at a time on a single connection (§33.6);
- transport encryption: `wss://` with the DER SHA-256 fingerprint pinned from
  the QR, cipher suites left to platform defaults
  (`docs/SECURITY.md` §26.1).

Still **OPEN — APPROVAL REQUIRED**:

- the exact transfer identifier format;
- the connection handshake, and how the token is presented;
- the integrity mechanism: checksum algorithm, and whether it is mandatory;
- whether a dropped connection during an active transfer is automatically
  resumed or requires a fresh pairing;
- the retryability classification for "peer unavailable after pairing".

The exact message names and JSON envelope remain open in `docs/PROTOCOL.md`
§41.1 and §41.2, and gate the control-message layer.

File Transfer implementation may now begin, bounded by the items above. The
transport foundation — connection establishment with pinning, frame
classification, and the frame size limit — depends on none of them and can be
built first.
