# Discovery

> Derivado de [`FEATURES.md`](../../FEATURES.md) §10 e §39–§41.
> Não substitui o master. Onde houver conflito, `FEATURES.md` prevalece.

## 1. Purpose

Discovery allows a device to identify other Partilha-capable devices available on
the local network.

The initial mechanism is mDNS.

## 2. Scope

In scope:

- announcing the local device;
- searching for nearby devices;
- detecting available devices;
- exposing discovered device information;
- reporting discovery failures;
- managing the lifecycle of discovery subscriptions.

## 3. Current Status

**PARTIALLY IMPLEMENTED — spike code only. No user-facing behaviour exists.**

What exists:

- `DiscoveryService` (domain contract) and `DiscoveredDevice`;
- `MdnsDiscoveryService` + `DiscoveredDeviceMapper` + `LocalAddressResolver`
  (data), isolating `mdns_dart` behind the contract with `mdns_dart` imported in
  no other file;
- `MulticastLock` in `core/platform`, with the Android implementation over a
  method channel and `CHANGE_WIFI_MULTICAST_STATE` declared in the manifest;
- unit tests for the record-validation trust boundary and for the lock
  lifecycle.

What does **not** exist: use cases, a `DiscoveryController`, a device list, or
anything wired into the app. `mdns_dart` is added to `pubspec.yaml` and compiled
but never invoked at runtime.

The feature is still **blocked** for real use: the provider is unvalidated on
hardware, and the checklist in `docs/decisions/0002-mdns-provider.md` is
unticked. Nothing here has been run against a real network.

## 4. User Problem

Two devices on the same Wi-Fi have no way to find each other without the user
typing an IP address and port by hand. Discovery removes that friction.

## 5. User Flow

```text
Receiver                        Sender
   │                              │
   ├── start advertising           │
   │                              ├── search
   │◄──── mDNS response ──────────┤
   │                              │
   │                       ◄──────┤ user selects the device
```

## 6. Functional Requirements

- Announce the local device while acting as a receiver.
- Search for nearby devices while acting as a sender.
- Detect devices as they appear and as they disappear.
- Expose discovered device information to the UI.
- Report discovery failures explicitly.
- Manage the lifecycle of discovery subscriptions.

Do not invent additional user-facing information about a discovered device.

## 7. Non-Functional Requirements

- discovery must not create uncontrolled subscriptions;
- discovery must not leak timers;
- discovery must not repeatedly recreate the underlying service;
- the UI must not fully rebuild on every irrelevant event.

## 8. States

```text
initial
discovering
devicesFound
empty
error
stopped
```

Do not add state values that carry no behavior.

## 9. State Transitions

```text
initial     → discovering
discovering → devicesFound
discovering → empty
discovering → error
discovering → stopped
devicesFound → discovering
empty        → discovering
error        → discovering
stopped      → discovering
```

## 10. Inputs

- local device identity (`deviceId`, `deviceName`, port, capabilities);
- network permission state.

**Discovery metadata is untrusted input** and is validated defensively. See
Security Requirements.

## 11. Outputs

A stream of discovered device entries containing only:

```text
deviceId
deviceName
host/address
port
capabilities
```

**The token is deliberately absent.** See
`docs/decisions/0003-token-fora-do-mdns.md`.

## 12. Validation

Because any host on the network can announce arbitrary records, every field is
attacker-controlled. Validation must:

- enforce field type and bounded length;
- reject entries whose service type does not match;
- treat `deviceName` as display-only and escape it at render time;
- never let metadata influence a filesystem path;
- never treat `deviceId` as proof of identity.

Specific numeric limits are **OPEN — APPROVAL REQUIRED**.

## 13. Success Behavior

The receiver's service is visible to Partilha senders on the same network, and
senders see the receiver listed with enough information to proceed to pairing.

## 14. Failure Behavior

Distinguish meaningful failures:

```text
discovery unavailable
permission / platform limitation
network failure
service initialization failure
discovery timeout, where applicable
```

All become project-owned `Failure` values. Raw package exceptions must never
reach presentation.

## 15. Cancellation Behavior

Stopping discovery must:

- cancel the search;
- stop advertising;
- release multicast resources;
- dispose every timer and subscription;
- move the state to `stopped`.

Leaving a phantom advertisement behind causes other devices to see a device
that cannot be connected to.

## 16. Architecture

```text
DiscoveryController (presentation)
        ↓
DiscoverDevicesUseCase / StartAdvertisingUseCase (application)
        ↓
DiscoveryService (domain contract)
        ↓
MdnsDiscoveryService (data)
        ↓
mdns_dart   ← provider pending spike
```

The UI must not know that mDNS exists.

## 17. Domain Contracts

```text
DiscoveryService
    Future<Result<List<DiscoveredDevice>, Failure>> discover()
    Future<Result<void, Failure>> startAdvertising({
        required String deviceId,
        required String deviceName,
        required int port,
        required Map<String, String> capabilities,
    })
    Future<Result<void, Failure>> stopAdvertising()
```

Two deliberate departures from the original sketch:

- **A bounded single-shot result, not a `Stream`.** The provider collects a
  fixed response window. Returning a stream would make "found nothing yet" and
  "discovery finished" indistinguishable, both presenting as a stream that never
  yields (`AGENTS.md` §83). A live stream that reports departure as well as
  arrival is an open question (§34).
- **`startAdvertising` takes no `token`.** The "token never in mDNS" rule is then
  structural instead of a convention someone can forget
  (`docs/decisions/0003-token-fora-do-mdns.md`).

Validation lives in `DiscoveredDeviceMapper`, not in the service, because
FEATURE.md §29 requires the mapping rules to be unit-testable and they are
untestable through a socket call.

## 18. Application Layer

Orchestrates start/stop and exposes results as `Result<T, Failure>`. No mDNS
package imports.

## 19. Data Layer

Owns `mdns_dart` entirely. Translates package exceptions into
`DiscoveryFailure`.

On Android this implementation is also responsible for the multicast lock, via
`core/platform/multicast_lock.dart`. The lock is acquired around each query and
held while an advertisement is live, then released in a `finally` so no exit path
can strand it. A lock left held keeps the Wi-Fi radio awake for the rest of the
process.

## 20. Presentation Layer

- `DiscoveryController` (ChangeNotifier) with immutable Freezed state;
- `ListenableBuilder` binding;
- a list view of discovered devices;
- explicit `empty`, `error` and `stopped` rendering.

## 21. External Dependencies

```text
mdns_dart            ← pending spike, see ADR 0002
getit
freezed
```

No HTTP client. No WebSocket in this feature.

## 22. Package Isolation

```text
mdns_dart → MdnsDiscoveryService → DiscoveryService
```

The package API must not leak into controllers, use cases, domain contracts, or
widgets.

## 23. Persistence

**None.**

Discovery state is ephemeral. Do not create a table for it.

Persisted devices are explicitly out of scope: there is no known-devices
registry in the MVP.

## 24. Platform Considerations

- Android and macOS are priority targets.
- Android requires a multicast lock; otherwise discovery silently fails on many
  devices. Implemented in `core/platform/multicast_lock.dart` and declared as
  `CHANGE_WIFI_MULTICAST_STATE` in the manifest. **Not yet run on a device.**
- Discovery needs no runtime permission, so it does not use `PermissionService`.
  The multicast permission is install-time and never prompts (§40).
- Interface selection matters when a machine has multiple interfaces (Wi-Fi and
  Ethernet). Which address is advertised is not yet defined — see Open
  Questions. The decision is isolated in `LocalAddressResolver` so it can be
  changed in one place.
- Do not scatter `Platform.is*` through the feature. `createMulticastLock()` is
  the single platform branch for multicast.

## 25. Performance Requirements

- Announcements must not be so frequent that they interfere with transfer
  throughput on a saturated network.
- Discovered-device updates must not cause a full list rebuild when only one
  entry changed.
- Discovery must not hold the UI thread during socket setup.

## 26. Security Requirements

**mDNS provides discovery, not authentication.**

The prohibited assumption:

```text
"Device discovered through mDNS = trusted device"
```

Required:

- the token must **never** appear in mDNS metadata; records are plaintext and
  readable by any host on the LAN;
- metadata is untrusted and attacker-controllable;
- `deviceId` is not proof of identity;
- discovered metadata must not be logged verbatim;
- pairing is what establishes trust.

Authority: `docs/SECURITY.md` §11.1 and
`docs/decisions/0003-token-fora-do-mdns.md`.

## 27. Accessibility Requirements

- each discovered device row needs a semantic label combining name and status;
- the list must announce when it transitions from empty to populated, and back;
- connection state must not be conveyed by color alone;
- rows must be keyboard-reachable on desktop and have adequate touch targets;
- the list must respect text scaling without truncating the device name into
  ambiguity.

## 28. Edge Cases

- multicast disabled or blocked → explicit failure, not an empty list with no
  explanation;
- airplane mode / no network;
- the local device discovers its own advertisement → must be filtered;
- duplicate responses for the same device → must not produce duplicate rows;
- a device disappears mid-transfer → the connection fails on its own terms;
- two devices advertising the same name → names are not unique identifiers;
- a hostile advertisement with a very long or malformed name → must be
  rejected or escaped, never crash the list;
- the app is backgrounded → advertising policy is **OPEN**.

## 29. Testing Requirements

**Unit**

- mapping from mDNS records to `DiscoveredDevice`;
- rejection of malformed and oversized records;
- duplicate suppression;
- `Failure` conversion.

**Integration**

- real announce and real discovery on a physical network, two devices;
- advertising stops cleanly and leaves no phantom record.

**UI**

- loading, populated, empty, error and stopped states;
- hostile record does not crash the list;
- name escaping is correct.

## 30. Known Limitations

- **No user-facing behaviour.** This is spike code; see §3.
- Provider unvalidated: the spike checklist in
  `docs/decisions/0002-mdns-provider.md` is entirely unticked.
- The official `multicast_dns` package cannot announce and is therefore
  insufficient.
- Known macOS camera/socket bugs in popular mDNS packages are unresolved.
- **`MulticastLock` is implemented but unverified on a device.** The APK builds
  and the permission reaches the manifest, but no physical Android device has
  run it. The failure this prevents is silent, so it must be confirmed on
  hardware before discovery is trusted (§19, §24).
- **Interface selection is still a policy decision** (§34). It is now a single
  injected collaborator, `LocalAddressResolver`, defaulting to
  `AllNonLoopbackAddresses`, and `startAdvertising` accepts an `interfaceName`.
  That makes the decision testable and swappable without touching the socket
  call, but it does not decide the policy. See §34.
- **Metadata length limits are provisional** (64 chars). §12 requires approval.
- `DiscoveredDevice` does not use Freezed. The spike does not justify a
  code-generation step for a five-field value object (`AGENTS.md` §55), but
  AGENTS.md §9 prefers Freezed for entities — **decide deliberately before this
  feature grows**, rather than letting the spike's choice stand by accident.
- A record with **no TXT payload is dropped**, because `ServiceEntry.isComplete`
  requires one. Partilha always advertises TXT, so this is treated as "not a
  Partilha receiver". Worth confirming against real peers.

## 31. Out of Scope

- known-devices registry;
- cross-subnet discovery;
- manual IP entry as a discovery substitute;
- Bonjour-only or Avahi-only optimization;
- discovery over Bluetooth, BLE, or Wi-Fi Direct;
- persistent advertisement across restarts.

## 32. Future Work

- manual address entry as a fallback when discovery is unavailable;
- richer device identity shown during discovery;
- subnet-aware discovery.

None is scheduled.

## 33. Architectural Decisions

| Decision | Where |
|---|---|
| Receiver announces, sender searches — do not reverse | `docs/ARCHITECTURE.md` §36 |
| mDNS isolated behind `DiscoveryService` | `AGENTS.md` §35 |
| Provider is `mdns_dart`, pending spike | `docs/decisions/0002-mdns-provider.md` |
| Discovery is a bounded result, not a live stream | §17 of this document |
| `startAdvertising` cannot carry a token | §17 of this document |
| `DiscoveredDevice` is a plain immutable class, not Freezed | §17 of this document |
| Token never in discovery metadata | `docs/decisions/0003-token-fora-do-mdns.md` |

## 34. Open Questions

**OPEN — APPROVAL REQUIRED**

- final mDNS provider, pending the spike in ADR 0002;
- exact mDNS service type and TXT-record keys (`docs/PROTOCOL.md` §7.2);
- maximum field lengths for every metadata field;
- whether the sender must try every advertised address in order until one
  connects, or whether it stops at the first. The chosen interface policy below
  is only robust on a multi-homed host if the sender does try them, so this is a
  dependency on the transport milestone rather than a free choice. See §34.1;
- announcement interval and whether it backs off;
- whether advertising continues while the app is backgrounded;
- whether discovery is cancelled automatically on app background.

No Discovery *feature* work — use cases, controllers, UI — may begin until the
provider spike is complete on real hardware. The spike's own isolation and
validation code is the only thing permitted before then, which is what this
document currently describes.

## 34.1 Interface selection: decided

Which local interface to advertise is **decided**, and it was not a choice
between candidate interfaces. The listener already owns the answer.

**Decision: the receiver advertises the addresses its listening socket is bound
to.** A socket bound to `0.0.0.0` is reachable on every interface, so
advertising every one of them is *correct* rather than an approximation. A
socket bound to a specific address advertises only that address. The transport
owns this fact, so discovery receives reachable addresses instead of guessing
them.

Consequences:

- Interface selection is a **transport** concern, not a discovery concern.
  `LocalAddressResolver` is the seam; its implementation becomes
  transport-owned once transport exists.
- Until then, `AllNonLoopbackAddresses` is the correct interim implementation,
  and only because the transport will bind to `0.0.0.0`. That assumption is
  stated rather than implied: if the transport ever binds to a single address,
  this default becomes wrong and must be replaced.

**Rejected: prefer the interface carrying the default route.** It answers "which
interface would reach the internet", not "which interface reaches peers on the
LAN". Under an active VPN or split-tunnel the default route points at the VPN,
which is the opposite of the right answer, and it fails silently. This option
should not be revived.

**Known limitation of the interim default**: it publishes every non-loopback
address, including a VPN or container interface if one is up. On the LAN this is
tolerable only because a peer picks the address that answers. That tolerance
depends on the open question in §34 about the sender trying every address, so
the interim default is not a final answer.

Rejected as premature: filtering interfaces by name (`utun`, `docker`, `br-`).
The names differ per platform, so the heuristic would be right on macOS and
wrong elsewhere while looking deliberate.