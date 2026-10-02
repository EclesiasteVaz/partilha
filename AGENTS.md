# AGENTS.md

# Partilha — AI Agent Engineering Guidelines

This document defines the engineering rules, architectural constraints, development workflow, quality standards, and decision boundaries that AI coding agents must follow when working on **Partilha**.

Partilha is an open-source Flutter application focused on local file sharing between nearby devices, initially targeting **Android and macOS**.

This document is authoritative for AI-assisted development.

If an agent encounters a situation that conflicts with these rules, it must **stop and ask for clarification or approval** instead of silently changing the architecture.

---

## 1. Core Principle

The agent is expected to behave as a senior software engineer working inside an existing codebase.

The objective is not to generate the largest amount of code.

The objective is to produce code that is:

- correct;
- understandable;
- maintainable;
- testable;
- performant;
- secure within the defined security model;
- accessible;
- platform-aware;
- consistent with the existing architecture;
- limited to the requested scope.

Do not optimize for code volume.

Do not introduce abstractions merely because they are theoretically possible.

Do not introduce complexity without a concrete engineering reason.

---

# 2. Absolute Rules

The following rules are mandatory.

## 2.1 Do not silently change architecture

The architecture defined in this document is intentional.

The agent must **stop and request approval** before:

- changing the dependency direction;
- replacing the state-management approach;
- replacing the routing solution;
- replacing the networking stack;
- replacing the persistence technology;
- introducing a new architectural layer;
- removing an architectural layer;
- changing the feature-first structure;
- introducing a new cross-cutting abstraction that affects multiple features;
- changing the transfer protocol;
- changing the pairing model;
- changing the security model;
- changing the storage strategy;
- changing the dependency injection strategy.

If the current architecture appears problematic, explain:

1. the problem;
2. the evidence;
3. the impact;
4. the proposed alternative;
5. the migration implications.

Then wait for approval.

---

## 2.2 Do not invent requirements

Implement only requirements that are:

- explicitly requested;
- documented in the relevant `FEATURE.md`;
- established by the current architecture;
- necessary to make the requested behavior function correctly.

Do not invent:

- product features;
- security mechanisms;
- synchronization mechanisms;
- background processing;
- analytics;
- telemetry;
- notifications;
- persistence;
- business rules;
- protocol capabilities;
- permissions;
- retry behavior;
- UI flows.

If a requirement is unclear and the decision affects architecture or user-visible behavior, stop and ask.

---

## 2.3 Do not perform unrelated refactoring

If a task is:

> Implement file transfer progress.

Do not simultaneously:

- reorganize unrelated folders;
- rename unrelated classes;
- migrate dependencies;
- rewrite existing controllers;
- change the design system;
- refactor unrelated repositories;
- modify unrelated features.

If an unrelated issue is discovered, report it separately.

Small local cleanup is acceptable only when it is necessary for the requested implementation and does not alter architecture.

---

## 2.4 Do not blindly follow generated code

Generated code is a tool, not an architectural decision.

Before accepting generated code, verify:

- generated types are correct;
- serialization behavior is correct;
- nullability is correct;
- equality semantics are correct;
- generated state transitions remain understandable;
- generated code does not introduce unnecessary dependencies;
- generated code does not leak infrastructure concerns into domain models.

---

# 3. Architectural Philosophy

Partilha follows a **feature-first Clean Architecture** approach.

The architecture prioritizes:

- clear ownership;
- explicit contracts;
- dependency inversion;
- replaceable infrastructure;
- predictable state management;
- streaming I/O;
- platform isolation;
- testability;
- performance.

The architecture is intentionally pragmatic.

It does not pursue theoretical purity at the cost of unnecessary complexity.

---

# 4. Project Structure

The primary structure is:

```text
lib/
├── core/
│   ├── errors/
│   ├── result/
│   ├── logging/
│   ├── network/
│   ├── routing/
│   ├── theme/
│   ├── icons/
│   ├── permissions/
│   └── ...
│
├── features/
│   ├── discovery/
│   │   ├── presentation/
│   │   ├── application/
│   │   ├── domain/
│   │   └── data/
│   │
│   ├── pairing/
│   │   ├── presentation/
│   │   ├── application/
│   │   ├── domain/
│   │   └── data/
│   │
│   ├── file_transfer/
│   │   ├── presentation/
│   │   ├── application/
│   │   ├── domain/
│   │   └── data/
│   │
│   └── settings/
│       ├── presentation/
│       ├── application/
│       ├── domain/
│       └── data/
│
└── main.dart
```

The exact feature list may evolve.

Do not create directories for hypothetical future features unless they are actually being implemented.

---

# 5. Dependency Direction

The intended dependency direction is:

```text
Presentation
     ↓
Application
     ↓
Domain
     ↑
Data
```

More explicitly:

```text
presentation → application → domain
data         → domain
```

## Presentation

Responsible for:

- screens;
- widgets;
- controllers;
- UI state;
- user interaction;
- presentation-specific transformations.

Presentation must not directly depend on infrastructure packages when a project-owned abstraction exists.

---

## Application

Responsible for:

- use cases;
- orchestration;
- application-level workflows;
- coordinating repositories and services.

Application should not contain UI logic.

Application should not directly depend on infrastructure implementations.

---

## Domain

Responsible for:

- entities;
- repository contracts;
- service contracts;
- domain-level models;
- business-relevant rules;
- failures;
- Result types;
- use-case contracts where appropriate.

Domain must not know about:

- Flutter widgets;
- `dart:io` socket mechanics;
- sqflite;
- mDNS package APIs;
- QR package APIs;
- permission package APIs;
- platform-specific implementation details.

The domain may use selected development/code-generation packages such as:

- Freezed;
- JSON Serializable;
- the project's custom Result implementation.

Domain purity is not pursued at the expense of practicality.

---

## Data

Responsible for:

- repository implementations;
- data sources;
- network implementations;
- local database implementations;
- DTOs;
- entity ↔ DTO mapping;
- infrastructure-specific error conversion.

Infrastructure exceptions must not leak into domain or presentation.

---

# 6. Feature Boundaries

Every feature should own its behavior.

For example:

```text
features/
└── transfer/
    ├── presentation/
    ├── application/
    ├── domain/
    └── data/
```

Avoid creating global abstractions when the behavior belongs to a single feature.

A shared abstraction should only be introduced when:

- multiple features genuinely need it;
- its responsibility is stable;
- ownership is clear;
- duplication would create real maintenance problems.

Do not create a `utils/` dumping ground.

Do not create generic helpers merely to avoid a few lines of code.

---

# 7. Barrel Files

Barrel files are intentionally used in Partilha.

Each feature and layer may expose its public API through a barrel file.

Example:

```text
file_transfer/
├── presentation/
│   └── presentation.dart
├── application/
│   └── application.dart
├── domain/
│   └── domain.dart
└── data/
    └── data.dart
```

The purpose is to:

- simplify imports;
- define public boundaries;
- avoid large import lists;
- make feature APIs easier to understand.

Do not create arbitrary nested barrel files solely for the sake of having more barrel files.

Avoid circular exports.

---

# 8. Models

Partilha distinguishes between:

```text
Entity
DTO
```

They are not interchangeable.

## Entities

Entities represent application/domain concepts.

They should not contain infrastructure concerns.

## DTOs

DTOs represent external data contracts.

Examples:

- network payloads;
- persisted database structures;
- protocol messages.

DTOs must not automatically become domain entities.

Explicit mapping is required:

```text
DTO
 ↓
Mapper
 ↓
Entity
```

and, where necessary:

```text
Entity
 ↓
Mapper
 ↓
DTO
```

---

# 9. Code Generation

Use:

- `freezed`;
- `json_serializable`;

whenever appropriate for:

- entities;
- DTOs;
- immutable state models;
- serializable protocol models.

Generated files must not be manually edited.

After modifying annotated models, regenerate code and verify the generated output through compilation/tests.

Do not commit stale generated code.

---

# 10. State Management

Partilha does **not** use BLoC or Cubit.

The state-management strategy is:

```text
ChangeNotifier
+
Immutable Freezed State
+
State Pattern
```

Controllers live in:

```text
presentation/
```

A controller should have a clear and limited responsibility.

Example conceptual structure:

```text
TransferController
    ↓
TransferState
```

State should represent explicit states such as:

```text
initial
loading
ready
transferring
success
error
```

The exact states depend on the feature.

Do not create artificial state variations merely to increase granularity.

---

## 10.1 UI Binding

UI listens using Flutter's native mechanisms, such as:

- `ListenableBuilder`;
- `AnimatedBuilder`.

Do not introduce Provider solely to expose controllers.

Controllers are resolved through GetIt.

---

## 10.2 Controller Responsibilities

Controllers may:

- receive user actions;
- invoke use cases;
- update immutable state;
- coordinate presentation behavior.

Controllers must not:

- implement repository logic;
- access sqflite directly;
- call `dart:io` socket APIs directly;
- call mDNS package APIs directly;
- contain platform-specific infrastructure;
- become a second domain layer.

If a controller becomes large, identify the actual responsibility that should move to application/domain.

Do not automatically split it into arbitrary classes.

---

# 11. Dependency Injection

Partilha uses:

```text
GetIt
```

for dependency injection and lifecycle management.

Use the appropriate lifecycle:

- `factory`;
- `lazySingleton`;
- `singleton`.

Choose based on actual ownership and lifecycle requirements.

Do not register every object as a singleton.

Do not introduce service locators in domain code.

Dependency registration belongs to the composition root/infrastructure setup.

---

# 12. Use Cases

Partilha uses explicit Use Cases.

The project follows the decision:

> Every repository/service method exposed to application logic should have an appropriate Use Case.

Example:

```text
GetNearbyDevicesUseCase
PairDeviceUseCase
SendFileUseCase
CancelTransferUseCase
GetTransferStatusUseCase
```

A Use Case should represent an application action.

Avoid putting unrelated operations into one enormous service.

Do not create artificial business logic merely to justify a Use Case.

---

# 13. Repository Pattern

Repository contracts belong to:

```text
domain/
```

Implementations belong to:

```text
data/
```

Example:

```text
domain/
└── repositories/
    └── transfer_repository.dart

data/
└── repositories/
    └── sqlite_transfer_repository.dart
```

Implementations are named after the technology they use. This keeps the name
meaningful and avoids the banned `Impl` suffix described in section 17.

Repositories should expose application-relevant operations rather than infrastructure details.

---

# 14. Result and Failure Handling

Partilha uses a custom:

```text
Result<T, E>
```

pattern.

Do not introduce:

- `dartz`;
- `fpdart`;
- another Result/Either implementation.

unless the architecture is explicitly changed with approval.

Failures should be typed.

Example conceptual categories:

```text
NetworkFailure
StorageFailure
PermissionFailure
DiscoveryFailure
PairingFailure
TransferFailure
ValidationFailure
UnknownFailure
```

The actual failure hierarchy should remain coherent and avoid excessive fragmentation.

---

# 15. Exceptions

Infrastructure exceptions must be handled at infrastructure boundaries.

Example:

```text
SocketException
HttpException
DatabaseException
PlatformException
```

must not leak through the application's public domain contracts.

Convert them into project-owned failures.

Conceptually:

```text
Infrastructure Exception
        ↓
Data Layer
        ↓
Failure
        ↓
Result<T, Failure>
```

Do not use broad `catch` blocks that silently discard the original cause.

Preserve useful diagnostic information in logs.

Do not expose sensitive information through errors.

---

# 16. Networking

The project uses:

- `dart:io` WebSocket for device-to-device communication;
- `dart:io` HTTP server for accepting and serving connections.

The MVP does **not** use a third-party networking package. This decision is
recorded in `docs/decisions/0001-transporte-websocket-dart-io.md`.

HTTP client usage is **not approved** for the MVP. If a future flow genuinely
requires it, that is a separate approved decision. See
`docs/decisions/0004-sem-dio-no-mvp.md`.

Infrastructure must remain isolated behind project-owned abstractions where practical.

Examples:

```text
WebSocketTransport
```

Do not name implementations with meaningless suffixes such as:

```text
NetworkClientImpl
RepositoryImpl
ServiceImpl
```

Prefer explicit names describing the implementation.

---

# 17. Network Abstraction Rule

The purpose of abstraction is replaceability, not abstraction for its own sake.

Good:

```text
Transport
    ↓
WebSocketTransport
```

Avoid:

```text
SocketWrapper
SocketManager
SocketHelper
SocketUtils
```

with no meaningful architectural responsibility.

If a package can realistically be replaced and the abstraction has a stable contract, isolate it.

If the abstraction only adds indirection without protecting the architecture, do not create it.

---

# 18. Realtime Communication

Device-to-device realtime communication uses a raw WebSocket over `dart:io`.

Feature/application code must not depend directly on socket mechanics.

The realtime layer should expose meaningful application operations rather than raw socket mechanics whenever possible.

Do not leak:

- `WebSocket` connection objects;
- socket frames or stream events;
- `SocketException` or other `dart:io` exception types;

into domain contracts.

---

# 19. File Transfer

File transfer is a core architectural concern.

The implementation must be **stream-based**.

Never load an entire file into memory just to transfer it.

Use:

```dart
Stream<List<int>>
```

for file streaming.

Transfers should progressively read/write data.

Conceptually:

```text
File
 ↓
Stream<List<int>>
 ↓
Network
 ↓
Progressive Write
 ↓
Destination File
```

The implementation must avoid unnecessary intermediate copies.

---

# 20. File Transfer Progress

Progress must be based on actual bytes transferred.

Conceptually:

```text
progress = bytesTransferred / totalBytes
```

Do not estimate progress from:

- number of chunks;
- elapsed time;
- arbitrary percentages.

Transfer speed should be dynamically calculated from actual transfer data.

---

# 21. Large Files and Memory

The application must remain usable when transferring large files.

Do not:

```text
readAsBytes()
```

for an entire large file unless there is a specific, justified reason.

Avoid:

- loading entire files into memory;
- duplicating large buffers;
- unnecessary conversions;
- copying streams into intermediate collections.

Performance is an architectural requirement.

---

# 22. Isolates and Heavy Work

Use isolates or other appropriate mechanisms when work can block the UI thread.

Candidates include:

- CPU-heavy processing;
- large data transformations;
- expensive parsing;
- expensive hashing/computation if introduced;
- other measurable CPU-bound operations.

Do not introduce isolates automatically for trivial work.

The decision should be based on:

- complexity;
- workload;
- measurable performance impact;
- platform behavior.

---

# 23. File Storage

The MVP stores received files directly in the system's appropriate:

```text
Downloads / Transfers
```

location.

Do not introduce a custom storage location without a documented requirement.

---

# 24. Storage Validation

Before starting a transfer, the receiving device must verify available destination storage.

If there is insufficient space:

```text
Transfer must not start.
```

The failure should be surfaced as a typed failure.

Do not begin a transfer and wait for the filesystem to fail after partially writing the file.

---

# 25. File Selection

The MVP supports:

- individual file selection;
- multiple file selection.

Folder transfer is not part of the MVP.

Do not implement folder transfer unless explicitly requested.

---

# 26. Transfer Queue

Multiple selected files are queued.

The queue must continue when an individual file fails.

Conceptually:

```text
File A → success
File B → failure
File C → continue
File D → continue
```

A single failed transfer must not automatically terminate the entire queue.

---

# 27. Automatic Retry

Failed transfers are automatically retried.

Maximum:

```text
3 attempts
```

Use backoff between attempts.

Example:

```text
Attempt 1
   ↓
1 second
   ↓
Attempt 2
   ↓
2 seconds
   ↓
Attempt 3
   ↓
Failure
```

The exact delay mechanism may evolve, but retries must remain bounded.

Do not create infinite retry loops.

Do not retry failures that are clearly non-retryable unless the feature explicitly defines otherwise.

---

# 28. Cancellation

Cancellation must be immediate from the application's perspective.

When a transfer is cancelled:

1. stop the transfer;
2. stop ongoing streaming;
3. delete the partial destination file;
4. update the transfer state.

Do not leave corrupted or incomplete files in the user's Downloads/Transfers directory.

---

# 29. Duplicate Filenames

If a destination file already exists, do not overwrite it by default.

Generate a new filename.

Example:

```text
photo.jpg
photo (1).jpg
photo (2).jpg
```

Preserve the original extension.

The conflict-resolution logic must be deterministic.

---

# 30. Background Transfer

Background transfer is **not part of the MVP**.

If the application closes:

```text
active transfer → cancelled
```

Do not introduce:

- background services;
- background isolates;
- OS-level transfer daemons;
- background execution permissions;

unless explicitly requested and architecturally approved.

---

# 31. Transfer History

Persistent transfer history is not part of the MVP.

Do not create a database table merely to support hypothetical history.

---

# 32. Known Devices

Known devices are not persisted.

Each pairing begins from a fresh state.

Do not create a "trusted devices" database unless the product requirement changes.

---

# 33. Device Identity

Each device has a persistent device token.

This token is part of the device identity/pairing model.

Do not interpret this as permission to create a persistent "known devices" registry.

These are separate concerns:

```text
Device identity
≠
Persisted known-device list
```

---

# 34. Device Name

The device name is user-defined.

Do not infer it from:

- email;
- account name;
- hostname;

unless explicitly required by the feature.

---

# 35. Device Discovery

mDNS is used for local discovery.

The architecture separates discovery behavior from the mDNS package.

Use a project-owned service such as:

```text
DiscoveryService
```

with an infrastructure implementation such as:

```text
MdnsDiscoveryService
```

The package API must not leak into feature/application code.

The discovery model requires the receiving device to **announce** itself. The
official `multicast_dns` package is query-only and cannot answer incoming
queries, so it cannot satisfy the approved model on its own. The candidate
provider is `mdns_dart`, pending a validation spike. See
`docs/decisions/0002-mdns-provider.md`.

The provider choice must be recorded before Discovery implementation begins.

---

# 36. Discovery Model

The current model is:

```text
Receiving device:
announces itself

Sending device:
searches for devices
```

Do not reverse this behavior without an explicit architectural decision.

---

# 37. QR Pairing

QR codes contain enough information to establish a connection.

The QR payload may contain:

```text
device ID
device name
host/address
port
token
capabilities
protocol-related information
```

The exact payload is a protocol contract.

Do not casually add or remove fields.

If a QR payload change affects interoperability, stop and request approval.

---

# 38. Protocol

The MVP uses JSON-based typed messages.

The MVP does **not** introduce protocol versioning.

Do not invent:

```text
v1
v2
protocolVersion
```

fields merely because versioning may be useful later.

Future protocol evolution can be documented in `FEATURE.md`.

Messages should be represented by typed code models and serialized explicitly.

---

# 39. QR Code Packages

QR scanning and generation must be isolated behind project-owned abstractions.

For example:

```text
QrCodeScanner
QrCodeService
```

UI and feature logic should not depend directly on the QR package.

This allows the implementation package to be replaced without rewriting feature logic.

---

# 40. Permissions

Permissions are accessed through a project-owned abstraction.

For example:

```text
PermissionService
```

The rest of the application should not directly depend on the permission package or platform APIs.

Permission handling must be:

- explicit;
- predictable;
- platform-aware;
- appropriately scoped.

Do not request permissions that are not required.

---

# 41. Platform Abstraction

Platform-specific behavior must be isolated.

Do not scatter:

```dart
Platform.isAndroid
Platform.isMacOS
Platform.isWindows
```

throughout the application.

Prefer project-owned platform services where platform differences matter.

The architecture must remain prepared for:

- Android;
- macOS;
- iOS;
- Windows;
- Linux.

Initial implementation priority:

```text
Android
macOS
```

Do not claim support for platforms that have not actually been implemented and tested.

## 41.1 Platform support status

The repository contains a `flutter create` folder for every platform the SDK
supports. A platform folder is **not** a support claim.

Support status is recorded in exactly two places, which must be updated in the
same change whenever platform status moves:

```text
README.md → Platform Support Status        (user-facing)
docs/ARCHITECTURE.md §48.1                  (technical source of truth)
```

Status vocabulary:

```text
Primary target  →  approved scope; planned
Scaffold only   →  folder exists, untouched `flutter create` output,
                   nothing implemented for the platform
Not supported   →  not built, not tested, no behaviour guaranteed
```

Currently `ios/`, `linux/`, `windows/` and `web/` are scaffold only. They are
retained deliberately so platform contributions can start without regenerating
the project. See `docs/decisions/0005-estado-das-plataformas.md`.

The agent must not describe a scaffold-only platform as supported, planned for
near-term delivery, or tested. When implementing or validating a platform, the
agent must update both status locations in the same change, and must record the
platform's limitations in the relevant `features/<feature>/FEATURE.md`.

Promoting a platform requires a real build, permissions requested through
`PermissionService`, isolated platform behaviour, and a recorded test run — not
merely the existence of a folder.

---

# 42. Dart IO

For filesystem operations, the project intentionally uses:

```text
dart:io
```

directly inside appropriate features/data infrastructure.

Do not create an artificial `FileStorage` abstraction merely for theoretical purity.

Create an abstraction only when there is a concrete architectural reason.

---

# 43. SQLite

SQLite is used through:

```text
sqflite
```

The package must remain inside the data layer.

Expected structure:

```text
LocalDataSource
      ↓
Repository
```

Do not access sqflite directly from:

- presentation;
- controllers;
- application;
- domain.

---

# 44. Database Migrations

Database schema changes must use explicit, versioned migrations.

Never silently recreate production data structures.

A migration should:

1. have a clear version;
2. describe the schema transition;
3. preserve existing data where required;
4. be deterministic;
5. be testable.

---

# 45. Persistent State

Persist only data that actually needs persistence.

Do not persist:

- temporary UI state;
- ephemeral transfer state;
- unnecessary caches;
- arbitrary controller state.

Controllers should load persistent information when needed.

---

# 46. UI Architecture

The UI uses a project-owned design system.

The design system should centralize:

- colors;
- typography;
- spacing;
- radii;
- elevation;
- component behavior;
- themes;
- iconography.

Use:

```text
ThemeExtensions
```

where appropriate.

Do not hard-code design tokens repeatedly throughout widgets.

---

# 47. Icons

The project uses **HugeIcons**.

UI code should not import the HugeIcons package directly.

Expose icons through a project-owned API such as:

```text
AppIcons
```

Example conceptual usage:

```dart
AppIcons.send
AppIcons.download
AppIcons.devices
```

This allows the icon implementation to change without rewriting the UI.

---

# 48. Typography

Typography is owned by the design system.

Use project-defined text styles such as:

```text
AppTextStyles
```

Do not repeatedly create arbitrary `TextStyle` instances when an existing design token applies.

Do not introduce typography inconsistencies.

---

# 49. Responsive Design

Responsive behavior is required from the beginning.

The application must consider:

- mobile;
- tablet;
- desktop.

Do not build a mobile layout and simply stretch it onto desktop.

When designing a screen, consider:

- available width;
- navigation model;
- content density;
- pointer interaction;
- keyboard interaction;
- window resizing.

---

# 50. Accessibility

Accessibility is a project requirement.

Consider:

- semantic labels;
- accessible controls;
- sufficient contrast;
- appropriate touch targets;
- text scaling;
- focus behavior;
- keyboard navigation where applicable;
- meaningful status announcements where appropriate.

Do not treat accessibility as a final polish step.

---

# 51. UI Package Isolation

UI code should not directly import infrastructure packages when a project-owned abstraction exists.

Examples:

```text
HugeIcons → AppIcons
QR package → QrCodeService
Permission package → PermissionService
mDNS package → DiscoveryService
dart:io WebSocket → WebSocketTransport
```

The purpose is to keep implementation details replaceable.

---

# 52. Logging

Production code must not use:

```dart
print()
```

Use the project's structured logger.

The logger supports appropriate levels such as:

```text
debug
info
warning
error
```

Logs should provide useful diagnostic context.

Do not log:

- authentication tokens;
- private user information;
- sensitive file contents;
- unnecessary personal data;
- secrets.

---

# 53. Security

Security implementation must follow the explicitly defined security model.

The agent must **not invent additional security architecture**.

For the current MVP, the defined pairing mechanism uses a persistent device token.

Potential future security hardening should be documented separately rather than silently implemented.

If the agent identifies a serious security risk:

1. stop if fixing it would change the architecture;
2. describe the risk;
3. explain the affected component;
4. propose a solution;
5. request approval when the solution changes the documented security model.

Security issues must never be hidden because they are outside the immediate task.

---

# 54. Dependency Management

Use stable package versions compatible with the project's Flutter/Dart SDK.

Do not update unrelated dependencies simply because newer versions exist.

A dependency update should have a reason, such as:

- required by the requested feature;
- security fix;
- compatibility issue;
- bug fix;
- necessary platform support.

Avoid dependency churn.

Before adding a package, ask:

1. Is it actually necessary?
2. Can the existing stack solve the problem?
3. Does it introduce a significant maintenance burden?
4. Does it require an abstraction?
5. Does it affect supported platforms?
6. Is it compatible with the project's architecture?

---

# 55. New Dependencies

Before introducing a dependency, evaluate:

- maintenance status;
- Flutter/Dart compatibility;
- Android compatibility;
- macOS compatibility;
- transitive dependencies;
- API stability;
- licensing;
- package maturity;
- whether it duplicates existing functionality.

Do not introduce a dependency for trivial functionality that can reasonably be implemented using the SDK or existing project infrastructure.

---

# 56. Naming

Names must communicate responsibility.

Prefer:

```text
WebSocketTransport
MdnsDiscoveryService
PermissionService
SendFileUseCase
TransferRepository
TransferController
```

Avoid vague names:

```text
Helper
Manager
Utils
Common
Thing
Service
Impl
```

unless the name genuinely represents a meaningful responsibility.

---

# 57. Comments and Documentation

Comments must explain **why**, not repeat **what** the code already says.

Bad:

```dart
// Increment the counter.
counter++;
```

Good:

```dart
// Keep the retry count outside the stream lifecycle so reconnecting
// does not accidentally reset the transfer retry budget.
```

Use Dartdoc selectively for:

- public APIs;
- reusable contracts;
- non-obvious behavior;
- important protocol contracts;
- architectural boundaries.

Do not document obvious implementation details.

---

# 58. FEATURE.md

Complex features should contain a `FEATURE.md`.

`FEATURE.md` documents:

- feature purpose;
- user-facing behavior;
- main flows;
- states;
- architecture;
- contracts;
- dependencies;
- important technical decisions;
- edge cases;
- limitations;
- future work.

`AGENTS.md` defines **how the agent must work**.

`FEATURE.md` defines **how a feature works**.

These documents serve different purposes.

Feature documents live at `features/<feature>/FEATURE.md` in the repository
root, not inside `lib/`. Feature documentation must stay out of the compiled
application bundle.

`FEATURES.md` in the repository root is the master feature specification. It
defines which features exist and how each one must be documented. Individual
`FEATURE.md` files must be derived from it.

The document hierarchy is:

```text
AGENTS.md          → how the agent must work
FEATURES.md        → which features exist and how they are documented
docs/ARCHITECTURE.md → how the application is technically structured
docs/PROTOCOL.md   → how devices communicate
docs/SECURITY.md   → what security model is approved
docs/decisions/    → why a significant decision was made
features/*/FEATURE.md → how an individual feature behaves
```

---

# 59. Architectural Decisions

When an architectural decision is important enough to affect future development, document it.

Examples:

- why raw WebSocket was chosen over Socket.IO;
- why the device token is never sent in discovery metadata;
- why streaming is required;
- why transfer history is not persisted;
- why BLoC is not used;
- why ChangeNotifier + immutable state is used;
- why sqflite was selected;
- why QR contains connection information.

Do not silently change documented decisions.

---

# 60. Testing Philosophy

Testing is required at the appropriate architectural level.

Prioritize deterministic tests.

Avoid tests that merely reproduce implementation details.

---

## 60.1 Unit Tests

Use unit tests for:

- domain logic;
- use cases;
- repositories where practical;
- services;
- controllers;
- mapping;
- validation;
- retry logic;
- filename conflict resolution;
- transfer state transitions.

---

## 60.2 Integration Tests

Use integration tests where infrastructure interaction matters, including:

- networking;
- SQLite;
- discovery;
- pairing;
- transfer flows.

Do not mock away the very behavior an integration test is supposed to validate.

---

## 60.3 UI Tests

Use UI/widget tests for meaningful UI behavior.

Examples:

- user interactions;
- state rendering;
- accessibility behavior;
- navigation behavior;
- important loading/error/success states.

Do not create hundreds of brittle snapshot-like tests for trivial visual details.

---

# 61. Tests Before Completion

A task is not complete merely because the application compiles.

The agent should verify, where applicable:

```text
Formatting
↓
Static analysis
↓
Unit tests
↓
Integration/UI tests
↓
Build
```

If a test cannot be executed, explain why.

Do not claim tests passed if they were not run.

---

# 62. Lint and Static Analysis

The project uses strict linting.

At minimum:

```text
flutter analyze
```

must pass without unresolved warnings/errors.

Project-specific lint rules must also be respected.

Do not suppress a lint simply to make CI pass.

If suppression is genuinely necessary:

1. explain why;
2. keep the scope minimal;
3. document the reason where appropriate.

---

# 63. Formatting

Use the Dart formatter.

Do not manually format code in ways that conflict with the formatter.

Before completion:

```bash
dart format .
flutter analyze
```

should be considered part of the normal verification process.

---

# 64. Build Verification

When the task affects platform-specific code or application initialization, verify the relevant build.

Do not assume:

```text
analyze passed
=
build works
```

For relevant changes, perform an appropriate build/test for the affected platform.

---

# 65. Git Workflow

Partilha uses simplified trunk-based development.

Primary branch:

```text
main
```

`main` is protected.

Use short-lived branches.

Branch naming:

```text
feat/...
fix/...
refactor/...
docs/...
test/...
chore/...
```

Avoid long-lived feature branches.

---

# 66. Commits

Use Conventional Commits.

Examples:

```text
feat: add nearby device discovery
fix: remove partial file after cancellation
refactor: isolate socket client
docs: document transfer protocol
test: cover retry policy
chore: update lint configuration
```

Commits should represent coherent changes.

Do not create meaningless commits such as:

```text
update
changes
stuff
final
final2
```

---

# 67. Commit Authority

The agent may prepare a commit.

However:

> The agent must not execute commits without explicit user approval.

The same applies to:

- tags;
- releases;
- publishing;
- pushing changes.

---

# 68. Pull Requests

The agent may prepare the content of a Pull Request.

The agent must wait for explicit approval before publishing/opening it.

A PR should include:

- what changed;
- why it changed;
- architectural impact;
- tests performed;
- known limitations;
- screenshots when relevant;
- migration notes when relevant.

---

# 69. Main Branch Protection

Merging into `main` should require:

- CI passing;
- required review/approval;
- branch being up to date according to repository rules.

Do not bypass branch protection.

Do not force-push protected branches.

---

# 70. Merge Strategy

Use **Squash Merge** for normal feature branches.

The resulting commit should represent the logical change clearly.

---

# 71. CI

CI should verify, as appropriate:

```text
Dependencies
↓
Formatting
↓
Static analysis
↓
Tests
↓
Build verification
```

CI should fail when required quality gates fail.

Do not weaken CI simply because a change makes the pipeline inconvenient.

---

# 72. Releases

Use Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Examples:

```text
1.0.0
1.1.0
1.1.1
```

Use Git tags for releases.

The agent must not create or push release tags without explicit approval.

---

# 73. CHANGELOG

Maintain:

```text
CHANGELOG.md
```

using Keep a Changelog-style categories where appropriate:

- Added;
- Changed;
- Deprecated;
- Removed;
- Fixed;
- Security.

Do not add speculative changes to the changelog.

---

# 74. Scope Control

Before modifying code, the agent should determine:

```text
What was requested?
What files are actually required?
What architecture is affected?
What tests are required?
What documentation must change?
```

Prefer the smallest coherent change that fully solves the task.

Avoid broad rewrites.

---

# 75. When the Existing Code Is Bad

Do not preserve clearly incorrect behavior merely because it already exists.

However, distinguish between:

```text
Bug
```

and:

```text
Architectural disagreement
```

For a bug:

- fix it within the current architecture.

For an architectural disagreement:

- document the issue;
- propose the alternative;
- request approval.

Do not use a feature task as an excuse to silently redesign the system.

---

# 76. When Requirements Conflict

If two sources conflict, use this order:

```text
Explicit user instruction
        ↓
Current approved architecture
        ↓
Relevant FEATURE.md
        ↓
Existing implementation
        ↓
General engineering convention
```

If the conflict cannot be resolved safely, stop and ask.

Do not guess when the decision has architectural consequences.

---

# 77. When Documentation and Code Conflict

Do not automatically assume the code is correct.

Determine whether the difference is:

- an implementation bug;
- outdated documentation;
- an intentional architectural change that was not documented.

If resolving the difference requires changing architecture, request approval.

Update documentation when an approved implementation changes documented behavior.

---

# 78. Performance Requirements

Performance must be considered before implementation, not after.

For every potentially expensive operation, consider:

- memory allocation;
- file size;
- number of rebuilds;
- synchronous work;
- stream backpressure;
- network latency;
- serialization cost;
- database operations;
- CPU usage;
- platform differences.

Avoid premature optimization, but do not ignore obvious performance risks.

---

# 79. Memory Safety

Partilha is a file-transfer application.

Memory behavior matters.

Never assume files are small.

Design APIs to work with streams where possible.

Avoid unnecessary:

```text
List<int>
Uint8List
String
JSON
```

copies for large payloads.

If a conversion is required, understand its memory implications.

---

# 80. Concurrency

Be careful with:

- simultaneous transfers;
- cancellation;
- retries;
- queue state;
- socket lifecycle;
- discovery events;
- controller disposal;
- file handles.

Do not introduce concurrency without defining ownership and lifecycle.

Ensure resources are properly closed/disposed.

---

# 81. Resource Lifecycle

Every long-lived resource must have a clear owner.

Examples:

- socket connection;
- stream subscription;
- file handle;
- database connection;
- controller;
- timer;
- discovery listener.

When a resource belongs to a lifecycle-aware component, dispose/cancel it appropriately.

Do not create unmanaged listeners or timers.

---

# 82. Error Recovery

Errors should be recoverable when appropriate.

Examples:

```text
temporary network failure
        ↓
retry
```

versus:

```text
insufficient storage
        ↓
do not retry automatically
```

The agent must distinguish retryable and non-retryable failures when implementing retry behavior.

Do not blindly retry every exception.

---

# 83. User Experience During Failure

Failure states must be explicit.

Avoid silent failures.

The UI should distinguish, where appropriate:

- loading;
- success;
- failure;
- cancelled;
- retrying;
- insufficient storage;
- permission denied;
- unavailable device.

Do not expose raw exception messages directly to users.

---

# 84. Accessibility and Error States

Error messages must be understandable and accessible.

Avoid relying only on:

- color;
- icons;
- animations.

Important state changes should remain understandable to users with accessibility settings enabled.

---

# 85. Open Source Standards

Partilha is an open-source project.

The repository should maintain:

```text
README.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
LICENSE
CHANGELOG.md
AGENTS.md
```

where applicable.

Also maintain appropriate:

```text
.github/
├── ISSUE_TEMPLATE/
└── PULL_REQUEST_TEMPLATE.md
```

Do not invent a license. The repository must use the license explicitly selected by the project maintainers.

---

# 86. Contribution Boundaries

External contributors should be able to understand:

- how to run the project;
- how to test it;
- how the architecture works;
- how to submit changes;
- what quality standards are expected.

Do not make contributors reverse-engineer architectural rules from implementation details when documentation can reasonably explain them.

---

# 87. Agent Communication

When reporting work, the agent should be concise but precise.

A useful completion report should include:

```text
Implemented
- ...

Changed
- ...

Tests
- ...

Analysis
- ...

Build
- ...

Notes
- ...
```

If something was not verified, explicitly state:

```text
Not verified because ...
```

Never imply successful verification that did not occur.

---

# 88. Agent Must Ask Before

The agent must stop and request approval before:

- changing architecture;
- changing security architecture;
- changing protocol contracts;
- changing persistence strategy;
- replacing dependencies with architectural impact;
- changing state management;
- introducing background execution;
- adding persistent device history;
- changing pairing behavior;
- changing transfer semantics;
- changing supported-platform strategy;
- deleting major existing functionality;
- performing a large refactor;
- publishing commits;
- pushing branches;
- opening/publishing PRs;
- creating release tags;
- publishing releases.

---

# 89. Agent May Decide Independently

The agent may make local engineering decisions when they remain within the documented architecture.

Examples:

- variable names;
- private helper methods;
- local widget decomposition;
- test organization;
- small implementation details;
- choosing between equivalent Flutter APIs;
- local error handling structure;
- internal method organization;
- minor performance improvements;
- implementation details of an already-approved contract.

The agent should still prefer the simplest maintainable solution.

---

# 90. Decision Heuristic

When multiple implementations satisfy the requirement, prefer the one that provides the best balance of:

```text
Correctness
    ↓
Maintainability
    ↓
Performance
    ↓
Testability
    ↓
Simplicity
```

Do not optimize for abstraction count.

Do not optimize for fewer lines of code.

Do not optimize for cleverness.

---

# 91. Definition of Done

A task is considered complete only when applicable requirements are satisfied.

### Functional

- Requested behavior is implemented.
- Edge cases are handled.
- Error states are defined.
- Existing behavior is not unintentionally broken.

### Architecture

- Dependency direction is respected.
- Feature boundaries are respected.
- Infrastructure dependencies remain isolated.
- No unauthorized architecture changes were introduced.

### Code Quality

- Code is formatted.
- Lints pass.
- No unnecessary warnings remain.
- Naming is clear.
- No unnecessary abstractions were introduced.

### Performance

- Large files are streamed.
- UI-thread blocking work is avoided.
- Unnecessary memory copies are avoided.
- Resource lifecycles are controlled.

### Testing

- Relevant unit tests exist.
- Relevant integration tests exist where required.
- Relevant UI tests exist where meaningful.
- Tests pass.

### Documentation

- Relevant `FEATURE.md` is updated.
- Architectural documentation is updated when necessary.
- Public/non-obvious APIs are documented where appropriate.
- `CHANGELOG.md` is updated when the change belongs in a release.

### Git

- Changes are scoped.
- Conventional Commit format is prepared when requested.
- No commit/tag/push/release is executed without explicit approval.

---

# 92. Final Agent Checklist

Before declaring a task complete, verify:

```text
[ ] Did I implement exactly what was requested?
[ ] Did I avoid inventing requirements?
[ ] Did I preserve the documented architecture?
[ ] Did I keep dependency direction correct?
[ ] Did I isolate infrastructure packages where required?
[ ] Did I avoid unrelated refactoring?
[ ] Did I use existing project abstractions?
[ ] Did I avoid unnecessary dependencies?
[ ] Did I consider memory usage?
[ ] Did I consider performance?
[ ] Did I handle resource lifecycles?
[ ] Did I handle failure states?
[ ] Did I write or update relevant tests?
[ ] Did I run formatting?
[ ] Did I run static analysis?
[ ] Did I run relevant tests?
[ ] Did I verify the relevant build where necessary?
[ ] Did I update relevant documentation?
[ ] Did I avoid changing security assumptions?
[ ] Did I avoid changing protocol contracts without approval?
[ ] Did I avoid commits/pushes/releases without approval?
```

If any answer is **No**, resolve it or explicitly report why it could not be completed.

---

# 93. Guiding Principle

Partilha should remain understandable to a developer who did not build it.

The architecture should make the correct path obvious.

The code should communicate intent.

Infrastructure should remain replaceable where it matters.

Performance should be considered part of correctness.

Security should be explicit rather than accidental.

Documentation should preserve decisions.

And AI agents should improve the project without silently redefining it.

> **Build deliberately. Change locally. Document decisions. Measure when it matters. Ask before changing architecture.**
