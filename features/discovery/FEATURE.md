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

**NOT IMPLEMENTED.**

Additionally, this feature is **blocked**. The mDNS provider is not yet chosen.
See Open Questions and `docs/decisions/0002-mdns-provider.md`.

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
    Stream<DiscoveredDevice> discover()
    Future<void> startAdvertising(DiscoveredDevice self)
    Future<void> stopAdvertising()
```

Final contract is fixed at implementation time and recorded here.

## 18. Application Layer

Orchestrates start/stop and exposes results as `Result<T, Failure>`. No mDNS
package imports.

## 19. Data Layer

Owns `mdns_dart` entirely. Translates package exceptions into
`DiscoveryFailure`.

On Android this implementation is also responsible for the multicast lock.

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
  devices.
- Interface selection matters when a machine has multiple interfaces (Wi-Fi and
  Ethernet). Which address is advertised is not yet defined — see Open
  Questions.
- Do not scatter `Platform.is*` through the feature.

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

- Not implemented.
- Provider unchosen.
- The official `multicast_dns` package cannot announce and is therefore
  insufficient.
- Known macOS camera/socket bugs in popular mDNS packages are unresolved.

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
| Token never in discovery metadata | `docs/decisions/0003-token-fora-do-mdns.md` |

## 34. Open Questions

**OPEN — APPROVAL REQUIRED**

- final mDNS provider, pending the spike in ADR 0002;
- exact mDNS service type and TXT-record keys (`docs/PROTOCOL.md` §7.2);
- maximum field lengths for every metadata field;
- which local interface is advertised when several exist;
- announcement interval and whether it backs off;
- whether advertising continues while the app is backgrounded;
- whether discovery is cancelled automatically on app background.

No Discovery implementation may begin until the provider spike is complete.