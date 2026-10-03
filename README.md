# Partilha

**Partilha** is an open-source, cross-platform file-sharing application designed to make transferring files between nearby devices simple, fast, and predictable.

The project focuses on direct device-to-device transfers, local network discovery, QR-based pairing, streaming file I/O, and a clean architecture that keeps infrastructure dependencies isolated from the rest of the application.

> **Status:** Pre-implementation.
>
> The repository currently contains the architecture and feature specification
> only. `lib/` still holds the default Flutter scaffold, and **no feature is
> implemented yet**. See the [Roadmap](#roadmap) for the real state of the
> project.

---

## Table of Contents

- [About](#about)
- [Goals](#goals)
- [How It Works](#how-it-works)
- [MVP Scope](#mvp-scope)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Technology Stack](#technology-stack)
- [Device Discovery](#device-discovery)
- [Pairing](#pairing)
- [File Transfer](#file-transfer)
- [Transfer Queue](#transfer-queue)
- [Storage](#storage)
- [State Management](#state-management)
- [Design System](#design-system)
- [Performance](#performance)
- [Error Handling](#error-handling)
- [Security](#security)
- [Platform Support Status](#platform-support-status)
- [Development](#development)
- [Testing](#testing)
- [Code Quality](#code-quality)
- [Git Workflow](#git-workflow)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

---

## About

Partilha is built around a simple interaction:

1. One device starts **Receive** mode.
2. The receiving device announces itself on the local network.
3. Another device starts **Send** mode.
4. The sender discovers available receiving devices through mDNS.
5. The devices can also be paired through a QR code.
6. The sender selects one or more files.
7. Partilha verifies that the destination has enough storage.
8. Files are streamed directly to the receiving device.
9. Progress and transfer speed are calculated from the actual bytes transferred.
10. Each file is handled independently within the transfer queue.

The application is intentionally designed around **streaming instead of loading entire files into memory**.

---

## Goals

Partilha aims to provide:

- Simple device-to-device file sharing.
- Fast local-network transfers.
- QR-based device pairing.
- Automatic device discovery through mDNS.
- Streaming file transfers.
- Low memory usage.
- Predictable transfer behavior.
- Automatic retry of temporary failures.
- A clean and maintainable architecture.
- Strong separation between application code and infrastructure packages.
- A foundation suitable for open-source contribution.

The project prioritizes **clarity, performance, maintainability, and practical abstractions** over unnecessary architectural complexity.

---

## How It Works

At a high level:

```text
┌─────────────────┐
│  Receive Device │
└────────┬────────┘
         │
         │ mDNS advertisement
         ▼
┌─────────────────┐
│  Local Network  │
└────────┬────────┘
         │
         │ discovery
         ▼
┌─────────────────┐
│   Send Device   │
└────────┬────────┘
         │
         │ QR / pairing
         ▼
┌─────────────────┐
│ Authenticated   │
│    Session      │
└────────┬────────┘
         │
         │ streaming
         ▼
┌─────────────────┐
│ Files → Disk    │
└─────────────────┘
```

The receiving device is responsible for advertising its availability.

The sending device searches for available receivers.

QR pairing provides the information required to establish the connection even when discovery alone is insufficient.

---

# MVP Scope

## Included

The MVP includes:

- Send mode.
- Receive mode.
- mDNS device discovery.
- QR-code pairing.
- User-defined device names.
- Persistent device token during the current pairing model.
- Multiple file selection.
- File transfer queue.
- Streaming uploads.
- Streaming downloads.
- Transfer progress.
- Transfer speed.
- Destination storage validation.
- Automatic filename conflict resolution.
- Automatic retries.
- Exponential backoff.
- Cancellation.
- SQLite persistence for required application data.
- Android and macOS as the initial target platforms.
- Responsive UI.
- Accessibility requirements.
- Structured logging.
- Automated CI.

## Not Included in the MVP

The following are intentionally deferred:

- Folder transfers.
- Pause/resume.
- Transfer history.
- Persisted list of known devices.
- Background transfer after application termination.
- Advanced security hardening.
- Additional platforms as primary targets.
- Advanced transfer management.

These are documented as future work rather than being implemented prematurely.

---

# Architecture

Partilha uses a **feature-first architecture** with clear boundaries between presentation, application, domain, and data.

The dependency direction is:

```text
Presentation
     │
     ▼
Application
     │
     ▼
Domain
     ▲
     │
Data
```

The domain contains contracts and business rules while infrastructure-specific implementations remain outside it whenever practical.

### Core principles

- Feature-first organization.
- Explicit contracts between modules.
- Repository interfaces in the domain.
- Repository implementations in the data layer.
- Use cases for application operations.
- DTOs separated from domain entities.
- Explicit DTO ↔ Entity mapping.
- Immutable application state.
- Typed errors.
- Custom `Result<T, E>` pattern.
- Infrastructure exceptions converted at the infrastructure boundary.
- Packages isolated behind interfaces when they represent replaceable infrastructure.
- No unnecessary abstractions.

---

# Project Structure

A simplified structure:

```text
partilha/
├── android/
├── ios/
├── macos/
├── windows/
├── linux/
├── web/
│
├── lib/
│   ├── core/
│   │   ├── errors/
│   │   ├── result/
│   │   ├── logging/
│   │   ├── routing/
│   │   ├── theme/
│   │   ├── icons/
│   │   ├── permissions/
│   │   └── ...
│   │
│   ├── features/
│   │   ├── discovery/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   └── presentation/
│   │   │
│   │   ├── pairing/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   └── presentation/
│   │   │
│   │   ├── file_transfer/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   └── presentation/
│   │   │
│   │   └── settings/
│   │       ├── data/
│   │       ├── domain/
│   │       ├── application/
│   │       └── presentation/
│   │
│   └── main.dart
│
├── test/
├── integration_test/
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── PROTOCOL.md
│   ├── SECURITY.md
│   └── decisions/
│
├── features/
│   ├── discovery/FEATURE.md
│   ├── pairing/FEATURE.md
│   ├── file_transfer/FEATURE.md
│   └── settings/FEATURE.md
│
├── .github/
│
├── AGENTS.md
├── FEATURES.md
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── CHANGELOG.md
├── LICENSE
├── analysis_options.yaml
└── pubspec.yaml
```

Feature documents live under `features/` in the repository root so that
documentation stays out of the compiled application bundle.

The exact structure may evolve as the application grows, but architectural boundaries should remain explicit.

---

# Technology Stack

## Core

- **Flutter**
- **Dart**
- **GetIt** for dependency injection
- **ChangeNotifier** for application controllers
- **freezed** for immutable models and states
- **json_serializable** for JSON serialization
- **go_router** for navigation
- **sqflite** for SQLite persistence

## Networking

- **`dart:io` WebSocket** for device-to-device realtime communication.
- **`dart:io` HTTP server** for accepting and serving the connection.
- **mDNS** for local-network discovery.

No third-party networking package is used. The rationale, and the reason
Socket.IO was rejected, is recorded in
[`docs/decisions/0001-transporte-websocket-dart-io.md`](docs/decisions/0001-transporte-websocket-dart-io.md).

No HTTP client is approved for the MVP. See
[`docs/decisions/0004-sem-dio-no-mvp.md`](docs/decisions/0004-sem-dio-no-mvp.md).

Infrastructure is isolated behind application-owned interfaces where
replacing the underlying implementation is a realistic requirement.

For example:

```text
Application
     │
     ▼
WebSocketTransport
     │
     ▼
dart:io WebSocket
```

The feature depends on `WebSocketTransport`, not directly on `dart:io` socket
mechanics.

---

# Device Discovery

The receiving device acts as the discoverable endpoint.

```text
Receive
   │
   ├── Start local service
   │
   └── Advertise through mDNS
              │
              ▼
          Local Network
              │
              ▼
Send ─────── discovery ───────► Receiver
```

The discovery implementation is isolated behind a project-owned interface.

For example:

```dart
abstract interface class DiscoveryService {
  Future<Result<List<DiscoveredDevice>, Failure>> discover();
  Future<Result<void, Failure>> startAdvertising({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
  });
  Future<Result<void, Failure>> stopAdvertising();
}
```

Discovery returns a bounded single-shot result rather than a live stream, so
that "no devices found yet" and "discovery ended" stay distinguishable instead
of both presenting as a stream that never yields. A long-lived stream remains an
open question. `startAdvertising` deliberately has no `token` parameter: that is
how the "token never in mDNS" rule is enforced structurally.

The concrete implementation may use an mDNS package, but the rest of the application does not need to know which package is being used.

Because the receiving device must **announce** itself, the official
`multicast_dns` package is unsuitable: it is query-only and cannot answer
incoming queries. The candidate provider is `mdns_dart`, pending a validation
spike. See
[`docs/decisions/0002-mdns-provider.md`](docs/decisions/0002-mdns-provider.md).

Discovery metadata is **public, untrusted input**. It must never carry the
device token: mDNS records are plaintext and readable by any host on the
local network. See
[`docs/decisions/0003-token-fora-do-mdns.md`](docs/decisions/0003-token-fora-do-mdns.md).

---

# Pairing

Partilha supports QR-based pairing.

The QR payload contains the information required to establish a connection, including:

- Device ID.
- User-defined device name.
- Host/address.
- Port.
- Device token.
- Protocol information.
- Device capabilities.

A simplified conceptual payload:

```json
{
  "deviceId": "device-id",
  "name": "My MacBook",
  "host": "192.168.1.10",
  "port": 8080,
  "token": "device-token",
  "capabilities": {
    "streaming": true,
    "multipleFiles": true
  }
}
```

The actual payload structure is an implementation detail and may evolve.

QR generation and scanning are isolated behind project-owned services.

---

# File Transfer

Partilha uses **streaming file I/O**.

Files should never be unnecessarily loaded entirely into memory.

Conceptually:

```text
Source File
    │
    │ Stream<List<int>>
    ▼
Network
    │
    │ Stream<List<int>>
    ▼
Destination File
```

This allows the application to handle large files without requiring memory proportional to the complete file size.

## Upload

The sender reads the file progressively and sends the data through the network stream.

## Download

The receiver consumes the network stream and writes chunks progressively to disk.

## Progress

Progress is based on real byte counts:

```text
progress = transferredBytes / totalBytes
```

Transfer speed is calculated dynamically from the amount of data transferred over elapsed time.

---

# Storage Validation

Before a transfer begins, Partilha checks whether the receiving device has enough available storage.

If there is insufficient space:

```text
Transfer
   │
   ▼
Check available storage
   │
   ├── Enough space ─────► Start transfer
   │
   └── Not enough ───────► Reject transfer
```

This prevents starting a transfer that cannot be completed.

---

# Transfer Queue

Multiple files can be selected in one operation.

Each file is treated as an independent queue item.

```text
Queue
├── file-a.jpg
├── file-b.pdf
├── file-c.zip
└── file-d.mp4
```

If one file fails, the queue continues with the next file.

The failed item is marked accordingly.

---

# Retry Policy

Temporary transfer failures use automatic retries.

The MVP uses:

- Maximum attempts: **3**
- Exponential backoff.

Conceptually:

```text
Attempt 1
   │
   └── failure
        │
        ▼
      wait
        │
Attempt 2
   │
   └── failure
        │
        ▼
      wait
        │
Attempt 3
   │
   └── failure → mark as failed
```

Backoff intervals increase progressively rather than retrying continuously.

---

# Cancellation

A transfer can be cancelled by the user.

Cancellation:

- Stops the active transfer.
- Removes the incomplete destination file.
- Does not preserve partial data.
- Allows the rest of the queue to continue according to the queue state.

The MVP intentionally does not support pause/resume.

---

# Filename Conflicts

If the destination already contains a file with the same name, Partilha automatically generates a non-conflicting filename.

For example:

```text
photo.jpg
photo (1).jpg
photo (2).jpg
```

The user does not need to manually resolve every filename conflict.

---

# State Management

Partilha does not use BLoC/Cubit.

Application state is managed with:

- `ChangeNotifier`
- immutable `freezed` states
- State Pattern
- `ListenableBuilder`
- `AnimatedBuilder`

A Controller owns one primary state model.

Conceptually:

```text
TransferController
       │
       ▼
TransferState
 ├── idle
 ├── preparing
 ├── transferring
 ├── completed
 └── error
```

States are immutable.

The Controller replaces the current state instead of mutating the existing state object.

Controllers are intentionally small and responsibility-oriented.

---

# Result Pattern

The project uses a custom `Result<T, E>` instead of introducing a functional-programming dependency solely for `Either`.

Conceptually:

```dart
Result<User, Failure>
```

can represent either:

```text
Success(value)
```

or:

```text
Failure(error)
```

This keeps operation outcomes explicit and avoids using exceptions as normal application control flow.

---

# Error Handling

Errors are typed.

Infrastructure exceptions such as:

- `dart:io` socket errors.
- HTTP errors.
- SQLite errors.
- filesystem errors.
- platform exceptions.

are handled at the infrastructure boundary and converted into application-owned failures.

Infrastructure-specific exceptions should not leak into the domain layer.

Conceptually:

```text
Infrastructure Exception
        │
        ▼
Infrastructure boundary
        │
        ▼
Application Failure
        │
        ▼
Result<T, Failure>
        │
        ▼
Controller State
```

---

# Entities and DTOs

Entities and DTOs are intentionally separate.

```text
API
 │
 ▼
DTO
 │
 │ mapping
 ▼
Entity
 │
 ▼
Application
```

DTOs represent external data contracts.

Entities represent application/domain concepts.

Both may use:

- `freezed`
- `json_serializable`

where applicable.

The conversion between them remains explicit.

---

# Persistence

Partilha uses **SQLite through `sqflite`**.

SQLite access is isolated inside the data layer.

```text
Domain
   │
   ▼
Repository
   │
   ▼
LocalDataSource
   │
   ▼
sqflite
   │
   ▼
SQLite
```

Database schema changes use explicit, versioned migrations.

The application does not recreate the database simply because the schema changes.

---

# Configuration Storage

Persistent application configuration is stored in SQLite.

Examples may include:

- User-defined device name.
- Application configuration required across sessions.

Only information that actually needs persistence should be stored.

The project intentionally avoids persisting unnecessary application state.

---

# Design System

Partilha uses a project-owned design system rather than spreading UI-library dependencies throughout the application.

The design system includes:

- Theme tokens.
- `ThemeExtensions`.
- Typography tokens.
- `AppTextStyles`.
- `AppIcons`.
- Reusable components.
- Responsive layout primitives.
- Accessibility conventions.

## Icons

The application uses **HugeIcons** rather than Flutter Material Icons.

The UI should not import HugeIcons directly.

Instead:

```dart
AppIcons.send
AppIcons.receive
AppIcons.file
AppIcons.settings
```

This allows the underlying icon library to change without requiring changes throughout the UI.

---

# Responsive UI

Responsiveness is considered from the beginning rather than added after the mobile UI is complete.

The application should account for:

- Phones.
- Tablets.
- Desktop windows.
- Different aspect ratios.
- Window resizing where supported.

Android and macOS are the initial platform priorities.

---

# Accessibility

Accessibility is treated as a product requirement.

The UI should consider:

- Semantic labels.
- Appropriate contrast.
- Touch target sizes.
- Keyboard/mouse interaction where applicable.
- Text scaling.
- Screen-reader compatibility.
- Clear interaction states.
- Meaningful error messages.

Accessibility should not be treated as a final polishing phase.

---

# Performance

Performance is an architectural concern.

The project should prioritize:

- Streaming instead of loading complete files.
- Avoiding unnecessary memory allocations.
- Avoiding unnecessary data copies.
- Avoiding expensive work on the UI isolate.
- Using isolates when appropriate.
- Minimizing unnecessary rebuilds.
- Lazy loading where meaningful.
- Efficient database access.
- Efficient network usage.
- Measuring before applying speculative optimizations.

The goal is not to optimize everything prematurely, but to avoid architectural decisions that create unnecessary performance problems.

---

# Logging

Partilha uses structured logging.

Logs should have appropriate levels such as:

```text
debug
info
warning
error
```

Production code should not use `print`.

Logging should provide useful context without exposing sensitive information.

---

# Security

The MVP uses a persistent device token as part of the pairing model.

The token **never leaves the device through discovery metadata**. mDNS records
are plaintext and readable by any host on the local network, so advertising the
token there would allow any neighbour to harvest it and impersonate the device.
The QR code is the only approved channel that may carry the token.

Advanced security hardening is intentionally deferred.

The approved security model is documented in
[`docs/SECURITY.md`](docs/SECURITY.md).

Potential future security work may include:

- Stronger authentication.
- Token rotation.
- Token expiration.
- Encrypted transport.
- Device trust management.
- Pairing revocation.
- Replay protection.
- Stronger session validation.

Security mechanisms should be introduced deliberately and documented rather than invented independently by individual features.

---

# Platform Support Status

Partilha targets Android and macOS first. Other platforms are present in the
repository as unmodified `flutter create` scaffolding so that contributors can
start work without regenerating the project, **not** because the application
works there.

| Platform | Folder | Status | Built / tested |
|---|---|---|---|
| Android | `android/` | **Primary target** — not implemented yet | No |
| macOS | `macos/` | **Primary target** — not implemented yet | No |
| iOS | `ios/` | Scaffold only | No |
| Windows | `windows/` | Scaffold only | No |
| Linux | `linux/` | Scaffold only | No |
| Web | `web/` | Scaffold only | No |

Status vocabulary:

- **Primary target** — inside the approved scope (`AGENTS.md` §41). Work is
  planned and expected, but nothing is implemented yet.
- **Scaffold only** — the platform folder exists, its contents are untouched
  `flutter create` output, and no feature, permission or platform service has
  been written for it. These platforms are **not supported**: they are neither
  built nor tested, and no behaviour is guaranteed.

Architectural readiness is not platform support. No feature is implemented on
any platform at this point, and no platform-specific behaviour has been
validated on real hardware.

Additional platforms may have different capabilities or platform-specific
implementations. Platform-specific behavior should be isolated behind
appropriate services where necessary, so that adding a platform does not
touch business logic.

### Keeping this table honest

The table is the single place where platform support is claimed. When a
platform gains a working implementation, a build, or a real-device test, this
table and `docs/ARCHITECTURE.md` §48 must be updated in the same change.

Promoting a platform requires more than a folder existing:

- the feature actually builds and runs on it;
- the permissions it needs are declared and requested through
  `PermissionService` (`AGENTS.md` §40);
- platform-specific behavior is isolated in a project-owned service
  (`AGENTS.md` §41, §49);
- it is built and exercised in CI or documented as manually verified
  (`AGENTS.md` §64);
- its limitations are recorded in `features/<feature>/FEATURE.md`.

Contributions targeting a scaffold-only platform are welcome. Such a change
should update this table rather than assume it.

---

# Development

## Requirements

Before starting development, install:

- Flutter SDK.
- Dart SDK compatible with the project.
- Android development environment for Android builds.
- Xcode for macOS/iOS development.
- Git.

Verify Flutter:

```bash
flutter doctor
```

---

## Install dependencies

Clone the repository:

```bash
git clone <repository-url>
cd partilha
```

Install dependencies:

```bash
flutter pub get
```

Generate code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For development with automatic regeneration:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## Run the application

Android:

```bash
flutter run
```

macOS:

```bash
flutter run -d macos
```

List available devices:

```bash
flutter devices
```

---

# Code Generation

Partilha uses generated code extensively where it provides real value.

Primary tools include:

- `freezed`
- `json_serializable`
- `build_runner`

Generated code should not be manually edited.

After changing annotated models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

# Testing

Testing is divided into several levels.

## Unit tests

Used for:

- Domain rules.
- Use cases.
- Result handling.
- Mappers.
- Repositories.
- Services.
- Controllers where appropriate.

## Integration tests

Used for critical flows such as:

- Device discovery.
- Pairing.
- SQLite behavior.
- File transfer.
- Transfer queue behavior.
- Retry behavior.

## UI tests

Used where UI behavior itself is important.

The goal is not maximum test count.

The goal is **meaningful confidence in critical behavior**.

---

# Code Quality

Before a change is considered complete, it should pass:

```bash
flutter analyze
```

and:

```bash
flutter test
```

Where relevant, platform-specific builds and integration tests should also be executed.

The project uses strict linting and additional project-specific rules.

New warnings should not be introduced.

---

# CI/CD

Continuous integration is enabled from the beginning.

The CI pipeline should validate the project through checks such as:

```text
Dependencies
     │
     ▼
Code generation
     │
     ▼
Static analysis
     │
     ▼
Unit tests
     │
     ▼
Integration/build checks
```

A Pull Request should not be considered mergeable while required CI checks are failing.

---

# Git Workflow

Partilha uses a simplified **trunk-based development** workflow.

The `main` branch is protected.

Development happens through short-lived branches.

## Branch naming

```text
feat/file-transfer
fix/qr-scanner
refactor/network-layer
docs/architecture
test/transfer-queue
chore/update-dependencies
```

## Conventional Commits

Commit messages follow Conventional Commits.

Examples:

```text
feat: add local device discovery
fix: prevent transfer when storage is insufficient
refactor: isolate websocket transport
test: add transfer retry tests
docs: document pairing protocol
chore: update flutter dependencies
```

---

# Pull Requests

Pull Requests should contain:

- Clear description.
- Motivation.
- Summary of changes.
- Tests performed.
- Relevant screenshots for UI changes.
- Known limitations.
- Potential risks.

Before a PR is considered complete, review should cover:

- Architecture.
- Correctness.
- Tests.
- Lint.
- Performance.
- Security.
- Documentation.
- Scope.

The Agent may prepare a Pull Request, but publication requires explicit approval.

---

# Releases

Partilha follows **Semantic Versioning**:

```text
MAJOR.MINOR.PATCH
```

Example:

```text
1.0.0
1.1.0
1.1.1
```

Releases use Git tags.

The project maintains a `CHANGELOG.md` following the principles of **Keep a Changelog**.

Typical sections include:

- Added
- Changed
- Deprecated
- Removed
- Fixed
- Security

Release operations require explicit approval.

---

# Documentation

The project maintains several documentation levels.

## README.md

Provides the public project overview:

- What Partilha is.
- How it works.
- Architecture.
- Development.
- Contribution.
- Roadmap.

## AGENTS.md

Contains instructions for AI coding agents working on the repository.

It defines:

- Architectural rules.
- Coding conventions.
- Dependency rules.
- Testing requirements.
- Performance requirements.
- Documentation expectations.
- Git behavior.
- Approval boundaries.

An Agent must not silently change an architectural decision documented there.

## FEATURES.md

`FEATURES.md` in the repository root is the master feature specification.

It defines:

- Which features exist.
- What each feature owns.
- Which sections of the per-feature documentation must exist.

## FEATURE.md

Each feature owns one authoritative document at
`features/<feature>/FEATURE.md`.

Feature documents live in the repository root, not inside `lib/`, so that
documentation stays out of the compiled application bundle.

A feature document covers:

- Purpose.
- User flow.
- Business rules.
- States.
- Architecture.
- Contracts.
- Technical decisions.
- Dependencies.
- Failure scenarios.
- Limitations.
- Future work.

Feature documentation may describe both the current implementation and explicitly separated future decisions.

## docs/decisions/

Significant architectural decisions are recorded as numbered documents.

Each record states the context, the decision, the rejected alternatives, and
the consequences. See
[`0001-transporte-websocket-dart-io.md`](docs/decisions/0001-transporte-websocket-dart-io.md).

---

# Project Principles

Partilha follows a few fundamental principles.

### 1. Keep dependencies at the boundaries

Infrastructure packages should not leak throughout the application.

### 2. Prefer explicit contracts

Interfaces should describe real boundaries and responsibilities.

### 3. Do not abstract for the sake of abstraction

An abstraction should exist because it provides meaningful isolation, substitution, or architectural value.

### 4. Stream large data

Files should not be unnecessarily loaded into memory.

### 5. Keep state predictable

Application state should be immutable and explicit.

### 6. Fail explicitly

Typed failures and `Result<T, E>` should make expected failure paths visible.

### 7. Keep features independent

A feature should not become tightly coupled to unrelated features.

### 8. Measure performance

Avoid speculative optimization while preventing obvious architectural performance problems.

### 9. Document decisions

Important technical decisions should be discoverable by future contributors.

### 10. Do not change architecture silently

Architectural changes require deliberate review and approval.

---

# Roadmap

The roadmap is intentionally separated from the MVP.

## Current

The project is **pre-implementation**. The items below are approved
*designs and decisions*, not shipped code. Nothing in `lib/` implements them
yet.

- [ ] Project foundation (structure, DI, Result, logger, routing, design system)
- [ ] Settings and device identity
- [ ] Feature-first architecture scaffold
- [ ] Android + macOS as primary targets
- [ ] mDNS discovery (provider pending validation spike)
- [ ] QR pairing
- [ ] Streaming transfer
- [ ] Transfer queue
- [ ] Retry strategy
- [ ] SQLite persistence
- [ ] Custom Result Pattern
- [ ] ChangeNotifier + State Pattern
- [ ] Design System

## Planned

- [ ] Folder transfers
- [ ] Pause/resume
- [ ] Transfer history
- [ ] Known-device management
- [ ] Background transfers
- [ ] Stronger authentication
- [ ] Token rotation/expiration
- [ ] Additional platform support
- [ ] Advanced transfer controls
- [ ] Further security hardening

The roadmap is subject to change as the project evolves.

---

# Contributing

Contributions are welcome.

Before contributing, please read:

- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `AGENTS.md`

For significant architectural changes, open a discussion or issue before implementation.

Small fixes and improvements should generally follow the existing project conventions.

Please keep Pull Requests focused on a single logical change whenever possible.

---

# License

Partilha is released under the **MIT License**.

See the [`LICENSE`](LICENSE) file for the applicable terms.

---

# Status

Partilha is pre-implementation. The architecture and feature specification are
complete and approved; the application itself has not been built yet.

The architecture and APIs may change before the first stable release.

The MVP prioritizes a reliable foundation for local device-to-device file transfer before adding advanced functionality.
