# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Architecture specification: feature-first Clean Architecture, dependency
  direction, package isolation matrix, and abstraction matrix.
- Feature specification (`FEATURES.md`) and four derived feature documents under
  `features/`, each with an explicit current-status section.
- Protocol contract (`docs/PROTOCOL.md`) with unresolved decisions marked
  `OPEN — APPROVAL REQUIRED`.
- Security model (`docs/SECURITY.md`) covering the MVP token-based pairing model.
- Architectural Decision Records under `docs/decisions/`.
- Open-source governance files: `LICENSE` (MIT), `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `CHANGELOG.md`.

### Changed

- **Transport**: replaced Socket.IO with a raw WebSocket over `dart:io`.
  Socket.IO was not implementable for Flutter↔Flutter — the only Dart server
  speaks protocol v2.0.1 while the maintained Dart client speaks v4.x, and
  there is no compatible pairing. See `docs/decisions/0001-transporte-websocket-dart-io.md`.
- **Discovery metadata**: removed the device token from mDNS advertised metadata.
  mDNS records are plaintext and readable by any host on the local network, so
  advertising the token would allow any neighbour to impersonate the device. The
  QR code is now the only channel that carries the token. See
  `docs/decisions/0003-token-fora-do-mdns.md`.
- **Retry policy**: fixed an arithmetic inconsistency. Three attempts admit
  exactly two delays, so the approved backoff is `1s → 2s` rather than
  `1s → 2s → 4s`.
- **Documentation layout**: `doc/` renamed to `docs/`; `FEATURE.md` renamed to
  `FEATURES.md`; feature documents moved out of `lib/` into `features/` at the
  repository root so documentation stays out of the compiled app bundle.
- **Feature naming**: the transfer feature folder is `file_transfer/`, consistent
  with snake_case naming.

### Removed

- **Dio / HTTP client**: no MVP flow performs HTTP requests. The HTTP client has
  been removed from the documented stack. See
  `docs/decisions/0004-sem-dio-no-mvp.md`.
- `lib/core/utils/`, `lib/core/helpers/`, `lib/core/common/` and
  `lib/core/misc/` from the documented structure. These are forbidden dumping
  grounds per `docs/ARCHITECTURE.md`.

### Security

- Discovery metadata is documented as untrusted, attacker-controllable public
  input, with mandatory validation rules for field type, length, display
  escaping, and filesystem-path influence.
- Transport encryption is explicitly unresolved and recorded as
  `OPEN — APPROVAL REQUIRED`, including the warning that `wss://` with an
  unpinned self-signed certificate does not by itself provide authentication.

### Known Limitations

- **Nothing is implemented.** The repository contains the default Flutter
  scaffold plus the complete architecture and feature specification.
- Discovery is blocked pending an mDNS provider validation spike.
- File transfer is blocked pending the wire-framing and transport-encryption
  decisions.

[Unreleased]: https://github.com/partilha/partilha/compare/v0.0.0...HEAD