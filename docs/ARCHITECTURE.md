# Partilha — Architecture

This document defines the technical architecture of **Partilha**.

It describes how the application is structured, how components depend on each other, where responsibilities belong, how infrastructure is isolated, and how the main technical systems interact.

This document must be read together with:

- `AGENTS.md`
- `FEATURES.md`
- `README.md`
- `docs/PROTOCOL.md`
- `docs/SECURITY.md`
- the relevant feature `FEATURE.md`

These documents serve different purposes.

```text
AGENTS.md
    ↓
How the AI Agent must work

FEATURES.md
    ↓
What features exist and how they must be documented

ARCHITECTURE.md
    ↓
How the application is technically structured

PROTOCOL.md
    ↓
How devices communicate

SECURITY.md
    ↓
What security model is currently approved

FEATURE.md
    ↓
How an individual feature behaves
```

---

# 1. Architecture Goals

The architecture of Partilha is designed around the following goals:

- clear responsibility boundaries;
- feature ownership;
- explicit contracts;
- dependency inversion;
- infrastructure isolation;
- predictable state management;
- efficient file streaming;
- low memory usage;
- platform isolation;
- testability;
- maintainability;
- accessibility;
- responsive UI;
- controlled complexity.

The architecture must remain pragmatic.

The project does not pursue abstraction for abstraction's sake.

The project also does not permit shortcuts that bypass established architectural boundaries.

---

# 2. Architectural Style

Partilha uses:

```text
Feature-First
+
Clean Architecture principles
+
Dependency Inversion
+
Explicit Contracts
```

The project is organized primarily around **features**, not technical layers.

Correct:

```text
features/
├── discovery/
├── pairing/
├── file_transfer/
└── settings/
```

Not:

```text
controllers/
repositories/
services/
screens/
models/
```

as the primary application structure.

---

# 3. High-Level Architecture

The conceptual architecture is:

```text
┌──────────────────────────────────────────────┐
│                  Presentation                │
│                                              │
│ Screens / Widgets / Controllers / UI State   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                  Application                 │
│                                              │
│ Use Cases / Application Workflows            │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                    Domain                    │
│                                              │
│ Entities / Contracts / Failures / Results    │
└──────────────────────▲───────────────────────┘
                       │
                       │ implements contracts
                       │
┌──────────────────────┴───────────────────────┐
│                     Data                     │
│                                              │
│ Repositories / Data Sources / Infrastructure │
└──────────────────────────────────────────────┘
```

Dependency direction:

```text
presentation → application → domain
data         → domain
```

The domain does not depend on data.

The application does not depend directly on data implementations.

Presentation does not depend directly on infrastructure when an appropriate project-owned contract exists.

---

# 4. Dependency Rule

The most important architectural rule is:

> Dependencies must point toward stable contracts and application/domain concepts, not toward infrastructure implementations.

A feature should conceptually follow:

```text
UI
 ↓
Controller
 ↓
Use Case
 ↓
Repository / Service Contract
 ↓
Infrastructure Implementation
```

The infrastructure implementation satisfies the contract.

---

# 5. Feature Structure

Each feature follows:

```text
feature/
├── presentation/
├── application/
├── domain/
└── data/
```

Example:

```text
features/
└── file_transfer/
    ├── presentation/
    │   ├── controllers/
    │   ├── screens/
    │   ├── widgets/
    │   └── presentation.dart
    │
    ├── application/
    │   ├── use_cases/
    │   └── application.dart
    │
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   ├── services/
    │   ├── failures/
    │   └── domain.dart
    │
    └── data/
        ├── datasources/
        ├── dto/
        ├── mappers/
        ├── repositories/
        ├── services/
        └── data.dart
```

The exact subdirectories may change according to the feature.

Do not create empty architectural folders without a reason.

---

# 6. Presentation Layer

The presentation layer contains:

- screens;
- widgets;
- controllers;
- immutable UI state;
- presentation-specific formatting;
- user interaction handling.

Presentation is responsible for answering:

> What does the user see and what action did the user perform?

It is not responsible for:

- database access;
- HTTP implementation;
- `dart:io` socket implementation;
- mDNS implementation;
- QR package implementation;
- business persistence;
- raw file-transfer infrastructure.

---

# 7. Controllers

Partilha uses:

```text
ChangeNotifier
+
immutable Freezed state
+
State Pattern
```

It does not use:

- BLoC;
- Cubit;
- Provider as the controller exposure mechanism.

Controllers live in:

```text
presentation/
```

A controller coordinates presentation behavior.

Example:

```text
TransferController
        ↓
TransferState
        ↓
UI
```

Controllers may invoke Use Cases.

Controllers must not directly invoke repositories unless the architecture explicitly defines a case where this is necessary.

The preferred path is:

```text
Controller
    ↓
Use Case
    ↓
Repository / Service
```

---

# 8. Controller State

State models should be immutable.

Use Freezed where appropriate.

Example conceptual state:

```text
TransferState
├── initial
├── loading
├── ready
├── transferring
├── completed
├── failed
└── cancelled
```

The exact state machine belongs to the relevant feature.

Do not create states without meaningful behavioral differences.

State should contain only information needed by the presentation/application flow.

Do not turn state objects into arbitrary data containers.

---

# 9. UI Binding

UI listens to controllers through Flutter's native `Listenable` mechanisms.

Preferred mechanisms include:

```text
ListenableBuilder
AnimatedBuilder
```

The UI should not depend on Provider merely to obtain a controller.

Controllers are resolved through GetIt according to their intended lifecycle.

---

# 10. Application Layer

The application layer coordinates application actions.

It contains:

- Use Cases;
- application workflows;
- orchestration between contracts.

It answers:

> What operation is the application performing?

Examples:

```text
DiscoverNearbyDevicesUseCase
PairDeviceUseCase
SendFileUseCase
CancelTransferUseCase
UpdateDeviceNameUseCase
```

A Use Case should represent an application action.

---

# 11. Use Case Rules

Partilha uses explicit Use Cases for repository/service operations exposed to application logic.

The project intentionally favors explicit application boundaries.

A Use Case should:

- receive the required input;
- call the appropriate domain contract;
- coordinate required operations;
- return a project-owned result;
- remain independent of infrastructure implementations.

A Use Case must not:

- manipulate widgets;
- access BuildContext;
- import `dart:io` socket APIs;
- import sqflite;
- import mDNS packages;
- import QR packages;
- import platform-specific infrastructure.

---

# 12. Domain Layer

The domain layer defines stable concepts and contracts.

It may contain:

- entities;
- repository contracts;
- service contracts;
- failures;
- Result types;
- domain-relevant rules;
- serializable models where appropriate.

The domain should express:

> What the application means.

It should not express:

> Which package performs the operation.

---

# 13. Domain Package Policy

Domain is intentionally pragmatic.

The following may be used where appropriate:

```text
Freezed
json_serializable
custom Result<T, E>
barrel files
```

Do not interpret "Clean Architecture" as requiring absolute package-free domain code.

However, infrastructure packages must not leak into domain.

Forbidden examples:

```text
sqflite
dart:io socket mechanics
mDNS package
QR package
permission package
platform implementation packages
```

---

# 14. Entities

Entities represent application/domain concepts.

Examples may include:

```text
Device
Transfer
TransferItem
ConnectionInfo
DeviceIdentity
```

The exact entity list is defined by the relevant feature.

Entities should not contain:

- database-specific annotations unless explicitly justified;
- HTTP response semantics;
- package-specific types;
- UI state;
- infrastructure exceptions.

---

# 15. DTOs

DTOs represent external data contracts.

They may represent:

- network payloads;
- protocol messages;
- database records;
- external service structures.

DTOs belong in:

```text
data/
```

when they represent infrastructure/data concerns.

Use explicit mapping between DTOs and domain entities where both representations exist.

---

# 16. Entity ↔ DTO Mapping

Do not treat DTOs and entities as automatically interchangeable.

Preferred flow:

```text
External Data
     ↓
DTO
     ↓
Mapper
     ↓
Entity
```

And when sending:

```text
Entity
     ↓
Mapper
     ↓
DTO
     ↓
External Data
```

Mapping logic must remain explicit enough to understand.

Do not scatter mapping logic across widgets and controllers.

---

# 17. Data Layer

The data layer implements domain contracts.

It contains:

- repository implementations;
- local data sources;
- remote data sources;
- infrastructure services;
- DTOs;
- mappers;
- package-specific implementations.

Example:

```text
domain/
└── repositories/
    └── transfer_repository.dart

data/
└── repositories/
    └── transfer_repository.dart
```

The implementation name should clearly identify its technology/responsibility where useful.

Avoid meaningless:

```text
TransferRepositoryImpl
```

when a more descriptive name exists.

---

# 18. Repository Pattern

Repository contracts belong to domain.

Repository implementations belong to data.

Example:

```text
TransferRepository
        ↑
        │ implements
        │
TransferDataRepository
```

A repository should expose application/domain-relevant operations.

It should not expose package-specific infrastructure objects.

Avoid:

```text
Future<DioResponse> sendFile(...)
```

Prefer a project-owned result/domain contract.

---

# 19. Data Sources

Data Sources encapsulate actual data access.

Examples:

```text
TransferRemoteDataSource
SettingsLocalDataSource
```

A data source should know how to communicate with its infrastructure.

A repository should know how to combine/translate data source results into domain concepts.

---

# 20. Error Boundary

Infrastructure errors must be converted at the data/infrastructure boundary.

Example:

```text
SocketException
     ↓
WebSocketTransport
     ↓
NetworkFailure
     ↓
Result<T, Failure>
```

The domain/application must never need to understand a package exception.

---

# 21. Result Pattern

Partilha uses:

```text
Result<T, E>
```

as its application result mechanism.

Do not introduce:

- dartz;
- fpdart;
- another Either/Result abstraction.

unless architecture is explicitly changed.

Conceptually:

```text
Success<T>
Failure<E>
```

The exact implementation belongs to the project's shared/core Result abstraction.

---

# 22. Failure Model

Failures are project-owned.

Examples:

```text
NetworkFailure
DiscoveryFailure
PairingFailure
TransferFailure
StorageFailure
PermissionFailure
ValidationFailure
DatabaseFailure
UnknownFailure
```

Only create a specialized Failure when it carries meaningful semantic information.

Do not create dozens of Failure subclasses that provide no useful distinction.

---

# 23. Infrastructure Isolation

Infrastructure packages must be isolated when they are realistically replaceable or would otherwise leak implementation details.

Examples:

```text
HugeIcons
    ↓
AppIcons

mDNS package
    ↓
DiscoveryService

QR package
    ↓
QrCodeService

Permission package
    ↓
PermissionService

dart:io WebSocket
    ↓
WebSocketTransport
```

The goal is replaceability and boundary protection.

The goal is not to create an interface for every class.

---

# 24. Abstraction Rule

Create an abstraction when at least one of these is true:

- infrastructure can realistically be replaced;
- platform implementations differ;
- a feature requires dependency inversion;
- the abstraction defines a meaningful contract;
- testing requires isolation of external infrastructure;
- package leakage would damage architecture.

Do not create abstractions merely because:

> "Clean Architecture says everything needs an interface."

It does not.

---

# 25. Networking Architecture

Partilha uses the Dart SDK directly:

```text
dart:io WebSocket
dart:io HttpServer
```

No third-party networking package is used. See
`docs/decisions/0001-transporte-websocket-dart-io.md`.

The exact protocol responsibilities are defined by:

```text
docs/PROTOCOL.md
```

`dart:io` socket mechanics must remain isolated behind project-owned
abstractions.

No HTTP client is approved for the MVP. See
`docs/decisions/0004-sem-dio-no-mvp.md`.

---

# 26. HTTP

The MVP defines no HTTP client flow.

`dart:io`'s `HttpServer` is used to accept the connection; `WebSocketTransformer`
upgrades it. HTTP **client** usage is not approved and must not be introduced
without a separate approved decision.

---

# 27. Realtime Communication

A raw WebSocket over `dart:io` is used through a project-owned transport
abstraction.

Conceptually:

```text
Feature
   ↓
Application
   ↓
Repository / Service
   ↓
WebSocketTransport
   ↓
dart:io WebSocket
```

Do not expose raw `WebSocket` objects to presentation or domain.

---

# 28. File Transfer Architecture

File transfer is stream-based.

The architecture must avoid loading entire files into memory.

Conceptually:

```text
File
 ↓
Stream<List<int>>
 ↓
Transfer Transport
 ↓
Remote Device
 ↓
Stream / Progressive Write
 ↓
Destination File
```

The exact transport contract is defined in:

```text
docs/PROTOCOL.md
```

---

# 29. Streaming Rule

Do not use whole-file memory loading for normal transfer.

Avoid architectures based on:

```text
File
 ↓
readAsBytes()
 ↓
Huge in-memory buffer
 ↓
Network
```

Prefer:

```text
File.openRead()
 ↓
Stream<List<int>>
 ↓
Network
```

and progressive destination writing.

---

# 30. Transfer Progress

Transfer progress must be based on real bytes.

The system must track:

```text
bytesTransferred
totalBytes
```

and derive:

```text
progress
```

from those values.

Do not use arbitrary percentages.

---

# 31. Transfer Speed

Transfer speed must be calculated from actual transfer activity.

The implementation should avoid excessive UI updates.

Do not emit high-frequency UI state changes that cause unnecessary rebuilds.

Where appropriate, throttle presentation updates without compromising actual transfer accounting.

---

# 32. Transfer Queue

The queue belongs to the transfer application/domain behavior, not the UI.

The UI displays queue state.

Conceptually:

```text
Queue
 ↓
Transfer Item
 ↓
Execution
 ↓
Result
 ↓
Next Item
```

A failed item does not automatically terminate the queue.

---

# 33. Retry Architecture

Retry policy belongs to the transfer/application logic.

Maximum attempts:

```text
3
```

Retry delays use backoff.

The retry mechanism must distinguish:

```text
Retryable failure
Non-retryable failure
```

Do not retry indefinitely.

Do not hide retry attempts from the transfer state model when the UI needs to communicate them.

---

# 34. Cancellation Architecture

Cancellation must propagate through the transfer stack.

Conceptually:

```text
UI
 ↓
Controller
 ↓
CancelTransferUseCase
 ↓
Transfer Contract
 ↓
Transport / Stream
 ↓
File Write
```

Cancellation must terminate active resources.

Partial files must be deleted.

---

# 35. Device Discovery Architecture

Discovery uses mDNS.

The package implementation is isolated behind:

```text
DiscoveryService
```

Conceptually:

```text
DiscoveryController
        ↓
DiscoverDevicesUseCase
        ↓
DiscoveryService
        ↓
MdnsDiscoveryService
        ↓
mDNS package
```

The UI must not know that mDNS exists.

The receiving device must **announce** itself. The official `multicast_dns`
package is query-only and cannot answer incoming queries, so it cannot satisfy
this direction on its own. The candidate provider is `mdns_dart`, pending a
validation spike on real Android and macOS hardware. See
`docs/decisions/0002-mdns-provider.md`.

The provider choice must be recorded before Discovery implementation begins.

Discovered metadata is **untrusted, attacker-controllable public input**. It
must never carry the device token. See
`docs/decisions/0003-token-fora-do-mdns.md`.

---

# 36. Discovery Direction

The current architecture follows:

```text
Device capable of receiving:
announce

Device initiating connection:
search
```

This distinction must remain explicit.

Do not introduce a second discovery mechanism without approval.

---

# 37. Pairing Architecture

Pairing is responsible for turning connection information into a valid pairing context.

Conceptually:

```text
QR / Discovery
      ↓
ConnectionInfo
      ↓
Validation
      ↓
Pairing Use Case
      ↓
Connection
```

Pairing should not own file-transfer execution.

---

# 38. Device Identity

Device identity contains the information necessary to identify a Partilha device.

The current model includes a persistent token.

Do not confuse identity with known-device persistence.

```text
Device identity
    ≠
Known device database
```

---

# 39. QR Architecture

QR scanning/generation is infrastructure.

The feature owns the contract.

The package is an implementation detail.

Conceptually:

```text
Pairing
 ↓
QrCodeService
 ↓
QR package
```

The QR payload contract belongs to:

```text
docs/PROTOCOL.md
```

---

# 40. QR Payload

The current QR design carries complete connection information.

Conceptual information:

```text
Device ID
Device Name
Host / Address
Port
Token
Capabilities
Protocol-related information
```

Do not independently define a second payload format inside a feature.

---

# 41. Protocol Versioning

The MVP does not introduce protocol versioning.

Do not add:

```text
protocolVersion
version
v1
v2
```

without explicit approval.

Protocol evolution is a future architectural concern.

---

# 42. SQLite Architecture

Persistence uses:

```text
sqflite
```

SQLite is accessed only through data infrastructure.

Conceptually:

```text
Use Case
   ↓
Repository Contract
   ↓
Repository
   ↓
LocalDataSource
   ↓
sqflite
   ↓
SQLite
```

---

# 43. Database Migrations

Database schemas must use explicit versioned migrations.

Every schema change must answer:

```text
What changed?
From which version?
To which version?
What happens to existing data?
```

Do not silently delete or recreate user data.

---

# 44. Persistent Settings

Only data that needs to survive application termination should be persisted.

Examples:

```text
Device name → persistent
Temporary loading state → not persistent
Active transfer progress → not persistent
Transfer history → not persistent in MVP
Known devices → not persistent in MVP
```

---

# 45. Filesystem Architecture

Filesystem operations use:

```text
dart:io
```

directly in appropriate feature/data code.

The project intentionally does not require an artificial generic:

```text
FileStorage
```

abstraction.

Create one only if a real architectural requirement appears.

---

# 46. Destination Storage

Received files are stored in the system's appropriate:

```text
Downloads / Transfers
```

location.

Before writing:

```text
available storage
        ≥
required storage
```

must be validated.

---

# 47. Duplicate Filename Resolution

Filename conflict resolution belongs to transfer/storage logic.

Example:

```text
document.pdf
document (1).pdf
document (2).pdf
```

The logic must be deterministic and safe against concurrent filename conflicts where applicable.

---

# 48. Platform Architecture

Initial supported platforms:

```text
Android
macOS
```

Architecture should remain extensible to:

```text
iOS
Windows
Linux
```

However:

> Architectural readiness is not the same as platform support.

Do not claim a platform is supported until it is actually implemented and validated.

---

# 49. Platform Abstraction

Platform-specific behavior must be isolated.

Examples include:

- permissions;
- filesystem paths;
- system integrations;
- platform networking behavior;
- desktop/mobile differences.

Do not scatter platform conditionals throughout business logic.

Avoid:

```dart
if (Platform.isAndroid) ...
```

throughout the feature code.

Use project-owned platform services where platform abstraction is meaningful.

---

# 50. Dependency Injection

Partilha uses:

```text
GetIt
```

for dependency injection.

Dependency registration belongs to the application's composition/bootstrap layer.

Feature code should depend on abstractions where appropriate.

Do not call:

```text
GetIt.instance.register...
```

inside random feature classes.

Registration should have a predictable lifecycle.

---

# 51. Lifecycle Management

Every long-lived resource must have a clear owner.

Resources include:

- sockets;
- streams;
- timers;
- database resources;
- discovery subscriptions;
- controllers;
- file handles.

A resource must be:

```text
created
owned
used
disposed
```

by a clearly defined lifecycle.

---

# 52. Resource Disposal

The agent must explicitly consider disposal when implementing:

- `StreamSubscription`;
- timers;
- sockets;
- controllers;
- listeners;
- file handles;
- database resources.

No unmanaged long-lived subscription should be introduced.

---

# 53. Logging Architecture

The application uses a structured logger.

Levels include:

```text
debug
info
warning
error
```

Production code must not use:

```dart
print()
```

Logging belongs to infrastructure/core concerns.

Feature code may log through the project logger.

Do not expose sensitive information in logs.

---

# 54. Performance Architecture

Performance is part of correctness.

The architecture must avoid:

- unnecessary memory copies;
- whole-file memory loading;
- blocking UI operations;
- excessive rebuilds;
- uncontrolled streams;
- excessive serialization;
- unnecessary database queries;
- unnecessary network requests.

Use isolates or other appropriate mechanisms for CPU-heavy work.

Do not use isolates for trivial operations merely because they exist.

---

# 55. Memory Strategy

File size must not determine application memory usage linearly.

The system should operate using streams where possible.

Avoid:

```text
file size = memory requirement
```

Prefer bounded memory behavior.

Any operation that creates large buffers must have an explicit reason.

---

# 56. UI Architecture

The UI uses a project-owned design system.

Centralized concepts include:

```text
AppColors
AppTextStyles
AppIcons
ThemeExtensions
spacing tokens
radii
component styles
```

Exact names may evolve.

The principle is that design decisions should be centralized and reusable.

---

# 57. Icons

HugeIcons is the icon source.

UI code should use:

```text
AppIcons
```

rather than importing HugeIcons directly.

This protects the application from direct package coupling.

---

# 58. Typography

Typography belongs to the design system.

Use project-defined styles instead of repeatedly creating arbitrary text styles.

The UI should maintain visual consistency across:

- mobile;
- tablet;
- desktop.

---

# 59. Responsive Architecture

Responsive design is required from the beginning.

Layouts must consider:

```text
mobile
tablet
desktop
```

Desktop behavior must not simply be a stretched mobile layout.

Where appropriate, desktop may use:

- wider content areas;
- different navigation patterns;
- keyboard interaction;
- pointer interaction;
- multi-column layouts.

---

# 60. Accessibility Architecture

Accessibility is a first-class requirement.

Consider:

- semantics;
- labels;
- contrast;
- touch target sizes;
- text scaling;
- focus;
- keyboard navigation;
- meaningful status communication.

Accessibility requirements belong in feature `FEATURE.md` files as well.

---

# 61. Routing

Partilha uses:

```text
go_router
```

Routing configuration belongs to the application/core routing layer.

Feature screens may be exposed through explicit route configuration.

Do not place routing decisions randomly inside widgets.

Avoid navigation logic duplicated across multiple screens.

---

# 62. Testing Architecture

Testing should mirror architectural responsibility.

```text
Domain
    ↓
Unit tests

Application
    ↓
Use Case tests

Data
    ↓
Repository/DataSource tests

Infrastructure
    ↓
Integration tests

Presentation
    ↓
Widget/UI tests
```

Not every class requires a dedicated test.

Behavior and contracts determine testing priority.

---

# 63. Integration Boundaries

Integration tests are particularly important for:

- networking;
- discovery;
- pairing;
- SQLite;
- file transfer;
- platform integration.

Do not mock the boundary away when the purpose of the test is validating the actual integration.

---

# 64. Test Determinism

Tests must be deterministic.

Avoid tests that depend unnecessarily on:

- real network availability;
- timing;
- random ports;
- current date/time;
- uncontrolled filesystem state;
- external services.

When integration testing requires real infrastructure, isolate and control it appropriately.

---

# 65. Security Boundary

Security rules are defined separately in:

```text
docs/SECURITY.md
```

This architecture document must not invent additional security mechanisms.

The agent must follow the approved security model.

---

# 66. Protocol Boundary

Protocol rules are defined separately in:

```text
docs/PROTOCOL.md
```

This architecture document describes where protocol code belongs.

It does not redefine protocol payloads.

If the protocol changes:

```text
Update PROTOCOL.md
Update affected FEATURE.md
Update implementation
Update tests
```

and obtain architectural approval where required.

---

# 67. Cross-Cutting Core

The project may contain a `core/` area for genuinely cross-cutting concerns.

Examples:

```text
core/
├── errors/
├── result/
├── logging/
├── routing/
├── theme/
├── icons/
├── permissions/
└── ...
```

Do not put feature-specific logic into `core/`.

A class belongs in core only if multiple features genuinely depend on it and it has no single feature owner.

---

# 68. Core Must Not Become a Dumping Ground

Forbidden:

```text
core/utils/
core/helpers/
core/common/
core/misc/
```

containing unrelated application logic.

If a component belongs to a feature, keep it in the feature.

---

# 69. Package Isolation Matrix

The following matrix defines the intended boundaries:

| Technology / Package | Allowed Directly In UI | Allowed In Domain | Isolation Required |
|---|---:|---:|---:|
| Flutter | Yes | No | No |
| Freezed | Indirect / generated | Yes | No |
| json_serializable | Generated | Yes | No |
| GetIt | Bootstrap / controlled | No | Yes |
| dart:io WebSocket | No | No | Yes |
| dart:io HttpServer | No | No | Yes |
| sqflite | No | No | Yes |
| mDNS package | No | No | Yes |
| QR package | No | No | Yes |
| Permission package | No | No | Yes |
| HugeIcons | No | No | Yes |
| dart:io | Only where appropriate | No | Context-dependent |

"Isolation required" means application/domain code must not depend on the package directly.

---

# 70. Abstraction Matrix

The project intentionally uses these abstractions:

| Concern | Project Boundary |
|---|---|
| Realtime transport | WebSocketTransport |
| mDNS | DiscoveryService |
| QR | QrCodeService |
| Permissions | PermissionService |
| Icons | AppIcons |
| Persistence | LocalDataSource + Repository |
| Device credential | SecureCredentialStore |
| File transfer | Transfer contracts |
| Errors | Failure |
| Operation results | Result |

Do not add abstractions to this table automatically.

If a new cross-cutting abstraction is needed, document why.

---

# 71. Naming Architecture

Names should describe responsibility.

Preferred:

```text
WebSocketTransport
MdnsDiscoveryService
PermissionService
TransferRepository
TransferController
SendFileUseCase
```

Avoid:

```text
Manager
Helper
Utils
CommonService
Thing
Impl
```

unless genuinely justified.

---

# 72. Generated Code

Generated files are implementation artifacts.

Do not manually edit them.

After model changes:

```text
source changes
    ↓
code generation
    ↓
format
    ↓
analyze
    ↓
test
```

Generated code must remain synchronized with source annotations.

---

# 73. Architecture Change Protocol

If the agent determines that the current architecture cannot correctly implement a requirement:

It must not silently redesign it.

It must produce:

```text
Problem
Why current architecture is insufficient
Affected components
Proposed change
Advantages
Risks
Migration impact
Tests affected
Documentation affected
```

Then wait for approval.

---

# 74. What Counts as an Architectural Change?

Examples:

- changing state-management framework;
- replacing the transport implementation;
- replacing the mDNS provider;
- introducing an HTTP client;
- replacing sqflite;
- changing feature boundaries;
- changing dependency direction;
- introducing background execution;
- changing transfer protocol;
- introducing persistent known devices;
- changing pairing semantics;
- introducing a new cross-cutting abstraction;
- changing security architecture;
- changing storage architecture.

---

# 75. What Does Not Usually Require Architectural Approval?

Examples:

- renaming a private variable;
- extracting a small private helper;
- improving a widget structure;
- improving a test;
- fixing a local bug;
- optimizing a local loop;
- improving error handling inside an existing contract;
- adding a missing test;
- correcting documentation.

The change must still remain within the established architecture.

---

# 76. Implementation Order

When implementing a new vertical capability, prefer:

```text
1. Domain contract
2. Entity / model
3. Failure / Result behavior
4. Use Case
5. Data contract implementation
6. Infrastructure integration
7. Controller/state
8. UI
9. Tests
10. Documentation
```

This is a guideline, not a rigid requirement.

If infrastructure must be established before a domain operation can be meaningfully tested, adapt while preserving dependency direction.

---

# 77. Implementation Checklist

Before coding:

```text
[ ] Read AGENTS.md
[ ] Read FEATURES.md
[ ] Read relevant FEATURE.md
[ ] Read ARCHITECTURE.md
[ ] Read PROTOCOL.md if communication is affected
[ ] Read SECURITY.md if security is affected
[ ] Inspect existing implementation
[ ] Search for existing abstractions
[ ] Identify affected layers
[ ] Identify tests
[ ] Identify documentation changes
```

During coding:

```text
[ ] Preserve dependency direction
[ ] Keep package boundaries
[ ] Avoid unnecessary abstractions
[ ] Avoid unrelated refactoring
[ ] Keep state immutable
[ ] Handle lifecycle/disposal
[ ] Consider performance
[ ] Consider accessibility
[ ] Handle failures explicitly
```

After coding:

```text
[ ] Generate code
[ ] Format
[ ] Analyze
[ ] Run tests
[ ] Verify relevant build
[ ] Review diff
[ ] Update documentation
[ ] Confirm no architectural drift
```

---

# 78. Architecture Drift

Architecture drift occurs when implementation gradually stops following the documented design.

Examples:

```text
Controller → dart:io WebSocket

Widget → sqflite

Domain → package-specific exception

Feature A → Feature B controller

UI → mDNS package

Transfer → read entire file into memory
```

These should be treated as architectural violations.

The agent must correct them when encountered in the scope of its task or report them when outside scope.

---

# 79. Existing Code vs Target Architecture

The existing codebase may contain code that does not perfectly follow this architecture.

Do not automatically rewrite everything.

When touching an existing area:

1. understand the current implementation;
2. identify the requested change;
3. bring the affected code toward the target architecture where necessary;
4. avoid unrelated migration.

The project should converge gradually rather than through uncontrolled rewrites.

---

# 80. Definition of Architectural Completion

The architecture is considered correctly implemented when:

```text
[ ] Feature boundaries are clear
[ ] Dependency direction is respected
[ ] Domain contracts are infrastructure-independent
[ ] Data implements domain contracts
[ ] Controllers do not contain infrastructure logic
[ ] Infrastructure packages are isolated
[ ] State management follows the approved pattern
[ ] File transfer is stream-based
[ ] Persistent data uses the approved persistence layer
[ ] Platform-specific logic is controlled
[ ] Errors are translated at infrastructure boundaries
[ ] Tests exist at appropriate boundaries
[ ] Performance constraints are respected
[ ] Documentation reflects implementation
```

---

# 81. Final Architectural Principle

Partilha should be understandable as a system of explicit contracts.

A developer should be able to answer:

```text
Where does this behavior belong?
        ↓
Which feature owns it?
        ↓
Which layer owns it?
        ↓
Which contract connects it?
        ↓
Which infrastructure implements it?
        ↓
How is it tested?
```

If those answers are unclear, the implementation should not proceed blindly.

The architecture exists to make the correct implementation path obvious.

> **Features own behavior.**
>
> **Domain owns contracts.**
>
> **Application owns operations.**
>
> **Data owns infrastructure implementations.**
>
> **Presentation owns interaction and state rendering.**
>
> **Infrastructure details stay behind boundaries.**
>
> **Large files are streamed.**
>
> **Failures are explicit.**
>
> **Resources have owners and lifecycles.**
>
> **Architecture changes require approval.**
>
> **When context is missing, stop and recover context instead of guessing.**
