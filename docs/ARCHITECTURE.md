# Health Passport Architecture

This repository is organized around clear boundaries between product apps, shared domain code, backend services, public documentation, and private planning.

## Top-Level Layout

```text
apps/
  ios/HealthPassport/      Native iOS app, Xcode project, Swift package, app UI

packages/
  core/                    Shared TypeScript data models, normalization, dedupe, receipts

services/
  api/                     Backend skeleton for Pro accounts, encrypted backup, and AI relay

docs/                      Shareable developer documentation only

.project/                  Private local roadmap, review notes, and development loop tracker
```

## Ownership Boundaries

### `apps/`

`apps/` contains user-facing applications. The current app is:

- `apps/ios/HealthPassport`: iOS-first SwiftUI app.

The iOS app owns:

- HealthKit permission and writeback UI.
- Local encrypted vault usage.
- Receipts, Sources, Passport, Coach, and Settings screens.
- Xcode project configuration.

The iOS app should not own:

- Long-term private roadmap notes.
- Backend secrets.
- Fitbit/Google client secrets.
- Cross-platform domain rules that belong in shared packages.

### `packages/`

`packages/` contains reusable, platform-agnostic code.

`packages/core` owns:

- Normalized health sample types.
- Capability matrix rules.
- Dedupe helpers.
- Sync receipt rules.

It should stay independent of SwiftUI, Xcode, HealthKit, and backend runtime details.

### `services/`

`services/` contains backend services.

`services/api` owns:

- Health checks.
- Privacy-safe backend boundaries.
- Future Pro account, encrypted backup, and AI relay APIs.

The backend must not receive raw health archives during normal local sync.

### `docs/`

`docs/` contains documentation that can be shared with collaborators or published with the repository.

Good examples:

- Architecture overview.
- Xcode setup guide.
- Local verification commands.

Not allowed in `docs/`:

- Private roadmap notes.
- App Store strategy drafts.
- Internal risk tracker.
- Secrets, credentials, account IDs, recovery keys, or personal signing settings.

### `.project/`

`.project/` is the local private workspace for planning. It is ignored by Git.

Use it for:

- Roadmap tracking.
- Development loop notes.
- App Store review drafts.
- Privacy threat-model drafts.
- Manual action checklists.

Because `.project/` is ignored, it can be updated every loop without being shared accidentally.

## Development Flow

Every meaningful change should use a small branch:

```text
codex/<slice-name>
```

The preferred loop is:

```text
Plan -> Implement -> Test -> Review -> Commit -> Merge -> Update .project/ROADMAP.md
```

Parallel work should stay separated by area:

- `codex/ios-...` for iOS app slices.
- `codex/core-...` for shared package slices.
- `codex/api-...` for backend slices.
- `codex/docs-...` for public documentation slices.
- `codex/project-...` for private local tracking changes, if they are ever intentionally exported.

## Current Product Boundary

The app currently proves this local-first loop:

```text
development samples -> encrypted local vault -> Apple Health writeback -> receipt UI
```

The next product boundary is:

```text
Fitbit/Google fixture import -> normalized samples -> encrypted vault -> receipts
```

Real OAuth, production API scopes, Pro backup, and AI coaching should come after this fixture-based import loop is stable.
