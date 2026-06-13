# Health Passport

Health Passport is a privacy-first continuity layer for wearable health data.
The first version focuses on importing supported Fitbit/Google wearable data,
preserving it in a local-first vault, and writing clean supported records back
to Apple Health with user permission.

## Repository Layout

- `apps/ios/HealthPassport`: native SwiftUI app, Xcode project, and HealthKit integration.
- `packages/core`: shared TypeScript models, normalization, dedupe, and receipt rules.
- `services/api`: backend skeleton for Pro accounts, encrypted backup, and AI relay.
- `docs`: shareable architecture and setup documentation.
- `.project`: private local roadmap and planning notes, ignored by Git.

See `docs/ARCHITECTURE.md` for the full boundary map.

## Verification

This workspace currently has Node available but not `npm`, and Swift through
Command Line Tools but not full Xcode. The first checks avoid dependency
installation:

```bash
node --test --experimental-transform-types packages/core/test/*.test.ts services/api/test/*.test.ts
swift run --package-path apps/ios/HealthPassport HealthPassportKitSmokeTests
swift build --package-path apps/ios/HealthPassport
```

Full iOS simulator, HealthKit entitlement validation, and real permission prompts require Xcode.
For the Xcode steps, see `docs/XCODE_HEALTHKIT_SETUP.md`.

## Private Planning

Roadmap tracking, internal review notes, and product-loop logs live in `.project/`.
That folder is intentionally ignored so private planning does not get shared by accident.
