## Description

<!-- What does this change do, and why? -->

## Type

<!-- Delete the ones that do not apply. -->

- [ ] Bug fix
- [ ] New feature
- [ ] Performance
- [ ] Refactor
- [ ] Documentation
- [ ] Test
- [ ] Build/CI

## Architectural impact

<!-- Required. If any box is ticked, the PR will not be reviewed without a
     prior approval on the decision. -->

- [ ] Changes the dependency direction
- [ ] Changes state management (ChangeNotifier + Freezed)
- [ ] Adds or removes a cross-cutting abstraction
- [ ] Changes the transfer protocol
- [ ] Changes the security model
- [ ] Changes the persistence strategy
- [ ] Adds, removes, or swaps a dependency
- [ ] Touches infrastructure packages directly (sqflite, dart:io, mDNS, QR, permissions)

If any are ticked, link the approved decision:

<!-- ADR: docs/decisions/0000-....md -->

## Contract changes

- [ ] This PR resolves an `OPEN — APPROVAL REQUIRED` item. Which one?

<!-- docs/PROTOCOL.md §x / docs/SECURITY.md §x -->

- [ ] This PR introduces a new `OPEN — APPROVAL REQUIRED` item.

- [ ] No contract changed.

## Memory and performance

<!-- Partilha is a file-transfer app. Memory safety is part of correctness. -->

- [ ] Large files are streamed; nothing is fully buffered in memory.
- [ ] No unbounded `List<int>` / `Uint8List` / `String` / JSON copies were added.
- [ ] No blocking work was added to the UI thread.
- [ ] Resource lifecycle is explicit: subscriptions, timers, sockets and file
      handles have owners and are disposed on every path including cancellation.
- [ ] Not applicable.

## Verification

<!-- Paste the actual commands and their results. Do not claim a check you
     did not run. -->

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

- [ ] Formatting clean
- [ ] `flutter analyze` passes with no new warnings
- [ ] Tests added or updated
- [ ] Relevant build verified (Android / macOS) — or stated as not verified

## Documentation

- [ ] `features/<feature>/FEATURE.md` updated if behaviour changed
- [ ] `docs/ARCHITECTURE.md`, `docs/PROTOCOL.md` or `docs/SECURITY.md` updated
      if a contract changed
- [ ] New decision recorded in `docs/decisions/` if it has lasting impact
- [ ] `CHANGELOG.md` updated if this belongs in a release
- [ ] No documentation change needed

## Known limitations

<!-- What does this PR NOT do? Be explicit. -->

## Screenshots

<!-- Required for UI changes. Desktop width as well as mobile. -->

## Checklist

- [ ] I read `AGENTS.md` and `CONTRIBUTING.md` before writing code.
- [ ] I implemented only what was requested, with no unrelated refactoring.
- [ ] No infrastructure package leaks into domain, application, or presentation.
- [ ] No `print()` in production code.
- [ ] Errors are typed `Failure` values, not raw exceptions across layers.
- [ ] I did not guess any `OPEN — APPROVAL REQUIRED` contract.
- [ ] I have not committed, pushed, tagged, or published anything without
      explicit approval.