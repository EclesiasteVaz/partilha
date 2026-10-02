# Partilha Security

## 1. Purpose

This document defines the security model for the Partilha MVP.

It establishes:

- what security mechanisms are currently approved;
- how device identity is handled;
- how pairing is authenticated;
- how connection information is protected;
- how sensitive data must be stored;
- what the application must reject;
- which security mechanisms are explicitly outside the MVP;
- which decisions require explicit approval before implementation.

This document is part of the project's technical contract.

The Agent MUST NOT introduce additional security architecture that is not explicitly defined or approved here.

---

# 2. Security Principles

Partilha follows these principles:

1. Minimize exposed information.
2. Do not trust discovered devices automatically.
3. Validate connection information before transfer.
4. Keep persistent credentials out of UI/application state when possible.
5. Do not log secrets.
6. Do not expose tokens unnecessarily.
7. Do not invent cryptographic mechanisms.
8. Fail safely when authentication or validation fails.
9. Do not treat local-network visibility as authentication.
10. Keep security responsibilities separated from UI and transport implementation.

---

# 3. MVP Security Scope

The MVP security model is intentionally limited.

The approved MVP model includes:

- persistent device identity;
- user-defined device name;
- persistent device token;
- token-based pairing/connection validation;
- controlled discovery metadata, **excluding the token**;
- input validation;
- controlled filesystem writes;
- protection against incomplete files being presented as completed files;
- no logging of sensitive credentials.

The MVP does NOT currently define a complete cryptographic security architecture.

---

# 4. Threat Model

Partilha operates primarily in a nearby-device environment.

The security model must account for at least the following scenarios:

### 4.1 Unknown nearby device

Another device may discover the Partilha service.

Discovery alone must not be considered sufficient authorization to transfer files.

---

### 4.2 Invalid connection information

A device may attempt to connect using:

- an invalid device ID;
- an invalid token;
- an invalid port;
- malformed connection data;
- incomplete QR information.

The connection must be rejected safely.

---

### 4.3 Malformed protocol input

A malicious or faulty peer may send malformed JSON or invalid protocol messages.

The application must validate protocol input before it reaches domain/application logic.

---

### 4.4 Unexpected transfer data

A peer may provide metadata that does not match the expected transfer.

Examples include:

- invalid file size;
- missing filename;
- invalid transfer identifier;
- unexpected transfer state;
- inconsistent transfer metadata.

The receiver must not blindly trust remote metadata.

---

### 4.5 Insufficient storage

A remote peer may request a transfer larger than the available destination storage.

The receiver must validate storage before beginning the transfer.

---

### 4.6 Application termination

The application may terminate while a transfer is active.

The MVP must not continue the transfer in the background.

Incomplete files must not be treated as valid completed files.

---

# 5. Device Identity

Each Partilha installation has a persistent device identity.

The device identity identifies the installation rather than the user as an account.

Conceptually:

```text id="r8k3q2"
deviceId
deviceName
token
```

These values have different security responsibilities.

---

## 5.1 Device ID

`deviceId` identifies the device.

It is not a secret.

It may be included in discovery metadata and connection information.

However, the device ID alone must never be treated as proof of authorization.

---

## 5.2 Device Name

`deviceName` is a user-defined display value.

It is not a credential.

It must not be used for authentication.

A device name such as:

```text
Eclesiaste MacBook
```

must never be treated as evidence that the connecting device is trusted.

---

## 5.3 Token

The persistent token is part of the current MVP pairing/connection validation model.

The token is sensitive.

It must be treated as a credential.

The token must:

- be generated securely;
- persist across normal application restarts;
- not be displayed unnecessarily;
- not be written to normal application logs;
- not be included in analytics;
- not be exposed through debug output;
- not be stored in UI state unless strictly required;
- not be hardcoded into source code.

The exact secure-storage implementation is defined by the platform/data layer.

---

# 6. Token Generation

The token must be generated using a cryptographically appropriate source of randomness provided by the platform/runtime.

Do not use:

```text
DateTime.now()
Random()
incrementing integers
device names
device IDs
```

or combinations of predictable values to generate the token.

The token generation mechanism must provide sufficient unpredictability for its role as a connection credential.

The exact token format and length must be defined by implementation based on the selected secure mechanism.

The Agent must not weaken the token merely for convenience.

---

# 7. Token Storage

The token must be persisted securely.

The Agent must use the platform's appropriate secure credential storage mechanism rather than storing the token as ordinary plaintext application data.

The security-sensitive value must not be stored in:

- UI state;
- logs;
- source code;
- Git;
- analytics events;
- ordinary configuration files;
- test fixtures containing real credentials.

The exact package/platform implementation must remain behind a project-owned abstraction.

Example:

```text id="s8a5kj"
SecureCredentialStore
        ↓
Platform secure storage
```

The domain layer must not depend on the secure-storage package.

---

# 8. Token Exposure

The token may be transported as part of the approved pairing/connection information.

However, exposure must be minimized.

The application must not:

- print the token;
- include it in ordinary logs;
- display it in diagnostic screens;
- send it to analytics;
- persist it in transfer history;
- include it in error messages;
- expose it through unnecessary UI state.

When logging connection information, sensitive fields must be redacted.

Example:

```text id="4j6m1p"
deviceId: abc123
deviceName: Eclesiaste MacBook
host: 192.168.x.x
port: 1234
token: [REDACTED]
```

---

# 9. QR Security

QR codes may contain connection information required to establish a connection.

Because the QR payload may contain the connection token, the QR payload must be treated as sensitive connection information.

The application must:

- generate the QR payload from current connection information;
- validate scanned QR data;
- reject malformed payloads;
- avoid logging raw QR contents;
- avoid persisting scanned tokens unnecessarily.

A QR code containing a valid token must not be treated as public information.

---

# 10. QR Validation

A scanned QR payload must be validated before being used.

Validation must include, where applicable:

- required fields;
- field types;
- valid device ID;
- valid device name;
- valid host/address;
- valid port;
- valid token;
- valid capabilities.

Malformed payloads must be rejected.

The application must not attempt arbitrary network connections based on unvalidated QR content.

---

# 11. mDNS Security

mDNS provides discovery, not authentication.

The following assumption is prohibited:

```text
"Device discovered through mDNS = trusted device"
```

Discovery only tells the application that a service is visible.

Connection authorization still requires the approved pairing/connection validation mechanism.

mDNS metadata must therefore be treated as untrusted input.

### 11.1 The token must not be advertised

The device token must **never** be placed in mDNS metadata.

mDNS responses and queries are plaintext on the local network. Any host able to
receive multicast traffic — not only Partilha installations — can read the
service records. Advertising the token would turn every Partilha receiver into
a credential disclosure point and allow a neighbouring host to impersonate it.

Approved discovery metadata is limited to:

```text
deviceId
deviceName
host/address
port
capabilities
```

The token leaves the device through the **QR code only**. See
`docs/decisions/0003-token-fora-do-mdns.md`.

Because discovery metadata is attacker-controllable, implementation must also:

- validate every field's type and length before use;
- never trust `deviceId` as proof of identity;
- never derive filesystem paths from discovered metadata;
- never log discovered metadata verbatim;
- treat `deviceName` as display-only and escape it when rendered.

---

# 12. Network Input Validation

All remote input must be considered untrusted.

This includes:

- discovery metadata;
- QR payloads;
- JSON messages;
- transfer metadata;
- filenames;
- file sizes;
- identifiers;
- capabilities;
- connection information.

Validation must happen at the appropriate boundary before data is used by application/domain logic.

---

# 13. Filename Security

Remote filenames must never be used directly as unrestricted filesystem paths.

The receiver must prevent path traversal and unintended filesystem access.

Examples of dangerous input include:

```text
../file.txt
../../file.txt
/absolute/path/file.txt
~/file.txt
```

or platform-specific equivalents.

The final destination must remain inside the application's approved user-facing transfer/download directory.

The sender must not be able to select an arbitrary destination path on the receiving machine.

---

# 14. Filename Normalization

The receiver may normalize filenames when required by the platform filesystem.

The normalization must preserve the intended user-visible filename as much as reasonably possible while preventing unsafe paths.

Duplicate filename resolution must follow the application rule defined in `docs/PROTOCOL.md`.

Example:

```text
photo.jpg
photo (1).jpg
photo (2).jpg
```

---

# 15. File Size Validation

The receiver must validate declared file sizes.

Invalid values must be rejected.

At minimum:

- file size must not be negative;
- file size must be representable safely;
- actual received bytes must not exceed the expected transfer boundaries.

A remote peer must not be allowed to cause an uncontrolled write simply by declaring an arbitrary size.

---

# 16. Transfer State Validation

The receiver must validate the state of a transfer before processing messages.

For example:

```text
TransferCompleted
```

must not be accepted for a transfer that was never started.

Likewise:

```text
TransferProgress
```

must refer to a known active transfer/file.

Unexpected state transitions must be rejected safely.

---

# 17. Partial Files

Partially transferred files must not be exposed as completed files.

If a transfer:

- fails;
- is cancelled;
- is interrupted;
- exceeds allowed limits;
- becomes invalid;

the incomplete destination file must be removed according to the approved transfer lifecycle.

This prevents users from mistaking incomplete data for a successfully received file.

---

# 18. Storage Exhaustion

The receiver must validate available storage before beginning a transfer.

This reduces the risk of:

- incomplete transfers;
- uncontrolled disk consumption;
- unnecessary partial files.

For multiple files, validation must consider the total expected storage requirement where applicable.

---

# 19. Resource Limits

Remote peers must not be able to cause unlimited resource consumption.

The implementation must establish reasonable bounds for protocol-controlled resources where the MVP requires them.

Potential resources include:

- number of queued files;
- number of active transfers;
- filename length;
- metadata size;
- message size;
- connection count.

**OPEN — APPROVAL REQUIRED**

Exact numerical limits are not currently defined.

The Agent must not invent arbitrary limits and present them as protocol requirements.

If implementation requires such limits, the missing decision must be raised explicitly.

---

# 20. Logging

Logging must never expose credentials or sensitive connection information.

Sensitive fields include at minimum:

- token;
- raw QR payload;
- credentials;
- security secrets.

Logs should contain useful diagnostic context without exposing secret values.

Example:

```text
INFO  Pairing request received
DEBUG Device discovered: deviceId=abc123
DEBUG Token: [REDACTED]
ERROR Pairing rejected: invalid token
```

Do not use:

```dart
print(...)
```

for production diagnostics.

Use the project's structured logger.

---

# 21. Error Messages

Errors shown to users must not expose internal secrets or sensitive implementation details.

Avoid messages such as:

```text
Token abc123456789 is invalid.
```

Prefer:

```text
Connection could not be authenticated.
```

Internal logs may contain diagnostic identifiers where appropriate, but secrets remain redacted.

---

# 22. Secrets in Source Control

The repository must never contain:

- real device tokens;
- production credentials;
- private keys;
- authentication secrets;
- real QR payloads containing credentials.

Test fixtures must use intentionally generated test values.

If a secret is accidentally committed, it must be treated as compromised and rotated rather than simply deleted from the latest commit.

---

# 23. Debug Builds

Debugging facilities must not weaken the security model in a way that can accidentally leak secrets.

Developers may use diagnostics during development, but sensitive values must remain redacted by default.

A debug-only log must not become a production logging requirement.

---

# 24. Security and Architecture

Security-sensitive infrastructure must be isolated behind project-owned abstractions where appropriate.

For example:

```text id="9o1m4c"
Domain
  ↓
Security / application contract
  ↓
SecureCredentialStore
  ↓
Platform secure storage
```

The domain layer must not depend directly on:

- platform secure-storage APIs;
- Android-specific security classes;
- macOS-specific security classes;
- package-specific credential APIs.

---

# 25. Security and Transport

The current security document does not define transport encryption.

The Agent must not automatically add:

- TLS;
- custom encryption;
- symmetric encryption;
- asymmetric encryption;
- Diffie-Hellman;
- certificate pinning;
- public-key infrastructure;
- custom cryptographic protocols.

These mechanisms may be evaluated in a future security revision.

They are not implicit requirements of the MVP.

---

# 26. Security and the Transport

The transport is a raw `dart:io` WebSocket.

It does not define the complete Partilha security model.

The application must not assume that a WebSocket automatically provides:

- authentication;
- authorization;
- encryption;
- device trust.

A `ws://` connection is **plaintext**. Using `WebSocketTransport` does not by
itself encrypt anything.

The project-owned protocol/security layer remains responsible for the approved
validation rules.

### 26.1 Transport encryption

**OPEN — APPROVAL REQUIRED**

Transport encryption is not defined. The following must be explicitly approved
before the Agent implements the transport:

- whether the MVP runs `ws://` (plaintext) or `wss://` (TLS);
- if TLS, how the self-signed certificate is generated, pinned, and verified;
- if plaintext, what the accepted exposure is and how it is presented to users.

A self-signed certificate is not automatically trustworthy: without an explicit
pinning or trust-on-first-use model, TLS offers authentication that a MITM can
forge. The Agent must not assume `wss://` alone solves this.

See also `docs/decisions/0001-transporte-websocket-dart-io.md`.

---

# 27. Security and mDNS

mDNS is a discovery mechanism.

It does not provide device authentication.

The application must therefore treat discovered metadata as untrusted until the approved pairing/connection validation succeeds.

---

# 28. Security and Filesystem Access

The receiver controls the destination filesystem.

Remote devices must never be able to specify arbitrary filesystem locations.

The sender provides file metadata.

The receiver decides:

- whether the transfer is accepted;
- where the file is stored;
- how the filename is normalized;
- whether enough storage exists.

---

# 29. Authorization Boundary

The MVP must distinguish:

```text
Discovery
    ≠
Authentication
    ≠
Authorization
```

### Discovery

Answers:

> "Is another Partilha service visible?"

### Authentication / connection validation

Answers:

> "Does the connection contain valid approved credentials?"

### Authorization

Answers:

> "Is this connection allowed to perform the requested transfer operation?"

The exact authorization rules must remain aligned with the approved MVP pairing model.

The Agent must not introduce an account/role/permission system.

---

# 30. Token Rotation

Automatic token rotation is not currently part of the MVP.

The Agent must not silently rotate the persistent token on:

- every application launch;
- every connection;
- every transfer;
- every discovery event.

If token rotation is introduced later, the security protocol must define:

- when rotation occurs;
- how peers receive the new token;
- how old tokens expire;
- how interrupted pairing behaves.

---

# 31. Token Revocation

A complete token revocation system is not currently defined.

The MVP must not introduce a persistent known-device registry simply to support token revocation.

If revocation becomes necessary in a future version, it must be explicitly designed.

---

# 32. Known Devices

The MVP does not persist a registry of known/trusted devices.

The following concepts must not be conflated:

```text
Persistent device identity
Persistent token
Known-device registry
```

Partilha may persist its own device identity and token without maintaining a user-visible database of previously connected devices.

---

# 33. Application Closure

When the application closes:

- active transfers are cancelled;
- background transfer does not continue;
- incomplete files are removed;
- no transfer is automatically resumed.

Security-sensitive connection state must not be left active beyond the supported application lifecycle.

---

# 34. Data Minimization

Partilha should store only data required for the current product behavior.

The MVP does not require persistent storage of:

- transfer history;
- remote device history;
- previous QR payloads;
- remote tokens;
- cloud account information.

Temporary connection data should be released when it is no longer required.

---

# 35. Privacy Boundary

Partilha is a nearby file-sharing application.

The MVP does not require:

- user accounts;
- cloud profiles;
- remote analytics about file contents;
- cloud file storage.

The application must not upload transferred files to external services as part of the MVP.

File contents are transferred directly between the participating devices according to the approved transport architecture.

---

# 36. No Silent Security Changes

The Agent must stop and request approval if implementation requires any of the following:

- a new credential;
- a new authentication mechanism;
- encryption;
- certificate management;
- key exchange;
- token rotation;
- token revocation;
- persistent remote-device trust;
- new permission/security requirements;
- new network exposure;
- new externally accessible endpoint;
- a new security-sensitive dependency.

The Agent must explain:

1. why the change appears necessary;
2. what security property it provides;
3. what architecture it affects;
4. what alternatives exist;
5. what protocol/documentation changes are required.

---

# 37. Security Testing

Security-relevant behavior must be tested.

At minimum, tests should cover:

- malformed QR payloads;
- invalid token;
- missing token;
- invalid device ID;
- malformed protocol messages;
- invalid file size;
- unsafe filenames;
- path traversal attempts;
- duplicate filenames;
- insufficient storage;
- unexpected transfer states;
- cancellation cleanup;
- incomplete transfer cleanup;
- secret redaction in logs.

Tests must use generated/test credentials rather than real credentials.

---

# 38. Security Review Checklist

Before considering a security-sensitive feature complete:

### Credentials

- [ ] Token is generated securely.
- [ ] Token is persisted securely.
- [ ] Token is never hardcoded.
- [ ] Token is never logged.
- [ ] Token is redacted from diagnostics.
- [ ] Token is not stored unnecessarily.

### Network

- [ ] Discovery metadata is treated as untrusted.
- [ ] QR input is validated.
- [ ] Remote messages are validated.
- [ ] Invalid authentication is rejected.
- [ ] Unexpected messages cannot corrupt application state.

### Filesystem

- [ ] Remote filenames are validated.
- [ ] Path traversal is prevented.
- [ ] Destination is controlled locally.
- [ ] File sizes are validated.
- [ ] Storage is checked before transfer.
- [ ] Partial files are cleaned up.

### Architecture

- [ ] Security package APIs do not leak into domain.
- [ ] Secrets do not enter UI unnecessarily.
- [ ] Transport does not own security policy.
- [ ] No undocumented authentication mechanism exists.

### Documentation

- [ ] Security behavior matches `docs/PROTOCOL.md`.
- [ ] Any security contract change is documented.
- [ ] No unresolved security decision was silently implemented.

---

# 39. Future Security Work

The following areas may be evaluated in future versions:

- encrypted transport;
- stronger mutual authentication;
- cryptographic device identity;
- token rotation;
- token revocation;
- explicit trusted-device management;
- secure transfer integrity verification;
- stronger replay protection;
- protocol versioning;
- security event auditing.

These are future considerations only.

They are not MVP implementation requirements.

The Agent must not implement them proactively.

---

# 40. Security Decision Rule

Security improvements are not automatically architecture improvements.

A security mechanism may introduce:

- protocol changes;
- compatibility requirements;
- key management;
- storage requirements;
- platform dependencies;
- UX complexity;
- testing requirements.

Therefore:

> Do not add security mechanisms merely because they are commonly used elsewhere.

Implement only security mechanisms that have been explicitly approved for the current Partilha version.

---

# 41. Final Rule

The security model must be explicit.

If implementation encounters a security decision that this document does not answer:

```text
STOP.
DO NOT GUESS.
```

The Agent must:

1. identify the security decision;
2. explain why it is required;
3. identify the affected protocol/architecture;
4. request approval;
5. update `docs/SECURITY.md` if approved;
6. update `docs/PROTOCOL.md` when the wire contract changes;
7. implement only the approved design.

Security behavior must never emerge accidentally from package defaults, transport behavior, or Agent assumptions.
