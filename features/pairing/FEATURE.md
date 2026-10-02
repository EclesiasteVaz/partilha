# Pairing

> Derivado de [`FEATURES.md`](../../FEATURES.md) §11–§15 e §11–§14 do master.
> Não substitui o master. Onde houver conflito, `FEATURES.md` prevalece.

## 1. Purpose

Pairing establishes enough trust and connection information between two devices
to allow a transfer.

The MVP model uses a persistent device token carried by a QR code.

## 2. Scope

In scope:

- generating/using device identity information;
- generating QR connection information;
- scanning QR information;
- validating received connection information;
- establishing the pairing context;
- exposing pairing success/failure.

Explicitly not in scope: a persisted list of previously paired devices.

## 3. Current Status

**NOT IMPLEMENTED.**

Pairing is additionally gated on unresolved protocol decisions. See Open
Questions.

## 4. User Problem

Discovery tells the sender that a device exists, but not that it is the device
the user intends to send to, and not how to authenticate. Pairing closes both
gaps through a deliberate, physical user action.

## 5. User Flow

```text
Receiver                                Sender
   │                                       │
   ├── shows QR with                       │
   │   deviceId, name,                     │
   │   host, port, token,                  │
   │   capabilities                        │
   │◄────────────── user shows QR ─────────┤
   │                                       ├── scans
   │                                       ├── validates payload
   │                                       │
   │◄──── connection + token validation ───┤
   │                                       │
   │                            pairing established
```

## 6. Functional Requirements

- generate/use device identity information;
- generate QR connection information;
- scan QR information;
- validate received connection information before use;
- establish the pairing context;
- expose pairing success and failure.

The device name is user-defined. The device token is persistent.

**Do not create a persisted known-device registry.** Persistent device identity
and persistent known-device history are separate concepts:

```text
Persistent device identity
≠
Persistent known-device history
```

## 7. Non-Functional Requirements

- QR payloads must be structured data, not an undocumented concatenated string;
- scanning must not require network access;
- pairing validation must complete before any transfer operation is allowed;
- secrets must never be written to logs.

## 8. States

```text
initial
generatingQr
showingQr
scanning
validating
paired
failed
```

## 9. State Transitions

```text
initial      → generatingQr
generatingQr → showingQr
showingQr    → scanning     (QR captured)
scanning     → validating
validating   → paired
validating   → failed
failed       → scanning
```

## 10. Inputs

- QR payload: `deviceId`, `deviceName`, `host/address`, `port`, `token`,
  `capabilities`, protocol-related connection information;
- permission state for camera access;
- local device identity.

**The QR payload is untrusted input** — anyone can print a QR code containing
arbitrary values.

## 11. Outputs

- a validated pairing context, or a typed `Failure`;
- a QR payload the receiver displays.

The QR is the **only** approved channel that may carry the token. See
`docs/decisions/0003-token-fora-do-mdns.md`.

## 12. Validation

Before accepting pairing information, validate:

- presence of required fields;
- field types;
- host/address;
- port;
- token;
- capabilities, where applicable;
- protocol compatibility under current protocol rules.

**Do not invent protocol-version negotiation.** Protocol versioning is not part
of the MVP.

The exact final field names and validation rules belong to the protocol
implementation, defined in `docs/PROTOCOL.md` §8.

## 13. Success Behavior

The connection is established, the token validates, and the pairing context is
available to File Transfer.

## 14. Failure Behavior

Distinguish meaningful failures:

```text
invalid QR payload
invalid device information
connection unavailable
authentication / token failure
protocol rejection
permission failure
timeout
```

Only implement failures the architecture actually supports. Do not create
categories solely to populate an enum.

## 15. Cancellation Behavior

Cancelling scanning must:

- stop the camera preview;
- release the scanner;
- return to the previous state without a partial pairing context.

Cancelling pairing after validation must discard the context entirely rather
than leaving it half-initialized.

## 16. Architecture

```text
PairingController (presentation)
        ↓
GenerateQrUseCase / ScanQrUseCase / ValidatePairingUseCase (application)
        ↓
PairingRepository + QrCodeService (domain contracts)
        ↓
SqlitePairingRepository + MobileScannerQrCodeService (data)
        ↓
sqflite · mobile_scanner · SecureCredentialStore
```

## 17. Domain Contracts

```text
PairingRepository
    Future<Result<DeviceIdentity, Failure>> readIdentity()
    Future<Result<PairingContext, Failure>> pair(PairingRequest request)

QrCodeService
    Future<String> encode(PairingPayload payload)
    Future<Result<ParsedPayload, Failure>> scan()
```

Contract names are indicative; the final contract is fixed at implementation time
and recorded here.

## 18. Application Layer

Orchestrates scanning, validation, and context establishment. Imports no
scanner package and no secure storage API.

## 19. Data Layer

- owns `mobile_scanner`;
- owns the token read/write through `SecureCredentialStore`;
- owns sqflite access for `deviceId` persistence.

The token must be written through the platform's secure credential storage, not
as ordinary plaintext application data.

## 20. Presentation Layer

- a `PairingController` with immutable Freezed state;
- the QR display screen;
- the scan screen;
- `ListenableBuilder` binding, controllers from GetIt.

## 21. External Dependencies

```text
mobile_scanner      (QR scanning, Android + macOS)
getit
freezed
json_serializable
sqflite
```

Scanner abstraction: `QrCodeService`.

## 22. Package Isolation

```text
mobile_scanner → QrCodeService
platform secure storage → SecureCredentialStore
```

UI and feature logic must not depend on the scanner or secure-storage packages
directly.

## 23. Persistence

Persisted, because it must survive restart:

```text
deviceId
device token  (secure storage only)
```

`deviceName` lives in Settings and is read through the Settings contract — it is
not duplicated here.

Not persisted: pairing contexts, known-device records, transfer state.

## 24. Platform Considerations

- `mobile_scanner` supports Android and macOS. On macOS, external and
  Continuity cameras have known camera-selection bugs; the built-in camera path
  works. This must be verified on a real Mac before pairing is considered done.
- Camera permission must be requested explicitly through `PermissionService`,
  not via the scanner package directly.
- macOS requires `NSCameraUsageDescription` in the entitlements and Info.plist.
- Android requires the camera permission in the manifest.

## 25. Performance Requirements

- QR generation must be fast enough to feel instantaneous on tap;
- scanning must decode in real time without visible lag;
- validation must not block the UI thread;
- the scanner must not keep the camera open after leaving the scan screen.

## 26. Security Requirements

- the token is a credential: never logged, never printed, never shown in a
  screenshot-friendly surface without a deliberate user action;
- the token must be generated with a cryptographically appropriate source of
  randomness provided by the platform/runtime;
- the token must not be predictable from `deviceId`, hostname, or any
  combination of observable values;
- the exact token format and length is **OPEN — APPROVAL REQUIRED**;
- the QR payload must be treated as sensitive connection information;
- a scanned token must not be persisted unnecessarily;
- a valid QR must not be treated as public information;
- the QR must not be logged in full.

Authority: `docs/SECURITY.md` §8–§10.

## 27. Accessibility Requirements

- the QR must have a semantic label and a text alternative for assistive
  technology;
- camera permission denial must be explainable and recoverable, not a dead end;
- the scan frame needs a clear accessible name;
- pairing state changes must be announced;
- the fallback for an unreadable QR must be reachable by keyboard on desktop;
- do not rely on colour to indicate scanning state.

## 28. Edge Cases

- QR scanned but malformed JSON → invalid payload failure;
- QR from a different application → rejected as out of scope;
- QR missing the token → rejected; the token is mandatory;
- QR pointing at a host that is unreachable → connection failure, distinct from
  validation failure;
- token does not match → authentication failure, distinct from connection
  failure;
- camera permission permanently denied → permission failure with a route to
  system settings;
- very large or deeply nested payload → bounded by validation;
- scanned payload containing path separators or control characters → rejected;
  metadata must never influence a filesystem path;
- the receiver closes the app between showing the QR and the connection.

## 29. Testing Requirements

**Unit**

- payload encode/decode round-trip;
- validation of every field, including rejection cases;
- `Failure` conversion for scanner and secure-storage exceptions;
- pairing state transitions.

**Integration**

- real secure-storage read/write on Android and macOS;
- end-to-end pairing between two real devices.

**UI**

- QR is displayed and labelled;
- scanning produces a validated context;
- each failure category renders distinctly and accessibly;
- permission denial is recoverable.

## 30. Known Limitations

- Not implemented.
- The token model is deliberately minimal; it is not strong authentication.
- Token rotation and revocation do not exist in the MVP.
- Transport encryption is undecided (`docs/SECURITY.md` §26.1), so the paired
  connection may be plaintext.

## 31. Out of Scope

- persisted known-devices list;
- multi-device pairing management;
- unpairing and re-pairing UX;
- account-based identity;
- token rotation and expiration;
- strong/cryptographic authentication;
- QR generation for more than one simultaneous pairing.

## 32. Future Work

- token rotation;
- revocation;
- stronger authentication;
- re-pairing flow.

None is scheduled.

## 33. Architectural Decisions

| Decision | Where |
|---|---|
| QR carries the token; discovery never does | `docs/decisions/0003-token-fora-do-mdns.md` |
| Device name is user-defined | `AGENTS.md` §34 |
| Persistent identity ≠ known-device history | `FEATURES.md` §11.2 |
| QR package isolated behind `QrCodeService` | `AGENTS.md` §39 |
| No protocol versioning in MVP | `AGENTS.md` §38 |

## 34. Open Questions

**OPEN — APPROVAL REQUIRED**

- exact token format and length;
- the connection handshake sequence, and whether the token travels in the first
  message (`docs/PROTOCOL.md` §9);
- the exact QR payload field names and validation rules;
- what a rejected device shows the user as the reason, and whether that leaks
  information;
- pairing timeout value;
- whether pairing survives app restart, given no known-device registry exists;
- behavior on macOS with external or Continuity cameras.

No Pairing implementation may begin until the handshake and payload contracts
are approved.