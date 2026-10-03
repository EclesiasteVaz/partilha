# Partilha Protocol

## 1. Purpose

This document defines the application-level communication protocol used by Partilha.

It is the source of truth for:

- device discovery metadata;
- pairing;
- connection establishment;
- capability negotiation;
- transfer lifecycle;
- transfer progress;
- cancellation;
- retry-related communication;
- protocol errors;
- message serialization;
- transport boundaries.

The protocol must be implemented exactly as documented.

If implementation requires behavior that is not defined here, the Agent MUST NOT invent it. The missing behavior must be identified and explicitly approved before implementation.

---

# 2. Protocol Scope

The Partilha MVP supports nearby device-to-device file transfer.

The expected high-level flow is:

```text
Discovery
    ↓
Device Selection
    ↓
Pairing / Connection
    ↓
Capability Exchange
    ↓
Transfer Request
    ↓
Transfer
    ↓
Completion
```

The protocol does not define:

- user accounts;
- cloud synchronization;
- remote internet transfers;
- persistent known-device registries;
- push notifications;
- background transfers;
- folder transfers;
- pause/resume;
- persistent transfer history;
- application-level user authentication;
- a server-side account system.

---

# 3. Protocol Principles

## 3.1 Explicit contracts

Every message exchanged between devices must have:

- a clearly defined message type;
- a defined JSON representation;
- required fields;
- optional fields where applicable;
- validation rules;
- defined error behavior.

Unknown or malformed messages must not be silently interpreted as valid messages.

---

## 3.2 JSON messages

Application-level control messages use JSON.

Typed Dart models should represent protocol messages in the application.

Serialization and deserialization should use the project's established code-generation approach where appropriate:

- `freezed`;
- `json_serializable`.

Raw JSON maps must not leak unnecessarily into domain/application logic.

---

## 3.3 No protocol versioning in MVP

The MVP does **not** introduce protocol versioning.

Do not create:

```text
protocolVersion
version
schemaVersion
```

or equivalent fields unless this document is explicitly changed.

The Agent must not invent protocol compatibility logic.

Protocol versioning may be introduced in a future protocol revision.

---

# 4. Transport Boundary

The application protocol must remain independent from the underlying transport implementation.

The architecture must allow the transport implementation to be changed without rewriting domain logic.

The application should communicate through project-owned abstractions.

For example:

```text
Domain / Application
        ↓
Project-owned communication contract
        ↓
Transport implementation
        ↓
dart:io WebSocket
```

The transport must not become part of domain models or business logic.

A transport implementation uses raw `dart:io` sockets, but protocol messages
belong to Partilha rather than to any third-party messaging package.

See `docs/decisions/0001-transporte-websocket-dart-io.md`.

---

# 5. Connection Model

Partilha uses nearby device discovery followed by a direct connection.

The receiver device exposes connection information.

The sender discovers the receiver and uses the advertised information to establish communication.

The expected flow is:

```text
Receiver
    │
    ├── Starts discovery advertisement
    │
    │
    ▼
Sender
    │
    ├── Searches for nearby devices
    │
    ├── Selects receiver
    │
    ├── Uses connection information
    │
    └── Establishes connection
```

The exact transport-level connection sequence must remain isolated from application-level protocol handling.

---

# 6. Device Identity

Each installation/device has a persistent device identity.

The device identity is different from the user's display name.

Conceptually:

```text
deviceId
deviceName
token
```

### `deviceId`

A stable identifier for the Partilha installation/device.

It must persist across normal application restarts.

### `deviceName`

A user-defined name displayed to other devices.

Example:

```text
Eclesiaste MacBook
```

The device name must be persisted.

### `token`

A persistent device token used as part of the current MVP pairing/connection model.

The token must not be treated as a user password.

The exact generation and secure-storage implementation must follow the approved security specification.

---

# 7. Discovery

## 7.1 Discovery technology

Nearby discovery uses mDNS.

The implementation must be isolated behind a project-owned discovery abstraction.

Example:

```text
DiscoveryService
    ↓
MdnsDiscoveryService
    ↓
mDNS package / platform implementation
```

The domain layer must not depend on the mDNS package.

---

## 7.2 Receiver advertisement

A device acting as a receiver advertises itself through mDNS.

The advertisement must provide enough information for another Partilha installation to identify and connect to it.

The discovery metadata conceptually contains:

```text
deviceId
deviceName
host/address
port
capabilities
```

**The token is deliberately absent from discovery metadata.**

mDNS records are transmitted in plaintext and are readable by every host on
the local network. Advertising the token would allow any neighbouring device
to harvest it and impersonate this device, which contradicts the approved
security model in `docs/SECURITY.md`. The token travels only through the QR
code. See `docs/decisions/0003-token-fora-do-mdns.md`.

### 7.2.1 Service type and TXT keys: PROPOSTO

**This section is a proposal. It is not approved, and the implementation must not
treat it as a contract until it is.**

```text
service type   _partilha._tcp.local.
```

`_tcp` rather than a bespoke type such as `_partilha-share._tcp`: the protocol
needs discovery and a port, and `_tcp` already means exactly that to every
resolver on the network. A bespoke type buys nothing and makes the service
invisible to standard tooling, which is the one thing worth having here.

TXT keys:

| Key | Carries | Rule |
|---|---|---|
| `name` | human-readable device name | user-defined, never derived from a hostname (§34) |
| `id` | stable device identifier | opaque to peers, never a token (§7.2) |

Two keys, and no more. `host` and `port` already have their own records (SRV and
A/AAAA), so duplicating them in TXT would create two sources of truth for the
same fact. Capabilities are proposed separately in §7.3.

Both keys are **required**. An advertisement missing either is rejected rather
than defaulted: `name` falling back to the DNS hostname would leak the machine's
name onto the network, which is the leak §34 exists to prevent.

**Evidence from the spike.** These values are not arbitrary. `mdns_dart` has
advertised `_partilha._tcp.local.` with TXT `name`/`id` on a real macOS network,
and Apple's own resolver — `/usr/bin/dns-sd`, which shares no code with the
library — discovered it, resolved the SRV to the right port and read the TXT
records. See `docs/decisions/0002-mdns-provider.md`. What is *not* proven is
Android, where the spike is still unticked.

**Still to approve:** the service type itself, and whether a missing key rejects
the record rather than defaulting.

### 7.3 Discovery metadata is untrusted input

Discovered metadata is **public, attacker-controllable input**.

A malicious host on the same network can announce arbitrary service names,
host addresses, ports, capabilities, and device names. Discovery therefore
provides **no** identity, integrity, or authenticity guarantee.

Consequences for implementation:

- never log the raw record contents verbatim beyond what is needed;
- never trust `deviceId` as proof of identity;
- never treat a resolved address as safe;
- always validate field lengths and types before use;
- never allow metadata to influence file paths directly;
- treat `deviceName` as display-only and escape it at render time.

Discovery is a **convenience mechanism**, never an authentication mechanism.
Pairing (see section 8) is what establishes trust.

---

# 8. QR Connection Information

Partilha supports QR-based connection information.

The QR payload contains the information necessary to establish a connection.

The approved conceptual payload contains:

```text
deviceId
deviceName
host/address
port
token
capabilities
protocol-related connection information
```

The QR code is the **only** approved channel that may carry the token.

The QR payload must represent structured data rather than an undocumented concatenated string.

Example conceptual representation:

```json
{
  "deviceId": "...",
  "deviceName": "...",
  "host": "...",
  "port": 0000,
  "token": "...",
  "certificateFingerprint": "...",
  "capabilities": []
}
```

`certificateFingerprint` is **required**, not optional. It was added as a direct
consequence of approving `wss://` with a pinned certificate
(`docs/SECURITY.md` §26.1): the sender must be able to verify the certificate
*before* it sends the token, and the QR is the only channel that reaches the
sender before a connection exists.

Two properties follow, and both matter:

- The fingerprint travels in the QR alongside the token, so it inherits the
  QR's protection. It is never sent over the connection, so a passive
  eavesdropper on a later connection learns nothing that helps them impersonate
  the device.
- Because the fingerprint arrives out-of-band, pinning has **no trust-on-first-
  use window**. There is no first connection during which an attacker could
  substitute their own certificate. This is the reason the design was chosen
  over TOFU.

This changes the QR payload contract and therefore affects interoperability
between versions. It is recorded here as an approved consequence of the
transport-encryption decision rather than as a separate invention; a change that
contradicts it must be approved separately.

This example is illustrative only.

The exact final field names and validation rules must be defined by the protocol implementation.

Do not add protocol-version fields.

---

# 9. Pairing

Pairing establishes the relationship required for two devices to communicate for a transfer.

The current MVP uses the persistent device token as part of the connection/pairing model.

The pairing process must validate the connection information before allowing transfer operations.

Conceptually:

```text
Device A
   │
   │ connection information
   ▼
Device B
   │
   │ validate identity/token
   ▼
Connection accepted
```

A connection that cannot be validated must not proceed to file transfer.

---

# 10. Capability Information

Devices may advertise capabilities.

Capabilities allow the sender to understand what operations the receiving device supports.

Capabilities must describe actual supported behavior.

Do not advertise functionality that the current implementation cannot execute.

Examples of potential capability categories include:

```text
file-transfer
multiple-files
```

These are examples, not an approved exhaustive list.

### 7.3.1 Capability identifiers: PROPOSTO

**This section is a proposal. It is not approved.**

```text
capability   value
```

Where capability is a single flag whose presence is the whole signal. A
capability set is a set of keys; a key that is absent is a capability the device
does not have.

Proposed for the MVP:

| Identifier | Meaning |
|---|---|
| `file-transfer` | this device can receive files |

That is deliberately the whole list. `AGENTS.md` §35 forbids advertising
functionality the implementation cannot execute, and there is exactly one
capability the MVP has. `multiple-files` appears in this section as an example
and is **not** proposed: §25 says the MVP supports multiple selection, but that
is a receiver-side behaviour, and a sender cannot verify it before connecting.
Advertising it would mean asserting something unverified.

**Alternative not chosen — versioned values.** `file-transfer=2` style values
imply a compatibility scheme this protocol does not have (§38: no protocol
versioning). A capability is present or absent; when its behaviour changes
materially, the identifier changes.

**Still to approve:** whether capabilities exist in the MVP at all. The sender
can discover a device and try to connect; if the MVP has one capability, the
field earns its place only if a future feature needs it.

The Agent must not create an extensive capability registry without approval.

---

# 11. Message Model

All application-level control messages must have an explicit message type.

Conceptually:

```json
{
  "type": "...",
  "...": "..."
}
```

The `type` field identifies the message.

Each message type must have a corresponding typed representation in the codebase.

Do not create a generic message object containing arbitrary business data.

---

# 12. Required Message Categories

The MVP protocol requires message categories for:

1. connection/pairing;
2. capability exchange;
3. transfer request;
4. transfer acceptance/rejection;
5. transfer progress;
6. transfer completion;
7. transfer cancellation;
8. transfer failure/error.

The exact message names and payload schemas must be finalized before implementation.

---

# 13. Transfer Request

A transfer request represents the sender asking the receiver to accept one or more files.

The request must contain enough metadata for the receiver to understand what is being requested before data transmission begins.

At minimum, the transfer model must support:

- individual files;
- multiple files;
- file name;
- file size.

Conceptually:

```text
Transfer
 ├── transfer identifier
 └── files
      ├── file identifier
      ├── file name
      └── file size
```

The protocol must not require loading file contents into memory to construct a transfer request.

---

# 14. Transfer Acceptance

The receiver must explicitly accept or reject a transfer request before file data transmission begins.

Possible outcomes include:

```text
accepted
rejected
```

### 14.1 Error representation: APPROVED

**Errors are a dedicated `error` message, not a field on every response.**

```json
{
  "type": "error",
  "id": "t-1",
  "payload": { "code": "insufficient_storage", "message": "..." }
}
```

`id` refers to the request being answered, so the sender knows which transfer the
failure belongs to. A dedicated message keeps `payload` free of error shapes, so
each message type validates one structure instead of two, and lets the receiver
handle a failure the same way regardless of which request produced it.

### 14.2 Error codes: APPROVED

The set is deliberately minimal. Each code maps to exactly one `Failure`
constant that already exists in the codebase, which is what makes this a
derivation rather than an invented taxonomy:

| Code | Failure constant | Required by |
|---|---|---|
| `invalid_message` | `TransferFailure.protocolViolation` | §28 malformed messages |
| `not_paired` | `PairingFailure.rejected` | §37 pairing, token not accepted |
| `transfer_rejected` | `TransferFailure.remoteRejected` | §14 the user declined the offer |
| `insufficient_storage` | `StorageFailure.insufficientSpace` | §22 storage validation |
| `unsupported` | `TransferFailure.remoteRejected` | §10 capability mismatch |

`cancelled` is deliberately **absent**: cancellation is its own message type, not
an error, and encoding it twice would leave two ways to say the same thing.

Adding a code requires approval, because the peer must understand it to react to
it. An unrecognised code from a future peer is handled by §27.1.

---

# 15. File Transfer

File contents must be transferred as a stream.

The implementation must not load an entire file into memory.

Conceptually:

```text
File
 ↓
Read Stream
 ↓
Transport
 ↓
Write Stream
 ↓
Destination File
```

Transfer progress is calculated from actual bytes transferred.

```text
progress = bytesTransferred / totalBytes
```

The UI must not depend on arbitrary percentage increments or simulated progress.

---

# 16. Multiple Files

A transfer may contain multiple files.

Each file must have its own identifiable transfer state.

Conceptually:

```text
Transfer
 ├── File A
 ├── File B
 └── File C
```

The transfer system must be capable of identifying which file is currently transferring.

If one file fails:

1. that file is marked as failed;
2. its failure is recorded in the current transfer state;
3. the queue continues to the next file where applicable.

A failed file must not silently appear successful.

---

# 17. Transfer Progress

Progress must represent real transfer activity.

Required conceptual values:

```text
bytesTransferred
totalBytes
```

Progress must be derived from those values.

For example:

```text
0 / 100 MB
25 / 100 MB
50 / 100 MB
75 / 100 MB
100 / 100 MB
```

The implementation must not fabricate transfer speed or progress.

---

# 18. Transfer Speed

Transfer speed must be calculated from actual transferred bytes over elapsed time.

The UI may display dynamic speed such as:

```text
8.4 MB/s
12.1 MB/s
7.8 MB/s
```

The exact smoothing/windowing algorithm is an implementation detail unless it materially affects user-visible behavior.

The Agent must not create unnecessary networking abstractions solely for speed calculation.

---

# 19. Transfer Cancellation

A transfer can be cancelled by the user.

Cancellation must:

1. stop the active transfer;
2. stop reading from the source;
3. stop writing to the destination;
4. remove the incomplete destination file;
5. update application state to reflect cancellation.

A partially received file must not be presented as a completed file.

Cancellation must not automatically retry the cancelled operation.

---

# 20. Transfer Retry

The application automatically retries retryable transfer failures.

Maximum attempts:

```text
3
```

Example:

```text
Attempt 1
   ↓ failure
Wait ~1 second
   ↓
Attempt 2
   ↓ failure
Wait ~2 seconds
   ↓
Attempt 3
   ↓ failure
Mark failed
```

The retry delay must use bounded backoff.

A retry must occur only for failures classified as retryable.

Non-retryable failures must immediately transition to failure.

Cancellation is not a retryable failure.

The exact retryable/non-retryable error classification must be defined together with the protocol error model.

**OPEN — APPROVAL REQUIRED**

Do not invent an extensive retry classification until the protocol error model is approved.

---

# 21. Duplicate File Names

When the destination already contains a file with the same name, Partilha automatically generates a unique filename.

Example:

```text
photo.jpg
photo (1).jpg
photo (2).jpg
```

The extension must remain intact.

Example:

```text
document.pdf
document (1).pdf
```

The naming algorithm must be deterministic.

The sender must not depend on the receiver's filesystem naming behavior.

---

# 22. Destination Storage

Before starting a transfer, the receiving device must validate that enough free storage is available.

The transfer must be rejected before partial data is written when available storage is insufficient.

For multiple files, storage requirements must account for the files that are going to be received.

The exact storage validation mechanism belongs to the platform/data layer and must not leak into domain logic.

---

# 23. Destination Location

Received files are saved directly into the platform's appropriate user-facing download/transfer directory.

Examples:

```text
Downloads
Transfers
```

The exact directory is platform-specific.

The protocol must not encode platform filesystem paths.

The receiver decides the valid destination path.

---

# 24. Completed Transfer

A file is considered completed only after:

1. all expected file bytes have been received;
2. the destination stream has successfully completed;
3. the destination file has been finalized;
4. the transfer state has been updated to completed.

The receiver must not report completion before the file is actually written successfully.

---

# 25. Integrity

The MVP must not claim file integrity verification that has not been explicitly implemented.

If checksums or hashes are introduced, the protocol must define:

- algorithm;
- field name;
- calculation point;
- transmission format;
- verification behavior;
- failure behavior.

**OPEN — APPROVAL REQUIRED**

No checksum/hash protocol should be invented during implementation.

---

# 26. Errors

Protocol errors must be represented using explicit error information.

The application must distinguish between:

```text
transport failure
protocol failure
validation failure
storage failure
transfer failure
cancellation
```

Raw exceptions from `dart:io`, mDNS, filesystem APIs, or other packages must not become protocol/domain errors automatically.

Infrastructure errors must be translated at the appropriate boundary.

---

# 27. Unknown Messages

If a device receives an unknown message type, it must not:

- interpret it as another message;
- silently execute it;
- crash the application;
- corrupt transfer state.

### 27.1 Unknown message: APPROVED

**An unrecognised message type is logged and ignored. The connection stays open.**

The distinction that matters is between a message this version does not
understand and a message that violates the contract:

```text
unknown type      → log, ignore, keep the connection
malformed content → violation, close the connection (§28)
```

A peer speaking a slightly different dialect must not be able to destroy work in
progress. Ignoring keeps a transfer alive when the other device introduces a
message type this version has never heard of; closing would turn any future
addition into a compatibility incident for transfers currently running.

This is not a licence to be lax: an unknown *type* is tolerated, a known type
with invalid contents is still a violation.

---

# 28. Malformed Messages

Malformed messages must not enter domain/application logic as valid objects.

Validation should occur at the protocol/data boundary.

Examples of malformed data include:

- missing required fields;
- invalid field types;
- invalid identifiers;
- invalid file sizes;
- invalid transfer identifiers;
- invalid connection information.

Malformed input must result in a controlled failure.

---

# 29. Message Ordering

Transfer-related messages may have dependencies.

For example:

```text
TransferRequest
      ↓
TransferAccepted
      ↓
FileTransfer
      ↓
TransferCompleted
```

The application must not process a completion message for a transfer that has not been accepted or started.

Unexpected message ordering must be handled explicitly.

The Agent must not assume that network messages are always received in the ideal order.

---

# 30. Connection Lifecycle

The protocol implementation must account for:

```text
connecting
connected
disconnected
reconnecting
failed
```

However, the application must not introduce persistent background reconnection behavior that conflicts with the MVP requirement that active transfers are cancelled when the application closes.

The exact reconnection behavior during an active transfer is **OPEN — APPROVAL REQUIRED** and must not be invented.

---

# 31. Application Closure

The MVP does not support background transfer.

If the application closes while a transfer is active:

1. the active transfer is cancelled;
2. incomplete destination files are removed;
3. no background transfer continues;
4. no transfer is resumed automatically after reopening.

Persistent transfer history is not required.

---

# 32. Security Boundary

The protocol document defines communication behavior.

Security-specific rules belong in:

```text
docs/SECURITY.md
```

The protocol must use the currently approved token-based pairing model.

The Agent must not independently introduce:

- TLS;
- certificate pinning;
- public/private key infrastructure;
- account authentication;
- OAuth;
- cloud authentication;
- invented encryption protocols;
- invented cryptographic handshakes.

Any such mechanism requires an explicit protocol/security decision.

---

# 33. Serialization

Protocol messages must be serializable to JSON and reconstructable from JSON.

Where code generation is appropriate:

```text
Freezed
+
json_serializable
```

should be used.

Protocol DTOs must remain separate from domain entities where their responsibilities differ.

Example:

```text
Protocol DTO
    ↓ mapping
Domain model
```

Do not expose transport-specific JSON maps throughout the application.

---

## 33.1 Wire Framing

A raw `dart:io` WebSocket carries **both** control messages and file bytes. The
connection is a single ordered byte stream, so the framing must distinguish
control traffic from payload traffic without ambiguity.

The approved constraints are:

```text
File bytes MUST be sent as WebSocket binary frames.
File bytes MUST NOT be base64-encoded into JSON.
Control messages MUST NOT be interleaved inside a file stream.
```

Base64 would inflate every payload by roughly one third and force the whole
file through a JSON string, which defeats the streaming and memory requirements
in `AGENTS.md`.

### 33.2 Discriminator: APPROVED

**Control traffic travels in WebSocket text frames. File bytes travel in
WebSocket binary frames. One connection carries both.**

This was chosen over a custom envelope, a channel id or an opcode prefix
because the transport already distinguishes the two, and duplicating that
distinction inside the payload adds cost without adding safety.

What this satisfies:

- File bytes are sent as binary frames and are **never** base64-encoded, so a
  file streams with no extra allocation and no size inflation.
- Control messages are never inside the file byte stream. A text frame is a
  separate frame; it cannot be interleaved into the byte stream itself.
- The two are unambiguous by construction, because they are different frame
  types. There is no field that can be malformed into ambiguity.

Accepted costs, stated rather than discovered later:

- `dart:io` surfaces both as a single `Stream<dynamic>`, so the receiver
  discriminates by element type. The transport layer must normalise this at its
  own boundary instead of leaking it upward.
- A text frame **could** be sent in the middle of a binary file transfer. The
  protocol defines the handling of that case explicitly rather than assuming it
  cannot happen; see §33.3.
- **Concurrent transfers cannot share one connection**, because frames are not
  tagged with a transfer id. This is resolved in §33.6 by serializing transfers.

### 33.3 A control frame during a file stream: APPROVED

A text frame arriving while a file transfer is streaming is a **protocol
violation**, not a control message for that transfer.

Rationale: silently accepting it would mean a sender could interleave control
traffic into bytes the receiver is already writing, and the receiver would have
no way to distinguish an intended message from a desynchronised stream. Failing
loudly is the only behaviour that preserves the integrity of the destination
file. It surfaces as `TransferFailure` and is not retryable as-is; the transfer
restarts from the beginning under the bounded retry policy.

### 33.4 Frame size limit: APPROVED

**Maximum frame size is 64 KiB, fixed. It is not negotiated.**

A frame larger than 64 KiB is a protocol violation. The receiver must reject it,
then close the connection and fail the transfer. The intent is that a host on the
local network must not be able to make the receiver allocate an arbitrary amount
of memory by announcing one enormous frame.

### 33.4.1 What the limit actually guarantees

This was originally specified as "reject before buffering". That is not
achievable with `dart:io` and the specification has been corrected to match
reality rather than left as an unimplemented promise.

`dart:io` materialises a complete WebSocket frame into a `Uint8List` before the
application sees it, and exposes no hook to inspect a frame's size before that
happens. The platform has therefore already allocated the oversized frame by the
time any Dart code can react to it.

What the limit does guarantee:

- the frame is never **processed**: not copied, not written to disk, not decoded,
  and never handed to the transfer layer;
- the connection is closed on the first violation, so the peer cannot keep the
  receiver busy by repeating the attempt — the exposure is one allocation per
  connection, not a sustained flood;
- the check is not advisory. A relaxed check would remove all three properties,
  so it must never become a warning.

A genuinely pre-allocation bound would require a transport that parses frame
headers itself. That is out of scope for `dart:io` and is recorded here as an
accepted platform limitation, not as an oversight.

64 KiB applies to binary data frames. Control messages are JSON text and are
small by construction, so they share the same ceiling rather than getting a
second, separately documented limit.

Frames are chunks of a file, never the file itself, so this bound does not
constrain file size. It only bounds how much memory one transfer holds at a
time, which is what keeps streaming viable under the memory requirements in
`AGENTS.md`.

### 33.5 Ordering: APPROVED

Frames are delivered in the order they were sent.

This is not a negotiated guarantee and needs no protocol support: a WebSocket
carries a single ordered byte stream over TCP, which already preserves order.
Recording it here because the receiver is entitled to rely on it — the sender
cannot reorder file chunks, and a receiver must not be written to expect
otherwise.

The guarantee is scoped to one connection. It says nothing about ordering across
transfers, because transfers are serialized (§33.6).

### 33.6 Transfers are serialized: APPROVED

**One transfer is active at a time, on one connection. The connection is reused
for the next transfer only after the current one finishes.**

This follows from §33.2: frames carry no transfer id, so two file streams on one
connection could not be told apart. Rather than extend the framing, the MVP
serializes. It also matches the queue semantics already documented in
`features/file_transfer/FEATURE.md` §12, where transfers proceed in order and one
failure does not stop the queue.

The cost is accepted and visible: a large file delays the rest of the queue.
This is a deliberate MVP limitation, not an oversight. Supporting parallel
transfers later requires an explicit change to §33.2, not just new code.

---

# 34. Protocol DTO Rules

Protocol DTOs should:

- represent the wire contract;
- validate required fields;
- serialize/deserialize JSON;
- remain independent from UI state;
- remain independent from widgets/controllers;
- avoid infrastructure-specific types.

Protocol DTOs must not contain:

```text
File
BuildContext
WebSocket
HttpRequest
Socket
Widget
ChangeNotifier
```

or equivalent infrastructure/UI objects.

---

# 35. Transfer Identifiers

Every active transfer must be distinguishable from other active transfer operations.

A transfer identifier is therefore required conceptually.

The exact identifier format is an implementation detail unless it becomes part of interoperability requirements.

The identifier must be unique within the scope required by the active communication session.

---

# 36. File Identifiers

When multiple files are transferred, each file must be distinguishable within the transfer.

A file identifier is therefore required conceptually.

The identifier exists to associate:

```text
request
progress
failure
completion
cancellation
```

with the correct file.

The exact identifier format is an implementation detail unless required by the final wire schema.

---

# 37. Protocol State Machine

The implementation should model transfer state explicitly.

Conceptually:

```text
Idle
  ↓
Requested
  ↓
Accepted
  ↓
Transferring
  ├── Cancelled
  ├── Failed
  └── Completed
```

Retryable failure may transition back into an active attempt:

```text
Transferring
    ↓
RetryableFailure
    ↓
Retry
    ↓
Transferring
```

After the maximum number of attempts:

```text
RetryableFailure
    ↓
Failed
```

The implementation must not create contradictory states such as:

```text
Completed + Failed
Completed + Cancelled
```

for the same final transfer attempt.

---

# 38. Protocol and Queue Separation

The transfer queue is an application-level concern.

The protocol communicates the state of the active transfer.

The queue must not be implemented inside the transport client.

Correct conceptual separation:

```text
Transfer Queue
      ↓
Transfer Application Service
      ↓
Protocol / Communication Contract
      ↓
Transport
```

The transport client must not own:

- queue state;
- retry policy;
- filesystem paths;
- UI state;
- business rules.

---

# 39. Protocol and Filesystem Separation

The protocol identifies files and their metadata.

The filesystem layer decides how bytes are read and written.

Do not place platform filesystem operations inside protocol DTOs.

Correct separation:

```text
Protocol
  ↓
Transfer Application Logic
  ↓
Filesystem / Stream
```

---

# 40. Protocol and UI Separation

The protocol must never depend on presentation-layer concepts.

It must not know about:

- screens;
- widgets;
- dialogs;
- snackbars;
- navigation;
- controllers;
- UI-specific states.

UI state is derived from application/domain state.

---

# 41. Open Protocol Decisions

The following decisions are intentionally unresolved and require explicit approval before implementation:

### 41.1 Exact message names: APPROVED (naming convention)

Message names are **`snake_case` strings** in the envelope's `type` field:

```json
{"type": "transfer_request", "id": "t-1", "payload": {}}
```

Chosen over integer opcodes because a log becomes `{"type": 7}`, which sends the
next person to the source to find what 7 means. The extra bytes are irrelevant
next to file payloads, and a wrong value is self-evident in a dump rather than
looking like a valid number.

Still open: **which** messages exist. The list still depends on the handshake and
token presentation, so no message type is defined until that is approved.

### 41.2 JSON envelope: APPROVED

Every control message uses the same envelope:

```json
{
  "type": "transfer_request",
  "id": "t-1",
  "payload": { "fileName": "photo.jpg", "size": 1234 }
}
```

- `type` — the `snake_case` discriminator from §41.1. Always present.
- `id` — correlates a response or an error with its request.
- `payload` — the message's own fields. Always present, `{}` when empty.

Uniform on purpose. It makes validation mechanical: check that `type` is a known
string, that `payload` is an object, and the shape of `payload` is then the only
per-type concern. A message with unknown fields at the top level instead has no
way to be recognised as unknown without first guessing its shape.

`id` is not optional. Without it there is no way to answer a specific request,
and adding it later would be a contract change the other side cannot understand.

`payload` is always present rather than omitted when empty, so decoding never has
to distinguish "absent" from "empty".

Errors are a separate `error` message (§14.1), not a field on this envelope.

### 41.3 mDNS service type

Define:

- service type;
- discovery metadata;
- TXT-record keys;
- address selection behavior.

### 41.4 Capability identifiers

Define the exact supported capability values.

### 41.5 Error codes

Define only the error codes required by the MVP.

### 41.6 Integrity verification

Decide whether the MVP requires checksums/hashes.

### 41.7 Unknown message behavior

Define whether unknown messages are ignored, rejected, or cause connection termination.

### 41.8 Reconnection behavior

Define what happens when the connection is temporarily lost during:

- pairing;
- transfer;
- idle state.

### 41.9 Transfer transport framing

Define exactly how file bytes are carried relative to control messages.

This must be explicit before implementation.

---

# 42. Implementation Rule

The Agent must follow this process when implementing protocol behavior:

```text
1. Read docs/PROTOCOL.md
2. Identify the required contract
3. Identify unresolved decisions
4. If required behavior is unresolved:
      STOP
5. Ask for explicit approval
6. Implement only the approved behavior
7. Add tests
8. Update protocol documentation if the contract changed
```

The Agent must never resolve an `OPEN — APPROVAL REQUIRED` item by guessing.

---

# 43. Protocol Change Policy

Any change to the wire contract is an architectural/protocol change.

Examples:

- changing message names;
- changing required fields;
- adding mandatory fields;
- changing transfer lifecycle;
- changing authentication/pairing behavior;
- changing mDNS metadata;
- introducing protocol versioning;
- introducing checksums;
- changing transfer framing.

Such changes require explicit approval.

The Agent must not silently modify the protocol because a different implementation would be more convenient.

---

# 44. MVP Protocol Non-Goals

The following are explicitly outside the MVP protocol:

- internet file transfer;
- cloud relay;
- user accounts;
- persistent device registry;
- background transfers;
- transfer history;
- folder transfer;
- pause/resume;
- push notifications;
- automatic cloud backup;
- protocol version negotiation;
- invented encryption architecture;
- invented authentication architecture.

Future support for these features must not leak into the MVP implementation.

---

# 45. Final Rule

The protocol is a contract, not a suggestion.

If code and this document disagree:

```text
DO NOT silently choose one.
```

The Agent must:

1. identify the disagreement;
2. explain the impact;
3. stop the affected implementation;
4. request an explicit decision;
5. update the protocol documentation;
6. only then continue implementation.

The objective is to prevent protocol drift, accidental interoperability assumptions, and architecture being defined implicitly by implementation.
