# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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