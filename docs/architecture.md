# Voyage Architecture (2025‑12)

This repo is structured to minimize “big rewrites” as PTT/Chat grows.
Key principles: **stable boundaries, feature‑first vertical slices, policy/engine swap by interface**.

## Goals

- **No surprise refactors**: platform/policy/transport can change without touching UI.
- **AI‑friendly**: each feature folder contains everything needed to reason locally.
- **Privacy‑first**: logs never contain user content; metadata only.

## Directory Map

```
lib/
  app/                 # App shell (routing, tabs, bootstrap)
  core/                # Global stable boundaries (theme, flags, utilities)
  services/            # Cross‑feature infrastructure (push, platform, backend)
  features/            # Feature‑first vertical slices
    ptt/
      presentation/    # PTT screens/widgets
      application/     # PttController, state, UI events, policy glue
      data/            # VoiceTransport port + implementations, audio engine, prefs
    chat/
      presentation/
      application/
      domain/
    friends/
      presentation/
      application/
      domain/
    auth/
      presentation/
      application/
      domain/
      data/
    onboarding/
      presentation/
    safety/
      application/     # Abuse/safety reporting
    debug/
      presentation/
      application/
```

## Stable Boundaries

- **Policy / Feature Flags**: `lib/core/feature_flags.dart`
  - Server JSON → `PolicyConfig(raw)` → platform guard → `effective`.
  - App code must branch only on `FF.*` getters.
- **Voice Transport Port**: `lib/features/ptt/data/voice_transport.dart`
  - UI and controllers depend on the port, not LiveKit.
  - Swap engine by changing `VoiceTransportFactory`.
- **PTT Controller**: `lib/features/ptt/application/ptt_controller.dart`
  - UI calls only `startTalk()` / `stopTalk()`.
  - Controller handles permission, cooldown, connect/publish, local record/playback.

## Coding Rules (non‑negotiable)

1. **No business logic in UI**  
   UI widgets call controller/providers only; no direct networking/permissions inside onPressed.
2. **Policy branches via `FF` only**  
   Never scatter OS/version/entitlement checks across the app.
3. **Logs are metadata‑only**  
   Never log chat text, audio content, transcription, or PII.
4. **Feature‑first ownership**  
   Put new files under the owning feature; cross‑feature code lives in `core/` or `services/`.

