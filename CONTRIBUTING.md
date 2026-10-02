# Contributing to Partilha

Thanks for your interest. Partilha is a local file-sharing app for nearby
devices, built with Flutter for **Android** and **macOS** first.

This document is aimed at external contributors. If you are an AI agent working
in this repository, `AGENTS.md` takes precedence over this file.

## Current state

**The project is pre-implementation.** There is no working feature yet. The
repository contains the complete architecture and feature specification, and the
default Flutter scaffold.

Before proposing code, please read:

```text
AGENTS.md          how AI agents must work, and the engineering rules
FEATURES.md        which features exist and how they are documented
docs/ARCHITECTURE.md   how the application is technically structured
docs/PROTOCOL.md       how devices communicate
docs/SECURITY.md       what security model is approved
docs/decisions/       why a decision was made
features/*/FEATURE.md  how an individual feature behaves
```

Understanding the architecture before writing code is not optional. Most
review comments will be about boundary violations, not logic.

## Requirements

- Flutter SDK with Dart 3
- Android SDK (for Android builds)
- Xcode with macOS support (for macOS builds)

## Running

```bash
flutter pub get
flutter run                 # attached device or emulator
flutter run -d macos        # macOS desktop
```

## Tests

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

`flutter analyze` must pass without warnings. Do not suppress a lint to make a
check pass; if a suppression is genuinely necessary, explain it in review.

Test levels and what belongs in each:

| Level | Use for |
|---|---|
| Unit | domain logic, use cases, mapping, validation, retry policy, filename conflicts, state transitions |
| Integration | networking, SQLite, discovery, pairing, transfer flows |
| Widget/UI | user interaction, state rendering, accessibility, navigation |

Do not mock away the very behaviour an integration test is supposed to verify.

## Architecture rules

These are not style preferences. Violating them blocks a pull request.

```text
presentation → application → domain
data         → domain
```

- Features own their behaviour. Do not add a global utility class to solve
  cross-feature coupling.
- `core/utils/`, `core/helpers/`, `core/common/` and `core/misc/` are forbidden.
- Infrastructure stays behind project-owned abstractions. `sqflite`, `dart:io`
  sockets, mDNS, QR and permission packages must not leak into domain,
  application, or presentation.
- State management is `ChangeNotifier` + immutable Freezed state. **Do not add
  BLoC/Cubit.**
- Dependency injection is GetIt. Do not add Provider.
- File transfer is stream-based. Never buffer a whole file in memory.
- Errors are typed `Failure` values returned in `Result<T, Failure>`. Do not use
  exceptions as normal control flow.
- Do not use `print()` in production code. Use the project logger.

## Adding a dependency

Every new dependency needs justification in the pull request:

1. Is it actually necessary?
2. Can the SDK or the existing stack solve it?
3. What is its maintenance status and license?
4. Does it support Android **and** macOS?
5. Does it require a project-owned abstraction?
6. What are its transitive dependencies?

Adding a package "because it exists" is a rejected reason. The MVP deliberately
uses no third-party networking package and no HTTP client.

## Decisions

Anything with lasting architectural impact — a new abstraction, a protocol
change, a dependency swap, a security change — requires approval **before** it
is written, not after.

Record it as a numbered document in `docs/decisions/`. Do not edit an existing
record to change a decision: mark it superseded and write a new one.

Several contracts are currently marked `OPEN — APPROVAL REQUIRED`. Please do not
guess them. Open an issue instead.

## Commits and pull requests

Commits follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat: add nearby device discovery
fix: remove partial file after cancellation
refactor: isolate websocket transport
docs: document transfer protocol
test: cover retry policy
chore: update lint configuration
```

Work on a short-lived branch from `main`:

```text
feat/...
fix/...
refactor/...
docs/...
test/...
chore/...
```

`main` is protected. Pull requests are squash-merged and require CI to pass and at
least one approving review.

A pull request should state:

- what changed;
- why it changed;
- architectural impact;
- tests performed;
- known limitations;
- screenshots, for UI changes;
- migration notes, if applicable.

## Reporting bugs

Open an issue with the template in `.github/ISSUE_TEMPLATE/`. Include your
platform, Flutter version, and the full stack trace if there is one. Please
remove the device token from any log output you paste.

## Security

Do not open a public issue for a security vulnerability. Contact the maintainers
privately first.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).