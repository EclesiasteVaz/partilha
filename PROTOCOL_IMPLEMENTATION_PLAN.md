# Protocol Implementation Plan (MVP)
Status: Approved by user (2025-10-09 context)
Base: commit 49e5587

Purpose: Concrete, minimal plan to unblock sender/receiver + pairing without guessing unresolved items. Follow AGENTS.md (ask before changing protocol contracts; keep domain free of infra/UI).

## Approved decisions
1. Messages (§41.1): use minimal set below. Envelope (type,id,payload) approved.
2. mDNS (§41.3): service type = `_partilha._tcp.local.`; TXT keys `name` and `id` required (reject if missing). No `capabilities` in TXT for MVP.
3. Capabilities (§41.4): none in TXT now (deferred). UI trusted-capabilities logic unchanged unless needed.
4. Error codes (§41.5): approved list; extend only with explicit permission.
5. Integrity (§41.6): Option A — no checksum/hash in MVP. Document as future work.
6. Unknown message (§41.7): Option A — ignore silently.
7. Reconnection (§41.8): a) use queue’s bounded retry (3 attempts, 1s→2s) on active transfer loss; b) reconnect automatically during pairing/idle where feasible.
8. Transfer ID (§35/§41.9): use separate wire transfer id (B). Generate wireTransferId (e.g. short UUID) and map local queue id ↔ wire id (since single active transfer per WS, mapping trivial).
9. Retry classification (§21): approved.
10. QR payload (§blocking): `{ "v": 1, "deviceId", "deviceName", "host", "port", "token" }` approved.
11. §33.3: control frame during active binary stream = protocol_violation; close connection; fail transfer.

## 1. Message set (approved)
| type | dir | payload | notes |
|---|---|---|---|
| pair_request | S→R | {deviceId, deviceName, token} | token only from QR |
| pair_response | R→S | {accepted: bool, reason?} | reject → not_paired/terminate as appropriate |
| transfer_offer | S→R | {wireTransferId, fileName, size, mimeType?} | wire id separate from local queue id |
| transfer_accept | R→S | {wireTransferId} | start binary frames after accept |
| transfer_reject | R→S | {wireTransferId, reason} | non-retryable |
| transfer_cancel | both | {wireTransferId} | explicit |
| transfer_complete | R→S | {wireTransferId} | receiver confirms end |
| transfer_error | both | {code, message?} | separate error message (§14.1) |
| transfer_progress | R→S (opt) | {wireTransferId, bytesReceived} | optional for MVP |

Envelope: {"type","id","payload"} — id correlates request/response (use per-message id; can mirror correlation).

## 2. Error codes (approved)
- not_paired (PairingFailure.rejected/unauthorized as appropriate)
- insufficient_space (StorageFailure.insufficientSpace)
- file_exists_conflict / conflict (TransferFailure.conflict)
- protocol_violation (TransferFailure.protocolViolation)
- unauthorized
- busy
- internal_error (UnknownFailure)
- cancelled (TransferFailure.cancelled)
Extend only with permission.

## 3. Wire/Domain mapping
- Keep TransferRequest.id as local queue id (existing). Add wireTransferId on wire DTOs; maintain Map<wireTransferId, localId> in sender session state and/or reverse in receiver session.
- Single active transfer per WS (§33.6) — mapping is trivial.
- Domain must not see wire IDs except via mapping at transport boundary.

## 4. File layout (suggested)
- core/protocol/ (or features/file_transfer/protocol/) — wire DTOs, envelope, codecs, message types. Must respect §34 (no UI/infra).
- features/file_transfer/data/ — WebSocketTransferRepository (sender), DartIoTransferServer (receiver control + disk), mappers.
- Keep contracts in domain.

## 5. Implementation steps (in order)
1. Create wire protocol types (envelope, message types, payloads) with json_serializable/freezed as appropriate; validation.
2. Sender: extend WebSocketTransferRepository to handshake pair_request→pair_response (if pairing context present), send transfer_offer, wait transfer_accept, then stream binary frames; map progress to domain; handle cancel/error/complete.
3. Receiver: add control parser in DartIoTransferServer; track active transfer state; enforce §33.3 (text during streaming → protocol_violation + close); call StorageValidationService before accepting; use resolveFilenameConflict on destination name; exclusive create + write stream + cleanup on error/cancel.
4. Wire controller→queue (TransferController uses QueueTransfersUseCase; render queue/speed/states).
5. QR payload parsing/validation already implied; ensure pairing context carries token/host/port/deviceId.
6. Tests (unit + minimal integration). Update PROTOCOL.md minimally if clarifications needed without reopening OPEN items.

## 6. Verification
- dart format . && flutter analyze
- flutter test
- flutter build macos --debug
