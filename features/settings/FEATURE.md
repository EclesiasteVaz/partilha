# Settings

> Derivado de [`FEATURES.md`](../../FEATURES.md) §32–§35 e §40.
> Não substitui o master. Onde houver conflito, `FEATURES.md` prevalece.

## 1. Purpose

Settings owns user-configurable application behavior.

The MVP does **not** have a large settings page. The Agent must not invent one.

At minimum, the user can define the device name.

## 2. Scope

In scope:

- user-defined device name;
- persistence of that name;
- making it available to Discovery and Pairing.

Explicitly not in scope: a settings screen with arbitrary preferences,
accounts, profiles, theming controls, or a general key/value preference store.

## 3. Current Status

**NOT IMPLEMENTED.**

No Dart code exists. `pubspec.yaml` contains only the default Flutter scaffold.
This document is a contract, not a description of shipped behavior.

## 4. User Problem

Without a device name, the sender sees an opaque identifier such as
`unknown-device` in the discovery list and cannot tell which of several nearby
devices it is sending to.

## 5. User Flow

```text
Open device name setting
   ↓
Read current persisted name
   ↓
User edits
   ↓
Validate
   ↓
Persist
   ↓
Name is reflected everywhere the device identity is shown
```

## 6. Functional Requirements

- The user can define the device name.
- The value is persisted.
- The value is available to Discovery.
- The value is available to Pairing.
- The value is reflected consistently wherever device identity is shown.
- The name is **not** duplicated across multiple storage mechanisms. There is
  exactly one source of truth.

## 7. Non-Functional Requirements

- Reads must not block the UI thread.
- The persisted name must survive application restart.
- Writing the name must not require the database to be fully migrated; see
  Open Questions.

## 8. States

```text
loading   → reading persisted value
ready     → value loaded
saving    → write in progress
error     → read or write failed
```

No additional states unless they carry real behavior.

## 9. State Transitions

```text
loading → ready
loading → error
ready   → saving
saving  → ready
saving  → error
```

## 10. Inputs

- user-entered device name.

No other input. Settings does not receive network input.

## 11. Outputs

- persisted device name, readable by Discovery and Pairing through the public
  Settings contract;
- state updates for the UI.

## 12. Validation

Device name validation is **not yet specified**. See Open Questions.

Minimum expectations once defined:

- must not be empty;
- must have a bounded length (mDNS TXT records and the UI both have limits);
- must not contain control characters;
- must be rendered escaped, since it is display-only text arriving from another
  device's perspective.

The Agent must not invent specific limits without approval.

## 13. Success Behavior

The name is persisted, the UI reflects the saved value, and Discovery
advertises the new name on its next announcement.

## 14. Failure Behavior

A read or write failure surfaces as a project-owned `StorageFailure` and an
explicit `error` state. Raw `DatabaseException` must not reach the UI.

## 15. Cancellation Behavior

Not applicable. Settings has no long-running operation to cancel.

## 16. Architecture

```text
SettingsController (presentation)
        ↓
GetDeviceNameUseCase (application)
        ↓
SettingsRepository (domain contract)
        ↓
SqliteSettingsRepository (data)
        ↓
LocalDataSource → sqflite
```

## 17. Domain Contracts

```text
SettingsRepository
    Future<Result<DeviceName, Failure>> readDeviceName()
    Future<Result<void, Failure>> saveDeviceName(DeviceName name)
```

Contract names are indicative. The final contract must be fixed when the
feature is implemented and recorded here.

## 18. Application Layer

Use cases only. No widget imports, no `BuildContext`, no sqflite.

## 19. Data Layer

Owns the sqflite access. Structure:

```text
LocalDataSource
      ↓
Repository
```

sqflite must not appear above the data layer.

## 20. Presentation Layer

- a `ChangeNotifier` controller with an immutable Freezed state;
- bound to the UI with `ListenableBuilder`;
- resolved through GetIt.

## 21. External Dependencies

```text
sqflite
freezed
json_serializable
getit
```

No network dependency. See `docs/decisions/0004-sem-dio-no-mvp.md`.

## 22. Package Isolation

```text
sqflite  → LocalDataSource
```

No UI or controller may import sqflite.

## 23. Persistence

SQLite is the persistence technology for the device name.

The feature must follow the persistence rules:

```text
LocalDataSource
      ↓
Repository
```

Migration policy is defined in `docs/ARCHITECTURE.md`. Schema changes require
explicit versioned migrations.

**No table exists for features explicitly marked non-persistent.** Settings is
not one of them; the device name genuinely needs to survive termination.

## 24. Platform Considerations

- Android and macOS are the priority targets.
- Do not scatter `Platform.isAndroid` / `Platform.isMacOS` through the feature.
- If a platform difference is genuinely required, it belongs in a project-owned
  platform service, not in the controller.

## 25. Performance Requirements

- Reads on startup must not delay first paint.
- The name is read by Discovery when building the advertisement. Do not re-read
  it from SQLite on every announcement tick.

## 26. Security Requirements

The device name is **display-only**. It is not a security boundary.

- The device name must not be used for filesystem paths.
- The device name must be escaped when rendered, because it originates on
  another device.
- The device name must not be used as an authentication input.
- The device **token** is never owned by Settings. It belongs to Pairing's
  identity concern and is written through `SecureCredentialStore`.

## 27. Accessibility Requirements

- The input needs a semantic label.
- Validation errors must be announced to assistive technology, not conveyed by
  color alone.
- Touch target must be adequate.
- Text must scale with the platform text-size setting.

## 28. Edge Cases

- name is empty → reject, see Open Questions;
- name exceeds maximum length → reject;
- name contains only whitespace → reject;
- database is not yet migrated → read must fail cleanly, not crash;
- name changes while a transfer is in progress → the current transfer is
  unaffected; new advertisements use the new name.

## 29. Testing Requirements

**Unit**

- repository read/write mapping;
- name validation, once defined;
- `Failure` conversion from sqflite exceptions.

**Integration**

- real sqflite round-trip, including a migration from a previous schema
  version.

**UI**

- renders loading, ready, saving, error;
- saving a valid name updates the displayed value;
- an invalid name surfaces an accessible error.

## 30. Known Limitations

- Nothing is implemented.
- Validation rules are undefined.
- There is no mechanism to detect a name collision with another device.

## 31. Out of Scope

- general preferences store;
- account or profile;
- theme selection;
- language selection;
- per-transfer settings;
- device deletion or reset (see Future Work).

## 32. Future Work

- device reset that regenerates identity;
- optional profile picture, if ever approved.

None of this is scheduled.

## 33. Architectural Decisions

| Decision | Where |
|---|---|
| SQLite via sqflite for persistent config | `docs/ARCHITECTURE.md` |
| No HTTP client in MVP | `docs/decisions/0004-sem-dio-no-mvp.md` |
| Token stored through `SecureCredentialStore`, not here | `docs/ARCHITECTURE.md` §70 |

## 34. Open Questions

**OPEN — APPROVAL REQUIRED**

- Maximum device-name length, and what happens on overflow.
- Whether an empty name is allowed, or a default name is auto-generated.
- The exact validation and rejection rules.
- Whether the schema ships with a migration from an earlier version, or only a
  fresh `onCreate`.
- Whether device reset belongs to Settings or to Pairing.

The Agent must not resolve any of these by guessing.