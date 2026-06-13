# Health Passport Development Loop

This loop is the working agreement for building Health Passport until the full roadmap is complete.

The goal is simple: always move through one small, testable product slice at a time, then update the tracker before choosing the next slice.

## Loop Shape

### 1. Plan

- Pick one user-visible slice from `docs/HEALTH_PASSPORT_PLAN.md`.
- Define the exact behavior we want by the end of the slice.
- Name what is intentionally not included.
- Check privacy, HealthKit, AI, and App Store risks before coding.
- List manual actions separately from code actions.

Output:

- A short implementation plan.
- A branch name using `codex/<slice-name>`.
- Updated checklist items when the scope is clear.

### 2. Implement

- Create a focused branch.
- Change only the files needed for the slice.
- Keep private health data, credentials, personal signing settings, and real exports out of the repo.
- Prefer local-first behavior before backend behavior.
- Preserve unsupported metrics in Passport instead of dropping them silently.

Output:

- Working code for the slice.
- No unrelated refactors.
- No committed personal Xcode `DEVELOPMENT_TEAM` or private account data.

### 3. Test

Run the smallest reliable test set first, then broaden when the slice touches platform behavior.

Always run when relevant:

```bash
swift build --package-path apps/ios/HealthPassport
swift run --package-path apps/ios/HealthPassport HealthPassportKitSmokeTests
node --test --experimental-transform-types packages/core/test/*.test.ts services/api/test/*.test.ts
```

For iOS app or HealthKit changes, also run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project apps/ios/HealthPassport/HealthPassport.xcodeproj -scheme HealthPassportApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Manual simulator checks are required when code touches:

- HealthKit permission prompts.
- Apple Health writeback.
- Onboarding and settings flows.
- Anything users must tap, approve, export, or delete.

### 4. Review

Review like a product engineer and privacy reviewer:

- Does the slice actually solve the user problem?
- Does the UI explain state without blaming the user?
- Does the app avoid sending raw health data to the backend?
- Are unsupported metrics preserved and explained?
- Are failed permissions, partial permissions, and missing data handled?
- Are tests meaningful for the risk we introduced?
- Did Xcode add personal signing or user state files that should stay local?

Output:

- Fixes before commit when issues are found.
- Tracker updates for remaining risks and manual actions.

### 5. Commit And Merge

- Commit the slice on its own `codex/<slice-name>` branch.
- Merge back to `main` with a merge commit.
- Keep unrelated local/user changes unstaged.
- Record important verification in `docs/HEALTH_PASSPORT_PLAN.md`.

Output:

- One feature commit.
- One merge commit.
- Clean explanation of what passed and what remains.

### 6. Decide Next Slice

Choose the next slice using this order:

1. Finish the current incomplete value loop.
2. Remove blockers that stop manual validation.
3. Build the next MVP dependency.
4. Polish UI only after the core flow works.
5. Add Pro and AI features after import, vault, writeback, receipts, and privacy tests are reliable.

## Definition Of Done

A slice is done only when:

- Code is implemented.
- Relevant automated checks pass.
- Manual actions are documented.
- User-facing behavior is understandable.
- Privacy claims match implementation.
- The roadmap tracker is updated.
- The branch is committed and merged.

If a slice needs outside accounts, API approval, App Store setup, or a real device, mark that exact part `Blocked` instead of pretending it is done.

## Current Roadmap Position

We are currently in Phase 4: HealthKit permissions and writeback.

Confirmed:

- Xcode project exists.
- App launches in simulator.
- HealthKit permission request works.
- Apple Health write permissions reached `granted` in simulator.

Still missing for the current value loop:

- Tap-test the sample writeback loop in the simulator.
- Confirm receipt rows after a writeback run.
- Add tests for denied and partial HealthKit permission states.
- Add a delete/reset control for development sample data.
- Confirm a real device behaves the same as the simulator.

## Next Three Slices

### Slice 1: HealthKit Writeback Receipt Loop

Goal:

`fake sample -> local vault -> Apple Health writeback -> receipt -> Receipts screen`

Included:

- Development-only fake sample generator.
- Writeback action for supported sample types.
- Vault receipt persistence.
- Receipts screen fed by stored receipts instead of placeholders.
- Tests for writeable, unsupported, and invalid samples.

Not included:

- Fitbit OAuth.
- Real Fitbit data import.
- Production sync scheduling.

### Slice 2: Fitbit/Google Connector Skeleton

Goal:

`OAuth-ready connector boundary -> fixture import -> normalized samples -> local vault`

Included:

- Connector protocol.
- Fixture-based Fitbit records.
- Normalization tests.
- Error mapping for expired token, rate limit, missing metric, and provider outage.

Not included:

- Real production Fitbit OAuth approval.
- Secret storage beyond local development placeholders.

### Slice 3: Dedupe, Gaps, And Passport Timeline

Goal:

`imported samples -> duplicate/gap analysis -> Passport timeline and receipt explanation`

Included:

- Source priority rules.
- Duplicate and overlap detection.
- Missing day or missing metric detection.
- Timeline UI with source badges and confidence labels.

Not included:

- Pro backup.
- AI coach.

## Full Roadmap Gate Order

1. HealthKit writeback receipt loop.
2. Fitbit/Google fixture connector.
3. Real Fitbit/Google OAuth and API access.
4. Dedupe, gaps, and source confidence.
5. Passport timeline.
6. Privacy leakage tests and logging rules.
7. Pro encrypted backup.
8. Local deterministic coach summaries.
9. Opt-in AI context preview and coach.
10. TestFlight and App Store readiness.
