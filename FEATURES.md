# Partilha — Feature Specification and Feature Documentation Contract

This document is the **master feature specification** for Partilha.

It defines how AI agents must understand, decompose, document, implement, validate, and maintain the application's features.

This document exists because feature requirements must not live only in an AI agent's temporary context.

The agent must treat this file as a persistent source of product and technical context.

---

# 1. Purpose of This Document

This file has two purposes:

1. Define the feature landscape of Partilha.
2. Instruct the AI Agent to create and maintain the individual `FEATURE.md` files for each feature.

The individual feature documents are derived from this document.

They must not contradict:

- `AGENTS.md`;
- `README.md`;
- `docs/ARCHITECTURE.md`;
- `docs/PROTOCOL.md`;
- `docs/SECURITY.md`;
- approved architectural decisions;
- explicit user instructions.

When a conflict exists, the agent must not silently choose one interpretation.

It must stop and report the conflict.

---

# 2. Critical Agent Rule

## Do not lose context.

Partilha is an architecture-driven project.

A feature must never be implemented based only on the latest user message.

Before implementing or modifying a feature, the agent must reconstruct the relevant context from the repository.

At minimum, it must inspect:

```text
AGENTS.md
README.md
FEATURES.md
docs/ARCHITECTURE.md
docs/PROTOCOL.md
docs/SECURITY.md
relevant FEATURE.md
relevant source code
relevant tests
```

The agent must not assume that the current conversation contains the complete specification.

The repository is the persistent memory of the project.

---

# 3. Source of Truth

When determining how a feature should behave, use the following priority:

```text
1. Explicit current user instruction
2. Explicit approved architectural decision
3. AGENTS.md
4. FEATURES.md
5. Relevant feature FEATURE.md
6. Architecture documentation
7. Protocol/security documentation
8. Existing implementation
9. General engineering convention
```

However, if a lower-level document contains an apparently intentional decision that conflicts with a higher-level document, do not silently overwrite it.

Report the conflict.

---

# 4. Never Invent Missing Requirements

An AI agent must never turn an assumption into a requirement.

Examples of forbidden assumptions:

```text
"The user probably wants notifications."

"The app should probably remember devices."

"End-to-end encryption would probably be better."

"We should probably support folders."

"The protocol should probably have a version."

"Background transfer is probably useful."

"We should probably add authentication."

"The user probably expects transfer history."
```

None of these may become implementation requirements unless explicitly approved.

If a requirement is missing:

```text
UNKNOWN
```

is a valid state.

The agent should document:

```text
Decision required:
...
```

instead of inventing behavior.

---

# 5. Feature Documentation Strategy

The project must use individual feature documents.

The intended structure is:

```text
features/
├── discovery/
│   └── FEATURE.md
│
├── pairing/
│   └── FEATURE.md
│
├── file_transfer/
│   └── FEATURE.md
│
└── settings/
    └── FEATURE.md
```

The exact folder structure may evolve as the project evolves.

The important rule is:

> One meaningful product capability should have one authoritative feature document.

---

# 6. The Agent Must Generate Feature Documents

The agent must create the individual `FEATURE.md` files from this master document.

The agent must not simply copy this entire file into every feature.

Each feature document must contain only the information relevant to that feature.

For example:

```text
features/discovery/FEATURE.md
```

must not contain the entire transfer specification.

It may reference transfer behavior where discovery interacts with transfer, but transfer remains owned by:

```text
features/file_transfer/FEATURE.md
```

---

# 7. Required Structure of Every FEATURE.md

Every generated feature document must contain the following sections, unless a section is genuinely not applicable.

```text
# Feature Name

## 1. Purpose

## 2. Scope

## 3. Current Status

## 4. User Problem

## 5. User Flow

## 6. Functional Requirements

## 7. Non-Functional Requirements

## 8. States

## 9. State Transitions

## 10. Inputs

## 11. Outputs

## 12. Validation

## 13. Success Behavior

## 14. Failure Behavior

## 15. Cancellation Behavior

## 16. Architecture

## 17. Domain Contracts

## 18. Application Layer

## 19. Data Layer

## 20. Presentation Layer

## 21. External Dependencies

## 22. Package Isolation

## 23. Persistence

## 24. Platform Considerations

## 25. Performance Requirements

## 26. Security Requirements

## 27. Accessibility Requirements

## 28. Edge Cases

## 29. Testing Requirements

## 30. Known Limitations

## 31. Out of Scope

## 32. Future Work

## 33. Architectural Decisions

## 34. Open Questions
```

If a section does not apply, write:

```text
Not applicable.
```

Do not silently omit important sections.

---

# 8. Current Feature Set

The initial feature set is:

```text
1. Discovery
2. Pairing
3. File Transfer
4. Settings
```

These are the initial feature boundaries.

The agent may identify additional necessary technical components, but it must not automatically turn every technical component into a product feature.

For example:

```text
Network
Logger
Database
Dependency Injection
Theme
Result
Failure
```

are architectural/infrastructure concerns.

They are not automatically product features.

---

# 9. Feature Dependency Map

The initial conceptual dependency is:

```text
Settings
   │
   └──────────────┐
                  ↓
Discovery → Pairing → Transfer
```

More precisely:

```text
Discovery
    ↓
Identifies nearby devices
    ↓
Pairing
    ↓
Establishes connection context
    ↓
Transfer
    ↓
Transfers files
```

The exact implementation dependency must follow `docs/ARCHITECTURE.md`.

Do not introduce circular feature dependencies.

---

# 10. Discovery Feature

## Purpose

Discovery allows a device to identify other Partilha-capable devices available on the local network.

The initial discovery mechanism is mDNS.

---

## 10.1 Discovery Responsibilities

Discovery is responsible for:

- announcing the local device;
- searching for nearby devices;
- detecting available devices;
- exposing discovered device information;
- reporting discovery failures;
- managing the lifecycle of discovery subscriptions.

---

## 10.2 Discovery Model

The current model is:

```text
Receiving-capable device:
announces itself

Sending device:
searches for devices
```

The agent must preserve this behavior.

Do not reverse the model.

---

## 10.3 Discovery Infrastructure

mDNS package usage must be isolated.

The feature should depend on a project-owned contract such as:

```text
DiscoveryService
```

with an infrastructure implementation such as:

```text
MdnsDiscoveryService
```

The mDNS package must not leak into:

- controllers;
- application use cases;
- domain contracts;
- widgets.

---

## 10.4 Discovered Device Information

A discovered device may expose information required for the user to identify it and proceed to pairing.

At minimum, the architecture must be able to represent the device identity/name information required by the current protocol.

Do not invent additional user-facing information.

---

## 10.5 Discovery States

The feature should explicitly model states such as:

```text
initial
discovering
devicesFound
empty
error
stopped
```

The exact state model must remain coherent with the actual implementation.

Do not create state values that have no meaningful behavior.

---

## 10.6 Discovery Failure

Possible failure categories include:

- discovery unavailable;
- permission/platform limitation;
- network failure;
- service initialization failure;
- discovery timeout where applicable.

The agent must use project-owned failures.

Raw package exceptions must not reach presentation.

---

## 10.7 Discovery Performance

Discovery must not:

- create uncontrolled subscriptions;
- leak timers;
- repeatedly recreate discovery services unnecessarily;
- continuously rebuild the entire UI for every irrelevant event.

Discovery resources must have clear ownership and disposal.

---

# 11. Pairing Feature

## Purpose

Pairing establishes enough trust and connection information between devices to allow a transfer.

The MVP uses a persistent device token.

---

## 11.1 Pairing Responsibilities

Pairing is responsible for:

- generating/using device identity information;
- generating QR connection information;
- scanning QR information;
- validating received connection information;
- establishing the pairing context;
- exposing pairing success/failure.

---

## 11.2 Device Identity

Each device has:

```text
device ID
device name
persistent device token
```

where required by the pairing model.

The device name is user-defined.

The device token is persistent.

Do not create a persisted known-device registry.

These are separate concepts:

```text
Persistent device identity
≠
Persistent known-device history
```

---

# 12. QR Contract

QR pairing carries complete connection information.

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

The exact protocol representation must be defined in:

```text
docs/PROTOCOL.md
```

The feature document must not invent a second protocol.

---

# 13. QR Package Isolation

QR scanning and generation packages must be isolated behind project-owned interfaces/services.

For example:

```text
QrCodeService
```

or separate contracts where necessary.

UI must not depend directly on the QR implementation package.

---

# 14. Pairing Validation

Before accepting pairing information, validate:

- required fields;
- field types;
- host/address;
- port;
- token;
- capabilities where applicable;
- protocol compatibility according to the current protocol rules.

Do not invent protocol-version negotiation if protocol versioning is not part of the MVP.

---

# 15. Pairing Failure

Pairing must distinguish meaningful failures.

Examples:

```text
Invalid QR payload
Invalid device information
Connection unavailable
Authentication/token failure
Protocol rejection
Permission failure
Timeout
```

Only failures supported by the actual architecture should be implemented.

Do not create fake failure categories solely to populate an enum.

---

# 16. File Transfer Feature

## Purpose

File Transfer is the central data-transfer capability of Partilha.

The MVP supports transferring files between nearby paired devices.

---

# 17. Transfer Scope

MVP supports:

- individual files;
- multiple files;
- queued transfers;
- progress;
- dynamic transfer speed;
- automatic retry;
- cancellation;
- filename conflict resolution;
- destination storage validation.

MVP does not support:

- folder transfer;
- pause/resume;
- persistent transfer history;
- background transfer;
- persistent known-device history.

Do not implement these without explicit approval.

---

# 18. Transfer Lifecycle

A conceptual transfer lifecycle is:

```text
created
   ↓
validating
   ↓
queued
   ↓
starting
   ↓
transferring
   ↓
completed
```

Failure paths may include:

```text
validating → failed
queued → failed
starting → failed
transferring → retrying
retrying → transferring
retrying → failed
```

Cancellation:

```text
queued → cancelled
starting → cancelled
transferring → cancelled
```

The exact state machine must be documented in:

```text
features/file_transfer/FEATURE.md
```

before implementing complex transfer state behavior.

---

# 19. Storage Validation

Before a transfer begins, the receiving device must verify that sufficient storage is available.

If there is insufficient space:

```text
Transfer must not start.
```

Do not start writing and discover insufficient storage after partial transfer.

---

# 20. File Streaming

File transfer must use streaming.

Use:

```dart
Stream<List<int>>
```

where appropriate.

Do not load an entire file into memory.

The transfer implementation must support large files without requiring memory proportional to total file size.

---

# 21. Transfer Progress

Progress must represent actual bytes transferred.

Conceptually:

```text
bytesTransferred / totalBytes
```

Do not calculate progress using elapsed time or number of chunks.

---

# 22. Transfer Speed

Transfer speed must be derived from actual transfer activity.

The UI should expose dynamic speed where appropriate.

Do not fake or estimate transfer speed using arbitrary constants.

---

# 23. Queue Behavior

When multiple files are selected:

```text
File A
File B
File C
File D
```

they enter the transfer queue.

If:

```text
File B fails
```

the queue must continue:

```text
File C
File D
```

A single failed file must not automatically terminate the entire queue.

---

# 24. Retry Policy

Automatic retry is limited to:

```text
3 attempts
```

Use backoff.

Conceptually:

```text
Attempt 1
   ↓
delay
   ↓
Attempt 2
   ↓
delay
   ↓
Attempt 3
   ↓
final failure
```

The approved progression is:

```text
1s
2s
```

Three attempts admit exactly two delays. A three-delay progression would
imply a fourth attempt and contradict the bound above.

The implementation must remain bounded.

Do not retry indefinitely.

Do not blindly retry failures that are clearly non-retryable.

---

# 25. Cancellation

Cancellation must:

1. stop the active transfer;
2. stop streaming;
3. remove the partial destination file;
4. update state to cancelled.

The application must not leave incomplete files as if they were successfully received.

---

# 26. Duplicate Filenames

Do not overwrite existing files by default.

Generate a new filename.

Example:

```text
photo.jpg
photo (1).jpg
photo (2).jpg
```

Preserve the extension.

Conflict resolution must be deterministic.

---

# 27. Destination

Received files are saved directly to the system's appropriate:

```text
Downloads / Transfers
```

location.

Do not introduce a custom destination unless explicitly requested.

---

# 28. Received File Behavior

After successful receipt:

- save the file;
- do not automatically open it;
- do not introduce notifications unless explicitly specified;
- do not create transfer history unless explicitly specified.

---

# 29. Background Transfer

Background transfer is out of scope for the MVP.

If the application closes:

```text
active transfer → cancelled
```

Do not introduce background execution as an "improvement."

---

# 30. Folder Transfer

Folder transfer is future functionality.

Do not implement it as part of the initial file-transfer architecture unless the architecture explicitly requires preparation for it.

The current MVP only requires file selection.

---

# 31. Pause and Resume

Pause/resume is out of scope.

Do not create pause/resume states merely because transfer systems commonly support them.

---

# 32. Settings Feature

Settings owns user-configurable application behavior.

The exact settings must be explicitly defined.

The agent must not invent a large settings page.

At minimum, the device name is user-configurable.

---

# 33. Device Name Setting

The user can define the device name used by Partilha.

The value must be:

- persisted;
- available to discovery;
- available to pairing;
- reflected consistently wherever the device identity is shown.

Do not duplicate device-name storage across multiple unrelated mechanisms.

---

# 34. Persistence Rules

Partilha uses SQLite where persistent application data is required.

Use:

```text
LocalDataSource
    ↓
Repository
```

sqflite must remain inside data infrastructure.

Do not persist temporary feature state.

Do not create persistence tables for features explicitly marked as non-persistent.

---

# 35. Feature State vs Persistent Data

These must not be confused.

Example:

```text
TransferController state
```

is temporary application state.

It does not automatically belong in SQLite.

Likewise:

```text
Device name
```

is persistent configuration.

It belongs in persistence.

The agent must always ask:

> Does this information need to survive application termination?

If not, do not persist it.

---

# 36. Cross-Feature Contracts

Features must communicate through explicit contracts.

Do not directly access another feature's internal implementation.

For example:

```text
Discovery
    ↓
public discovery contract
    ↓
Pairing
```

rather than:

```text
Pairing
    ↓
imports DiscoveryController
```

Controllers are presentation concerns and must not become cross-feature APIs.

---

# 37. Cross-Feature Dependencies

Before adding a cross-feature dependency, the agent must identify:

```text
Which feature owns the concept?
Who consumes it?
What contract is required?
Can the dependency be inverted?
```

Do not solve cross-feature coupling by creating a global utility class.

---

# 38. Feature API Boundaries

Each feature should expose only what other parts of the application actually need.

Internal classes should remain internal where possible.

Barrel files should define the intended public surface.

Do not export every file indiscriminately.

---

# 39. Feature Performance

Every feature must document performance-sensitive operations.

Examples:

### Discovery

- subscription lifecycle;
- event frequency;
- UI rebuild frequency.

### Pairing

- QR processing;
- connection establishment;
- payload parsing.

### Transfer

- memory;
- streaming;
- file I/O;
- network throughput;
- retries;
- queue processing.

### Settings

- persistence latency;
- unnecessary reloads.

---

# 40. Feature Accessibility

Every feature document must explicitly consider accessibility.

Examples:

### Discovery

- device names must be readable;
- loading/empty/error states must be understandable.

### Pairing

- QR scanning must have an accessible alternative where applicable;
- errors must not rely solely on color.

### Transfer

- progress must communicate meaningful status;
- success/failure/cancellation must be distinguishable.

### Settings

- controls must have accessible labels;
- keyboard navigation must work where applicable.

---

# 41. Feature Testing

Every feature document must define its testing requirements.

At minimum, identify:

```text
Unit tests
Integration tests
UI tests
```

where applicable.

Do not create tests merely to satisfy a numerical target.

Test behavior and contracts.

---

# 42. Edge Cases

Every feature document must explicitly identify edge cases.

The agent must consider at least:

```text
Empty state
Loading state
Failure state
Cancellation
Disposal
Permission denial
Network failure
Unexpected input
Duplicate data
Resource exhaustion
Application termination
```

Only applicable cases should be implemented.

---

# 43. Feature Documentation Must Separate Current and Future

This distinction is mandatory.

Use:

```text
CURRENT
```

for behavior that exists or is approved for the current implementation.

Use:

```text
FUTURE
```

for planned behavior.

Never describe future behavior as if it already exists.

Example:

```text
Current:
Files are transferred without pause/resume.

Future:
Pause/resume may be considered later.
```

---

# 44. Out of Scope Is Important

Every feature document must explicitly state what it does not implement.

This prevents the Agent from "helpfully" expanding scope.

Example:

```text
## Out of Scope

- Folder transfer
- Background transfer
- Persistent transfer history
- Pause/resume
```

Out-of-scope requirements must be treated as constraints.

---

# 45. Open Questions

Every feature document must end with:

```text
## Open Questions
```

If there are no open questions:

```text
None.
```

The agent must not silently resolve an architectural open question.

---

# 46. Feature Implementation Protocol

When asked to implement a feature, the Agent must follow this process.

## Step 1 — Reconstruct Context

Read:

```text
AGENTS.md
README.md
FEATURES.md
docs/ARCHITECTURE.md
docs/PROTOCOL.md
docs/SECURITY.md
relevant FEATURE.md
```

Then inspect the existing implementation.

---

## Step 2 — Identify Scope

Write down internally:

```text
Feature:
Goal:
Affected layers:
Affected files:
Dependencies:
Tests required:
Documentation required:
```

Do not begin coding before understanding these.

---

## Step 3 — Check for Conflicts

Check:

- architecture;
- protocol;
- security;
- persistence;
- platform;
- existing behavior.

If conflicting requirements exist:

```text
STOP
REPORT
WAIT
```

Do not guess.

---

## Step 4 — Check Existing Code

Before creating a class, search for an existing equivalent.

Before creating a service, search for an existing service.

Before adding a package, verify whether the existing stack already solves the problem.

Before creating a model, search for existing models.

Before creating a state, inspect existing state patterns.

Do not duplicate functionality.

---

## Step 5 — Plan

Prepare a concise implementation plan.

Example:

```text
1. Add domain contract.
2. Add use case.
3. Add data implementation.
4. Add controller state.
5. Add UI.
6. Add tests.
7. Update feature documentation.
```

The exact plan depends on the feature.

---

## Step 6 — Implement in Dependency Order

Prefer:

```text
Domain
↓
Application
↓
Data
↓
Presentation
```

when implementing a new vertical capability.

Do not create UI that depends on undefined application contracts.

---

## Step 7 — Generate Code

Run required code generation.

Verify generated files.

Do not manually modify generated output.

---

## Step 8 — Test

Run relevant tests.

At minimum:

```text
Unit tests
Static analysis
Formatting
```

Run integration/UI tests when the feature requires them.

---

## Step 9 — Review

Review the diff for:

- architecture violations;
- accidental scope expansion;
- package leakage;
- memory problems;
- resource leaks;
- missing disposal;
- missing error handling;
- missing tests;
- incorrect documentation.

---

## Step 10 — Update Documentation

If behavior changed:

Update the relevant `FEATURE.md`.

If architecture changed with approval:

Update architecture documentation and/or ADRs.

If protocol changed with approval:

Update `docs/PROTOCOL.md`.

If security changed with approval:

Update `docs/SECURITY.md`.

---

# 47. Do Not Use Conversation Memory as Architecture

The Agent must not assume:

> "I remember we decided..."

Instead:

> "I found the decision documented in the repository."

If a decision exists only in conversation and materially affects architecture, it should be documented before implementation.

---

# 48. Context Recovery Procedure

If the Agent realizes that it has lost context:

It must not continue guessing.

It must:

1. stop implementation;
2. reread relevant documentation;
3. inspect the current code;
4. identify what is known;
5. identify what is unknown;
6. continue only when the requirements are clear.

Never compensate for missing context by inventing behavior.

---

# 49. Context Check Before Coding

Before implementing any non-trivial feature, the Agent should be able to answer:

```text
What problem am I solving?

What is explicitly in scope?

What is explicitly out of scope?

Which feature owns this behavior?

Which layer owns this logic?

What contract connects the layers?

What infrastructure package is involved?

Is that package isolated?

What state transitions exist?

What can fail?

What can be cancelled?

What must be persisted?

What must not be persisted?

What are the performance constraints?

What are the security constraints?

What platforms are affected?

What tests prove this works?
```

If the Agent cannot answer these questions, it should not start implementation.

---

# 50. Do Not Over-Engineer

Strictness does not mean unnecessary complexity.

The Agent must not create:

- interfaces for every class;
- factories for every object;
- repositories for purely local UI state;
- services with one meaningless method;
- abstractions with no replaceability value;
- speculative extension points;
- future architecture that has no current use.

The architecture is deliberate but pragmatic.

---

# 51. Do Not Under-Engineer

Likewise, the Agent must not bypass architecture because a shortcut appears faster.

Forbidden shortcuts include:

```text
UI → dart:io WebSocket
UI → sqflite
UI → mDNS package
UI → QR package
Controller → raw socket
Domain → infrastructure package
Feature → another feature's controller
```

unless an explicitly approved architectural decision allows it.

---

# 52. Feature Completion Criteria

A feature is complete only when:

```text
[ ] Requirements implemented
[ ] Scope respected
[ ] Architecture respected
[ ] State model complete
[ ] Error states handled
[ ] Cancellation handled where applicable
[ ] Persistence handled correctly
[ ] Performance requirements respected
[ ] Security requirements respected
[ ] Accessibility considered
[ ] Tests implemented
[ ] Static analysis passes
[ ] Formatting passes
[ ] Relevant build verified
[ ] FEATURE.md updated
[ ] No undocumented behavior introduced
```

---

# 53. Current MVP Boundary

The following are explicitly outside the current MVP unless later approved:

```text
Folder transfer
Pause/resume
Background transfer
Persistent transfer history
Persistent known-device registry
Invented protocol versioning
Invented authentication system
Invented encryption architecture
Push notifications
Cloud synchronization
User accounts
Remote file sharing over the internet
```

The agent must not implement these as "preparation" unless the architecture explicitly requires a small compatibility boundary.

---

# 54. Future Feature Documentation

When future functionality is discussed, document it under:

```text
Future Work
```

Do not implement it automatically.

Examples:

```text
Future:
Folder transfer

Future:
Pause/resume

Future:
Background transfer

Future:
Transfer history

Future:
Security hardening
```

A future feature becomes an implementation task only after explicit approval.

---

# 55. Feature Document Generation Rules

When creating an individual `FEATURE.md`, the Agent must:

1. Read this entire `FEATURES.md`.
2. Read `AGENTS.md`.
3. Read the architecture documentation.
4. Read protocol/security documentation where relevant.
5. Identify only the feature's actual responsibilities.
6. Separate current behavior from future behavior.
7. Explicitly list out-of-scope behavior.
8. Document states and transitions.
9. Document contracts.
10. Document dependencies.
11. Document error behavior.
12. Document testing requirements.
13. Document performance constraints.
14. Document security constraints.
15. Document accessibility requirements.
16. Document open questions.
17. Validate the generated document against the current implementation.
18. Never invent missing requirements.

---

# 56. Feature Document Maintenance

A `FEATURE.md` is not a one-time document.

When implementation changes behavior, the corresponding feature document must be reviewed.

The Agent must ask:

> Did this code change alter the documented feature behavior?

If yes, update the document.

If the change represents a new architectural decision, update the relevant architecture/ADR documentation as well.

---

# 57. Final Rule

The purpose of these documents is not bureaucracy.

The purpose is to prevent the project from becoming dependent on:

- one developer's memory;
- one AI session;
- one Agent's interpretation;
- undocumented assumptions;
- accidental architecture.

The repository must remain the source of truth.

A future developer or AI agent should be able to enter the repository and reconstruct:

```text
What Partilha is
        ↓
How it is architected
        ↓
What each feature does
        ↓
How features interact
        ↓
What is allowed
        ↓
What is forbidden
        ↓
What remains future work
        ↓
How to implement changes safely
```

If that information cannot be reconstructed from the repository, the documentation is incomplete.

> **Never guess when the repository can define the answer.**
>
> **Never silently change a decision.**
>
> **Never turn future work into current scope.**
>
> **Never trade architectural correctness for implementation speed.**
>
> **Preserve context before writing code.**
