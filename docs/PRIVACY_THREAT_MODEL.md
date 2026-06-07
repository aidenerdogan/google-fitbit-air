# Privacy Threat Model

## Privacy Promise

Health Passport treats health data as user-owned private data. The default sync
path is local-first: wearable data is imported on the device, normalized, stored
locally, and written to Apple Health only after explicit permission.

## Sensitive Data

- Health samples, workouts, sleep, heart-rate data, HRV, calories, distance,
  and source metadata.
- OAuth tokens and refresh tokens.
- Apple Health permission state.
- AI context packs derived from health trends.
- Encrypted backup blobs.

## Initial Trust Boundaries

- iOS app: trusted local processor for HealthKit and provider sync.
- Apple Health: user-authorized destination for supported writeback.
- Fitbit/Google APIs: external source of wearable data.
- Backend: account, billing, encrypted backup storage, and AI relay only.
- AI provider: receives only explicit, user-approved context packs.

## Non-Negotiable Rules

- Do not sell health data.
- Do not use health data for ads or behavioral targeting.
- Do not upload raw health archives during normal sync.
- Do not log health samples, OAuth tokens, or HealthKit payloads.
- Do not send AI context without a preview and explicit user approval.
- Do not make diagnosis, treatment, or disease-management claims.

## Phase 1 Controls

- Keep sample data fake.
- Add `.gitignore` entries for local databases, logs, environment files, and
  common health export formats.
- Add backend endpoints that explicitly reject raw health sample payloads for AI
  relay requests.
- Add tests for sync receipt and backend privacy behavior.
