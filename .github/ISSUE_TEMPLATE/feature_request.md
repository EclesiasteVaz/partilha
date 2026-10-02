---
name: Feature request
about: Suggest a capability or change to the documented architecture
title: ''
labels: enhancement
assignees: ''
---

## Problem

<!-- What is the user-facing problem? Not the solution. -->

## Proposed change

<!-- What should change? -->

## Scope

- [ ] Adds new user-facing behavior
- [ ] Changes an existing documented behavior
- [ ] Internal refactor, no user-visible change

## Architectural impact

<!-- If any box is ticked, this requires approval BEFORE implementation.
     See AGENTS.md §88. -->

- [ ] Changes the dependency direction
- [ ] Changes state management
- [ ] Adds or removes a cross-cutting abstraction
- [ ] Changes the transfer protocol
- [ ] Changes the pairing model
- [ ] Changes the security model
- [ ] Changes the persistence strategy
- [ ] Adds, removes, or swaps a dependency
- [ ] Changes supported-platform strategy
- [ ] None of the above

If any are ticked, please describe the problem, the evidence, the impact, and
the proposed alternative.

## Currently open decisions

Does this depend on something marked `OPEN — APPROVAL REQUIRED`?

<!-- e.g. docs/PROTOCOL.md §33.1 wire framing -->

## Alternatives considered

<!-- Including "do nothing" and why it is worse. -->

## Which feature owns this

- [ ] Settings
- [ ] Discovery
- [ ] Pairing
- [ ] File Transfer
- [ ] Cross-feature — explain
- [ ] Not yet clear

## Out of scope check

`FEATURES.md` marks several things as explicitly **out of scope** for the MVP:
folder transfer, pause/resume, transfer history, background transfer, and
known-device management.

- [ ] I have read `FEATURES.md` and this is not already listed as out of scope.
- [ ] I understand that implementing it requires approval.
- [ ] I understand this changes the MVP scope and is not a bug or polish item.

## Alternatives / additional context