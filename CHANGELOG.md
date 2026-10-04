# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Settings: device name** (`features/settings`): the first implemented screen.
  A user-defined device name, validated as a `DeviceName` value object
  (non-empty, at most 64 characters, no control characters), persisted through
  `sqflite` behind a `SettingsLocalDataSource` / `SettingsRepository` boundary,
  and bound to the UI with a `ChangeNotifier` controller over immutable Freezed
  state. An unconfigured device uses the constant `Partilha` rather than a name
  inferred from the machine, which would broadcast it to the local network.
- **Routing** (`core/routing`): `MaterialApp.router` with a project-owned
  `AppRoute` enum, `RouteInformationParser` and `AppRouterDelegate`, using the
  SDK's own routing rather than a routing package. Settings is the first route;
  `AppRoute.send` is declared but has no page yet. Recorded in
  `docs/decisions/0006-routing-api-nativa-do-flutter.md`, which supersedes
  `go_router` as the documented choice.
- **`ValidationFailure`** for empty and overlong user input.

### Changed

- The app root no longer renders the "under construction" placeholder. It boots
  into Settings and resolves its dependencies from `InjectionContainer`.

- **Control message codec** (`core/protocol`): the trust boundary for the
  control channel, and the only place JSON is parsed. Frames are treated as
  untrusted input, so the decoder distinguishes three outcomes rather than
  throwing: understood, unknown `type`, and malformed. An unknown type is logged
  and ignored with the connection left open (§27.1), while a malformed frame is
  a contract violation that closes it (§28). Collapsing those two would mean a
  peer speaking a slightly different dialect could destroy a transfer in
  progress. The malformed reason never echoes the frame itself, because that
  frame is untrusted and may carry a token or file names, and logging it verbatim
  would write those to disk (§52). Carries the five approved error codes from
  §14.2, each traceable to a `Failure` constant that already existed, plus §14.1
  and §41.2: one envelope for every message, `id` required so a failure can be
  correlated with its request, and `payload` always present so decoding never has
  to tell "absent" from "empty". An unrecognised code from a future peer is kept
  verbatim and carries no local failure, which is what lets §27.1 apply to it.
  Error frames are built in exactly one place, so the enum name and the wire
  spelling cannot drift apart — a mistake the first test run actually caught,
  since `json_serializable` writes an enum by its Dart name by default. Adds
  `freezed`, `json_serializable` and `build_runner`, per §9.

- **Transport foundation** (`core/network`): `WebSocketTransport` as the
  project-owned contract, with `DartIoWebSocketTransport` as its only
  `dart:io` implementation. Pinned `wss://`, control in text frames and file
  bytes in binary frames on one connection, a 64 KiB frame ceiling, and one
  transfer at a time. Covered by integration tests against a real TLS WebSocket
  server, including the case that matters most: a certificate that does not
  match the pin is refused rather than connected to unverified, and is reported
  as a pairing failure so a retry cannot bury it. Registered in the DI container
  as a factory, because it owns a socket and must not be shared across sessions.
  Adds `crypto`, the Dart team's package, for SHA-256: `dart:io` exposes only
  SHA-1 for certificates and hand-rolling a hash is not acceptable.

- Architecture specification: feature-first Clean Architecture, dependency
  direction, package isolation matrix, and abstraction matrix.
- Core error model: sealed `Failure` hierarchy covering the categories named in
  `AGENTS.md` §14, each carrying the original exception for diagnostics and a
  separate user-safe message for display. `isRetryable` is resolved in one
  exhaustive switch so a new failure category cannot ship without a retry
  verdict.
- Core `Result<T, E extends Failure>` with `Success`/`Err`, `fold`, `map`,
  `mapError`, and `guard`/`guardAsync` for converting stray exceptions at the
  data boundary.
- Core structured logger with level filtering and secret redaction applied in
  one place, including nested maps and maps inside lists.
- Dependency injection container wrapping `get_it`, used only from the
  composition root.
- Continuous integration running formatting, static analysis with
  `--fatal-infos`, tests, and an Android build.
- Design system owning colour, typography, spacing, radii and iconography:
  `AppColors` and `AppTextStyles` are `ThemeExtension`s so widgets read them
  from the ambient theme, and `AppIcons` is the only file allowed to import the
  icon package.
- Dark-first neon direction: neon cyan and magenta on a near-black field, with a
  derived light palette of deeper, desaturated equivalents of the same hues,
  because neon cannot clear the contrast floor against white.
- `AppColors` owns the palette and overlays it onto the generated `ColorScheme`,
  so Material components cannot drift away from the design system's tokens.
  Every foreground/background pair is asserted against its WCAG target in both
  brightnesses, and semantic states must additionally differ by at least 1.35x
  in luminance, because a neon trio is otherwise indistinguishable in greyscale.
- Theme switching selects the nearer palette rather than blending: a
  per-channel blend was measured to render body text at 1.05:1 at the midpoint.
- Feature specification (`FEATURES.md`) and four derived feature documents under
  `features/`, each with an explicit current-status section.
- Protocol contract (`docs/PROTOCOL.md`) with unresolved decisions marked
  `OPEN — APPROVAL REQUIRED`.
- Security model (`docs/SECURITY.md`) covering the MVP token-based pairing model.
- Architectural Decision Records under `docs/decisions/`.
- Open-source governance files: `LICENSE` (MIT), `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `CHANGELOG.md`.

### Changed

- **Protocol**: the 64 KiB limit was specified as "reject before buffering".
  That is not possible with `dart:io`, which materialises a whole frame before
  application code can inspect it, so the specification was corrected to state
  what the limit actually guarantees: the frame is never processed, written or
  decoded, and the connection closes on the first violation. Recorded as a
  platform limitation rather than left as an unimplemented promise.

- **Protocol**: approved wire framing — control messages in WebSocket text
  frames, file bytes in binary frames, on one connection (`docs/PROTOCOL.md`
  §33.2). Chosen because the transport already distinguishes the two, so no
  custom envelope, channel id or opcode prefix is needed and file bytes stay raw.
  The accepted costs are recorded rather than left to be discovered: one
  connection cannot carry concurrent transfers, and a text frame arriving
  mid-file is defined as a protocol violation (§33.3) rather than tolerated,
  because accepting it would let a sender interleave control traffic into bytes
  already being written.

- **Security**: approved `wss://` with the certificate fingerprint pinned from
  the QR (`docs/SECURITY.md` §26.1). Plaintext was rejected because it does not
  weaken the token model, it removes it: the token would be readable by any host
  on the LAN. TLS alone was insufficient because a self-signed certificate is
  forgeable. Pinning from the QR has no trust-on-first-use window, which was the
  deciding factor against TOFU.

  This adds a required `certificateFingerprint` field to the QR payload, so the
  payload contract changes. Recorded as a consequence of the approved decision,
  and a later change contradicting it needs its own approval.

- **Discovery spike**: added `DiscoveryService` and `DiscoveredDevice` to
  `features/discovery/domain`, with `MdnsDiscoveryService` and
  `DiscoveredDeviceMapper` in `features/discovery/data`. `mdns_dart` is imported
  in no other file, so the provider stays replaceable.

  This is spike code with no user-facing behaviour: no use case, controller or
  screen exists, and nothing has been run against a real network. The provider
  remains unvalidated and `docs/decisions/0002-mdns-provider.md` is unticked.

- **Platform services**: added `core/platform/multicast_lock.dart`, the first
  project-owned platform service. Android silently drops multicast traffic
  without `WifiManager.MulticastLock`, and it does so silently enough that
  discovery looks like an empty network rather than a bug. The Android side is
  implemented in `MainActivity.kt` with reference counting, and
  `CHANGE_WIFI_MULTICAST_STATE` is declared in the manifest. The lock is
  released in a `finally` on every exit path, because a stranded lock keeps the
  Wi-Fi radio awake for the rest of the process.

  Discovery requests no runtime permission, so it does not use
  `PermissionService`: the multicast permission is install-time and never
  prompts. An empty `PermissionService` was deliberately not created.

  An APK was built to confirm the Kotlin side compiles and the permission
  reaches the package. **It has never run on a device**, so Android stays
  "primary target, not implemented" in both status locations (`AGENTS.md`
  §41.1).

- **Interface selection**: decided in `features/discovery/FEATURE.md` §34.1. The
  receiver advertises the addresses its listening socket is bound to, which makes
  this a transport concern rather than a discovery one;
  `LocalAddressResolver` is the seam, and the current
  `AllNonLoopbackAddresses` is correct only because the transport will bind to
  `0.0.0.0`.

  "Prefer the interface carrying the default route" was rejected: under an
  active VPN the default route points at the VPN, which is the opposite of the
  right answer for LAN peers, and it fails silently. Filtering interfaces by name
  (`utun`, `docker`, `br-`) was rejected as premature, since the names differ per
  platform and the heuristic would look deliberate while being wrong elsewhere.

  Two deliberate departures from the sketched contract, both recorded in
  `features/discovery/FEATURE.md` §17: discovery returns a bounded
  `Result<List<DiscoveredDevice>, Failure>` rather than a live `Stream`, because
  a stream would make "found nothing yet" and "finished" indistinguishable; and
  `startAdvertising` has no `token` parameter, which makes the "token never in
  mDNS" rule structural rather than conventional.

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
- **Platform support status**: replaced the generic "initial/future targets"
  wording with an explicit per-platform status table in `README.md` and
  `docs/ARCHITECTURE.md` §48.1. `ios/`, `linux/`, `windows/` and `web/` are
  recorded as scaffold-only: untouched `flutter create` output, not built and
  not tested. Platform folders are retained deliberately so platform
  contributions can start without regenerating the project. See
  `docs/decisions/0005-estado-das-plataformas.md`.
- **Analysis options**: replaced the generated `analysis_options.yaml`, which
  enabled `flutter_lints` with every additional rule commented out, with strict
  language modes and 79 verified lint rules.

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

- **Nothing is implemented.** The repository contains the generated Flutter
  scaffold, the complete architecture and feature specification, and the core
  error, result and logging primitives. No feature screen or flow exists.
- **No platform is supported.** Android and macOS are the approved targets but
  have no implementation yet. `ios/`, `linux/`, `windows/` and `web/` contain
  unmodified scaffold only; they are neither built nor tested. See
  `docs/decisions/0005-estado-das-plataformas.md`.
- Discovery is blocked pending an mDNS provider validation spike.
- File transfer is blocked pending the wire-framing and transport-encryption
  decisions.

[Unreleased]: https://github.com/partilha/partilha/compare/v0.0.0...HEAD