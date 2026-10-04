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

**IMPLEMENTED.** Device name only.

```text
lib/features/settings/
├── domain/        DeviceName, SettingsRepository
├── application/   GetDeviceNameUseCase, SaveDeviceNameUseCase
├── data/          SettingsLocalDataSource, SqliteSettings*
└── presentation/  SettingsController, SettingsScreen
```

This is the first implemented screen in the application. It replaced the
`flutter create` placeholder, so the app now renders real UI rather than an
"under construction" notice.

Not implemented, and deliberately so: everything in §31. There is no
preferences store beyond the single device-name row.

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

Implemented in `DeviceName.create`, which returns a `Result` rather than
throwing: an empty or overlong name is an ordinary thing a user does, not a
programming error (§83).

| Rule | Behavior | Failure |
|---|---|---|
| Surrounding whitespace | trimmed before judging and before storing | — |
| Empty / whitespace only | rejected | `ValidationFailure.empty` |
| Longer than 64 characters | rejected | `ValidationFailure.tooLong` |
| C0 control chars or DEL | rejected | `ValidationFailure.malformed` |

Control characters are rejected rather than stripped, so the stored name and the
advertised name cannot disagree.

`DeviceName.maxLength = 64` is bounded by the mDNS TXT budget (§7.2) and by the
peer list row. Approved by the maintainer on 2026-10-04; see §34.

Unchanged from the contract: the name is rendered escaped, because it is
display-only text arriving from another device's perspective.

The value object, not the raw string, is what reaches Discovery, Pairing and
persistence, so the rules cannot be re-decided per consumer.

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

- name is empty → rejected with `ValidationFailure.empty`;
- name exceeds 64 characters → rejected with `ValidationFailure.tooLong`;
- name contains only whitespace → rejected after trimming;
- name contains a control character, notably a newline → rejected, since an
  unescaped newline could terminate a TXT record early;
- nothing stored yet → the fallback `Partilha` is returned as a **success**, not
  a failure, so a first run is not reported as an error;
- a stored row that no longer validates, e.g. written before the limit changed
  → the fallback is returned rather than an unusable name being advertised;
- storage unavailable → `StorageFailure`, and the screen stays editable so the
  one action that might recover is still available;
- name changes while a transfer is in progress → the current transfer is
  unaffected; new advertisements use the new name.

## 28.1 Behavior Detail Worth Knowing

**The saved value is re-read after a write.** `SaveDeviceNameUseCase` trims, so
the stored name may differ from what was typed; the controller reads it back so
the field shows what was actually persisted. That read publishes
`SettingsStatus.saved` rather than going through `load()`, because routing
through `load()` would end in `ready` and the user would never see confirmation
that the save worked.

**A confirmation read that fails does not report the save as failed.** The write
succeeded; claiming otherwise would tell the user their name was not saved when
it was.

## 29. Testing Requirements

Implemented in `test/features/settings/`. Total suite: 277 tests.

**Unit** — `domain/device_name_test.dart`

- accepted input: plain, accented, non-Latin, emoji, exactly at the limit;
- rejected input: empty, whitespace only, over the limit, control characters;
- trimming happens before judging;
- value equality;
- the fallback is not the machine hostname, which is the §34 leak this guards.

Implemented in `application/settings_use_cases_test.dart`: reading, saving, and
that an invalid name never reaches storage.

Implemented in `data/sqlite_settings_repository_test.dart`: round trip, first-run
fallback, a stored value that no longer validates, `StorageFailure` conversion,
that a write failure is not retryable, and that the exception never reaches the
caller.

**Integration** — `data/sqlite_settings_local_data_source_test.dart`

Real SQLite through `sqflite_common_ffi` as a dev dependency, because mocking
sqflite away would hide the schema and the upsert:

- write then read; replace rather than duplicate; independent keys;
- a value containing `'); DROP TABLE` is stored literally;
- survives close and reopen, and two handles on one file;
- the repository and the data source agree on the device-name round trip, which
  would catch a key mismatch invisible to every unit test.

**UI** — `presentation/settings_screen_test.dart`, `presentation/settings_controller_test.dart`

- stored name in the field, fallback prefilled;
- typing reaches the controller;
- saving confirms in text;
- storage failure and invalid name are readable text, not color;
- the status is a `liveRegion`;
- the save control meets the touch-target token;
- width is capped on a wide window;
- the controller publishes `saved`, does not write on invalid input, locks while
  saving, and clears a stale failure when the user types.

`test/widget_test.dart` covers the shell: the composition root registers the
whole graph and resolves to the SQLite implementations, the router lands on
`SettingsScreen`, and the app is not a debug build.

Not covered: a migration from a previous schema version. There is no previous
version, so there is nothing to migrate from (§34).

## 30. Known Limitations

- The validation limits in §12 were chosen while implementing and approved
  afterwards on 2026-10-04 (§34).
- There is no mechanism to detect a name collision with another device.
- `SettingsScreen` is the only screen; it is not yet reachable from anywhere
  except the router's default route, so there is no navigation to it.
- There is no way to reset or clear the name once set (see Future Work).
- The `settings` table has no migration path exercised by a test, because only
  version 1 exists.

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

### 34.1 Validation limits — APPROVED

The rules in §12 are implemented because a screen cannot exist without them.
They were chosen during implementation and approved by the maintainer on
2026-10-04, rather than being guessed silently:

| Decision | Implemented value |
|---|---|
| Maximum length | 64 characters, rejected on overflow |
| Empty name | rejected, `ValidationFailure.empty` |
| Default name | constant `Partilha`, never derived from the machine |
| Control characters | rejected, not stripped |
| Trimming | surrounding whitespace removed |

The change is local to `DeviceName`. If the limit ever moves, `maxLength` must
stay equal to the limit Discovery enforces on an untrusted announcement, or a
name accepted here could be refused by a peer.

### 34.2 Still open

- Whether the schema ships with a migration from an earlier version, or only a
  fresh `onCreate`. Only version 1 exists, so `onCreate` alone is correct today.
- Whether device reset belongs to Settings or to Pairing.

Neither blocks the current screen. The Agent must not resolve them by
guessing.