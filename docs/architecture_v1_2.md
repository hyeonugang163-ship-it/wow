# Voyage PTT Blueprint v1.2 (2025‑12)

This document upgrades the original v1.1 blueprint into a more enterprise‑grade,
future‑proof architecture while keeping the same “no big rewrites” philosophy.
It is compatible with the current feature‑first layout described in
`docs/architecture.md`.

## What Changes vs v1.1

v1.1 locked four key boundaries:

- Global `PttMode` safety defaults (Manner first).
- Policy/feature flags via `PolicyConfig` + `FF` platform guards.
- A stable `VoiceTransport` port for SFU/engine swaps.
- A single `PttController` called by all UI surfaces.

v1.2 keeps those boundaries and strengthens four weak spots:

1. Mutual consent (server truth)
2. Centralized policy evaluation
3. Explicit PTT session state machine
4. Privacy‑safe logging guarantees

The goal is to ship MVP now, then scale to Kakao‑level messenger + Zello‑level
walkie without a rewrite.

## 1) Mutual Walkie Consent (Authoritative)

### Domain

Introduce a friendship consent model that can express:

- `allowFromMe` (my setting)
- `allowFromPeer` (peer setting)
- `allowEffective = allowFromMe && allowFromPeer`
- request timestamps for audit + UX
- block flags both directions

**Rule:** Instant PTT is allowed only when:

1. Global mode is `walkie`
2. Friendship is mutual (`allowEffective == true`)
3. Neither direction is blocked
4. Platform/OS policy allows attempt

### Client Behavior

- UI toggles update only `allowFromMe`.
- `allowFromPeer` arrives from backend and may lag.
- If peer consent is unknown (MVP), treat as `true` to avoid regressions,
  but keep the mutual gate wired in code.

### Backend Contract

Provide a single endpoint/stream that returns peer consent state per friend.
All clients compute `allowEffective` the same way.

## 2) Policy Engine (Single Decision Point)

v1.1 scattered “can I start PTT?” checks across notifiers/controllers.
v1.2 introduces a pure evaluator:

- Input: raw/effective policy, user global mode, mutual consent, block map,
  cooldown, platform/OS runtime info.
- Output: a `PolicyDecision` describing:
  - `effectiveMode` (may downgrade Walkie → Manner)
  - `canStart` / `blockReason`
  - derived booleans like `shouldAttemptInstantPlay`

**Non‑negotiable:** no feature or UI should re‑implement policy gates; they must
call the evaluator.

Benefits:

- Tests become trivial (pure function).
- A/B policy experiments are safe.
- iOS/Android parity is guaranteed.

## 3) PTT Session State Machine

Replace implicit “flags + async gaps” with an explicit state machine.

States:

- `idle`
- `preparing`
- `recording`
- `publishing`
- `playing`
- `error`

Events:

- `pressDown`, `pressUp`
- `policyDowngrade`, `policyBlock`
- `audioFocusLoss`, `transportError`

The state machine lives in application layer and drives:

- local record lifecycle
- transport connect/publish
- foreground service + audio focus
- UI glow/labels

**Invariant:** holding the PTT button keeps the session in
`recording/publishing`; release always transitions to `playing/idle`.

## 4) VoiceTransport v2 (Compatible Extension)

The port remains stable. v2 adds optional streams:

- `Stream<TransportState> state`
- `Stream<TransportStats> stats`

Existing implementations compile unchanged by providing default no‑op streams.

## 5) Audio UX Profiles

Move audio tuning into policy:

- Opus/VAD/DTX profile
- jitter buffer profile
- `BeepProfile` (pre‑tone length, volume)

Receiver playback always follows:

`beep → ~150ms gap → voice`

without bypassing OS silent/DND rules.

## 6) Privacy‑Safe Logging

Add a strict redaction layer:

- Logs only accept whitelisted metadata fields.
- Push payload raw dumps are forbidden.
- Any content field (text/body/audio transcript) must be dropped or hashed.

This is enforced in code by a redactor helper and lint rules.

## 7) Modularization Path (v2+)

Current feature‑first layout is v1.2‑ready.
When the team or AI automation grows, split into internal packages:

- `packages/core`
- `packages/ptt`
- `packages/chat`

Boundaries stay identical; only paths change.

## Success Criteria

- v1 ship: 1:1 Walkie/Manner, safe defaults, no privacy leaks.
- v2 expand: group/PTT framework/E2E without touching UI or app shell.
- Policy/engine swaps require only:
  - changing `PolicyConfig` JSON and evaluator rules
  - swapping `VoiceTransport` implementation
