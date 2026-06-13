# Health Passport

Health Passport is a privacy-first continuity layer for wearable health data.
The first version focuses on importing supported Fitbit/Google wearable data,
preserving it in a local-first vault, and writing clean supported records back
to Apple Health with user permission.

## Current Milestone

This repository is in Phase 4: HealthKit permissions and writeback.

- Native SwiftUI app shell: `apps/ios/HealthPassport`
- Shared open-core sync models: `packages/core`
- Backend skeleton for Pro/backup/AI relay: `services/api`
- Planning and privacy docs: `docs`
- Xcode app project: `apps/ios/HealthPassport/HealthPassport.xcodeproj`
- HealthKit entitlement and purpose-string templates: `apps/ios/HealthPassport/Config`

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
