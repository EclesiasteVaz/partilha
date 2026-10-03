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

**NOT IMPLEMENTED.**

Two previously blocking decisions are now approved:

- wire framing: control in text frames, file bytes in binary frames
  (`docs/PROTOCOL.md` §33.2);
- transport encryption: `wss://` with the certificate fingerprint pinned from
  the QR (`docs/SECURITY.md` §26.1).

Still blocked on: maximum frame size, the integrity mechanism, the transfer
identifier format, the handshake, the reconnection policy, the concurrency
policy, and the retryability classification. See Open Questions.

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

```text
TransferRepository
    Stream<TransferProgress> send(TransferRequest request)

CancelTransferUseCase
    Future<Result<void, Failure>> call(TransferId id)

StorageValidationService
    Future<Result<StorageStatus, Failure>> check(...)
```

Final contracts are fixed at implementation time and recorded here.

## 18. Application Layer

Owns the queue, retry policy, cancellation, and progress aggregation. Owns no
socket and no filesystem handles.

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

## 21. External Dependencies

```text
dart:io (File, WebSocket, HttpServer)
getit
freezed
```

No file-transfer third-party package. No HTTP client
(`docs/decisions/0004-sem-dio-no-mvp.md`).

## 22. Package Isolation

```text
dart:io WebSocket → WebSocketTransport
```

`dart:io` socket mechanics must not appear in domain, application, or
presentation.

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

- Not implemented.
- No pause/resume.
- No folder transfer.
- No transfer history — the user cannot review past transfers.
- No background transfer: closing the app cancels the transfer.
- Token-based authentication over a possibly plaintext transport.

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
