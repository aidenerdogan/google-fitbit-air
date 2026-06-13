# Health Passport Plan

Status legend:

- `Todo`: Not started yet.
- `In Progress`: Actively being worked on.
- `Blocked`: Waiting for a decision, account, approval, API access, or external action.
- `Done`: Completed and verified.

Build loop:

- Use `docs/DEVELOPMENT_LOOP.md` as the operating loop for each slice: plan, implement, test, review, commit, merge, and update this tracker.
- Current priority: finish the HealthKit writeback receipt loop before starting real Fitbit/Google OAuth.

## 1. Product Goal

Health Passport is a privacy-first app that helps people keep a clean, continuous health and activity record when they use Fitbit/Google wearables, switch devices, change memberships, or use more than one health app.

The app does not replace Fitbit, Garmin, Oura, WHOOP, Apple Health, or Apple Fitness. Its job is to preserve wearable history, explain data gaps, remove duplicates where possible, and write supported clean data back to Apple Health with user permission.

MVP promise:

- `Todo` Preserve wearable activity history in a private local vault.
- `Todo` Sync supported Fitbit/Google data into Apple Health.
- `Todo` Show exactly what was imported, skipped, written, or unsupported.
- `Todo` Explain gaps and trends in simple language.
- `Todo` Keep privacy as the highest product priority.

Current product decisions:

- Platform: iOS-first native app.
- Privacy model: local-first by default.
- First connector: Fitbit/Google.
- First writeback target: Apple Health.
- Business model: Free + Pro.
- Pro value: encrypted backup, restore, advanced continuity, and opt-in AI.
- AI usage: explicit opt-in only, with minimal approved context.
- Medical boundary: wellness and data continuity only, no diagnosis or treatment claims.

## 2. MVP Scope

### Included

- `Todo` Fitbit/Google account connection.
- `Todo` Apple Health permission flow.
- `Todo` Local encrypted health vault.
- `Todo` Import of core wearable data:
  - steps
  - workouts
  - sleep
  - heart rate
  - resting heart rate
  - active calories
  - distance
  - HRV only if the source metric can be mapped safely
- `Todo` Apple Health writeback for supported data types.
- `Todo` Sync receipts after each sync.
- `Todo` Duplicate and conflict detection.
- `Todo` Gap detection when a device, account, membership, or permission stops providing data.
- `Todo` Basic coach explanations for trends and gaps.
- `Todo` Export of user-owned archive.

### Not Included In MVP

- `Todo` Android or Health Connect support.
- `Todo` Full multi-wearable hub support.
- `Todo` Replacing vendor dashboards.
- `Todo` Medical diagnosis, treatment guidance, or disease claims.
- `Todo` Selling health data, ad targeting, or third-party data brokerage.
- `Todo` Automatic AI analysis without explicit user consent.

## 3. Build Phases

### Phase 1: Foundation

- `Done` Initialize the repository structure.
- `Done` Create the native iOS app target.
- `Done` Create the TypeScript open-core package for shared data models and sync rules.
- `Done` Create the backend service skeleton for Pro accounts, encrypted backup, and AI relay.
- `Done` Add license and basic project documentation.
- `Done` Add privacy threat model draft.
- `Done` Add App Store review notes for HealthKit and AI usage.

Done when:

- The project builds a blank iOS app.
- The TypeScript package has tests running.
- The backend can start locally.
- Privacy and review notes exist.

### Phase 2: iOS App Shell

- `Done` Create main app navigation.
- `Done` Add tabs or sections for Passport, Sources, Receipts, Coach, and Settings.
- `Done` Add empty states for first launch.
- `Done` Add onboarding screen explaining Apple Health and Fitbit/Google permissions.
- `In Progress` Add app theme with a simple original visual identity.

Done when:

- The app launches in the simulator.
- The user can move through the main screens.
- The UI does not clone Apple Fitness, Fitbit, or any wearable vendor design.

### Phase 3: Local Vault

- `Done` Choose local storage implementation.
- `Done` Encrypt local health data at rest.
- `Done` Store source metadata and sync receipts.
- `In Progress` Store normalized samples without real test health data in fixtures.
- `Done` Add export path for user-owned archive.
- `Done` Add delete local data action.

Done when:

- Local data can be saved, read, exported, and deleted.
- No raw health data leaves the device during normal local sync.

### Phase 4: HealthKit Permissions And Writeback

- `In Progress` Add HealthKit capability to the iOS app. Code/config templates exist; Xcode capability must still be attached manually.
- `Done` Define requested read and write data types.
- `Done` Ask for permissions with clear purpose text.
- `Done` Handle denied and partially granted permissions.
- `In Progress` Write supported samples to Apple Health. Development sample loop exists; simulator/device tap validation is still required.
- `Done` Record HealthKit write results in sync receipts.

Done when:

- The app can request HealthKit permissions.
- The app can write supported sample data in a test environment.
- Permission failures are shown clearly instead of silently failing.

### Phase 5: Fitbit/Google Connector

- `Todo` Register Fitbit/Google developer app.
- `Todo` Implement OAuth connection flow.
- `Todo` Store provider tokens securely.
- `Todo` Fetch profile/source metadata.
- `Todo` Fetch activity, sleep, heart rate, resting heart rate, calories, and distance.
- `Todo` Normalize Fitbit/Google records into shared data models.
- `Todo` Handle API errors, expired tokens, and rate limits.

Done when:

- A test account can connect.
- Fixture-based connector tests pass.
- Imported records can be shown in the local vault without Apple Health writeback.

### Phase 6: Dedupe And Receipts

- `Todo` Define source priority rules.
- `Todo` Detect duplicate workouts.
- `Todo` Detect overlapping samples.
- `Todo` Detect missing days or missing metric ranges.
- `In Progress` Create sync receipts with imported, written, skipped, unsupported, and failed counts.
- `In Progress` Show receipts in the app.

Done when:

- Users can understand what happened during sync.
- Duplicate records are skipped or flagged.
- Unsupported metrics are preserved in Passport when possible instead of being lost.

### Phase 7: Passport UI

- `Todo` Build the Passport timeline.
- `Todo` Show connected devices and source history.
- `Todo` Show gap map by metric and time range.
- `Todo` Show continuity score.
- `Todo` Show source badges and confidence labels.
- `Todo` Add simple filters by metric and source.

Done when:

- A user can answer: "What data do I have, where did it come from, and what is missing?"

### Phase 8: Pro Backup

- `Todo` Add account sign-in for Pro users.
- `Todo` Encrypt backup on device before upload.
- `Todo` Upload encrypted backup blobs to backend.
- `Todo` Restore backup to a new device.
- `Todo` Add delete cloud backup action.
- `Todo` Document that backend cannot decrypt backups.

Done when:

- Backup and restore work without exposing raw health data to the backend.
- The user can delete cloud backup data.

### Phase 9: AI Coach

- `Todo` Add local deterministic summaries first.
- `Todo` Create AI context-pack preview screen.
- `Todo` Require explicit user approval before sending any context to AI.
- `Todo` Send only minimal trend and gap summaries.
- `Todo` Block diagnosis, treatment, and medical claims in coach responses.
- `Todo` Show coach limitations clearly.

Done when:

- The coach can explain trends and gaps.
- The user can see and approve what is sent.
- No raw full health archive is sent to AI.

### Phase 10: Beta And App Store Readiness

- `Todo` Prepare TestFlight build.
- `Todo` Complete privacy policy.
- `Todo` Complete App Store nutrition labels.
- `Todo` Prepare HealthKit review notes.
- `Todo` Prepare AI usage review notes.
- `Todo` Create screenshots and app preview copy.
- `Todo` Run release privacy and security review.

Done when:

- TestFlight build is ready.
- Store submission materials are complete.
- Privacy claims match implementation.

## 4. Manual Actions

These actions require human accounts, approvals, legal decisions, or App Store setup.

### Apple Developer Access

Status: `Todo`

Steps:

1. Go to the Apple Developer website.
2. Sign in with the Apple ID that will own the app.
3. Confirm the account is enrolled in the Apple Developer Program.
4. If not enrolled, complete enrollment and payment.
5. Save only non-secret account notes in the project tracker.
6. Do not save passwords, recovery keys, or two-factor backup codes in the repo.

### App Bundle ID

Status: `Todo`

Steps:

1. Open Apple Developer account settings.
2. Go to Certificates, Identifiers, and Profiles.
3. Create a new App ID.
4. Choose an explicit bundle ID.
5. Suggested bundle ID placeholder: `com.yourcompany.healthpassport`.
6. Replace `yourcompany` before implementation with the real company or developer namespace.
7. Record the final bundle ID in project documentation.

### Enable HealthKit Capability

Status: `Todo`

Steps:

1. In the Apple Developer portal, open the app identifier.
2. Enable HealthKit capability.
3. In Xcode, open the app target.
4. Add the HealthKit capability.
5. Attach `apps/ios/HealthPassport/Config/HealthPassport.entitlements` or copy its HealthKit key into the app entitlements file.
6. Add the purpose strings from `apps/ios/HealthPassport/Config/Info.plist` to the app target Info settings.
7. Keep permission text simple and specific.
8. Verify the app asks only for data types it truly needs.

### Register Fitbit/Google Developer App

Status: `Todo`

Steps:

1. Open the Fitbit or Google developer console for Fitbit APIs.
2. Create a new application.
3. Add the app name: `Health Passport`.
4. Add the privacy policy URL when available.
5. Add OAuth redirect URI for development.
6. Add OAuth redirect URI for production later.
7. Record app client ID in local development settings.
8. Do not commit client secrets or production credentials.

### Confirm API Scopes And Approval Needs

Status: `Todo`

Steps:

1. List the MVP metrics needed from Fitbit/Google.
2. Map each metric to the required API scope.
3. Check which scopes are available for normal apps.
4. Check whether intraday data requires approval.
5. Check whether sleep stage, HRV, or detailed heart data requires approval.
6. Mark unavailable metrics as `Blocked` or `Later`.
7. Update MVP scope if a metric cannot be accessed reliably.

### Draft Privacy Policy

Status: `Todo`

Steps:

1. Write what data the app reads.
2. Write what data the app writes to Apple Health.
3. Write what data stays on device.
4. Write what data is uploaded only for Pro encrypted backup.
5. Write how AI works and what is sent only after consent.
6. Write how users can export and delete data.
7. Write that health data is not sold or used for ads.
8. Review policy against the actual implementation before release.

### Decide Pro Pricing

Status: `Todo`

Steps:

1. Define what is free.
2. Define what is Pro.
3. Choose monthly price.
4. Choose yearly price.
5. Decide whether to offer a trial.
6. Confirm pricing covers backend, AI, and support costs.
7. Add final prices to App Store Connect only after testing purchases.

### Prepare App Store Screenshots And Review Notes

Status: `Todo`

Steps:

1. Create sample screenshots with fake or demo health data only.
2. Show Passport timeline.
3. Show Sources screen.
4. Show Sync Receipt screen.
5. Show privacy and AI consent screen.
6. Write HealthKit explanation for reviewers.
7. Write AI explanation for reviewers.
8. Confirm screenshots do not contain real personal health data.

## 5. Testing Checklist

### Unit Tests

- `Done` Normalization tests.
- `Todo` Unit conversion tests.
- `Done` Capability matrix tests.
- `Done` Dedupe rule tests.
- `Done` Sync receipt tests.
- `In Progress` Error mapping tests.

### HealthKit Permission Tests

- `Done` All permissions granted.
- `Todo` Some permissions denied.
- `Todo` All permissions denied.
- `Todo` Permissions revoked after first sync.
- `In Progress` Unsupported data type skipped safely.

### Fitbit Fixture Tests

- `Todo` Successful activity import.
- `Todo` Successful sleep import.
- `Todo` Successful heart rate import.
- `Todo` Expired OAuth token.
- `Todo` API rate limit.
- `Todo` Missing metric response.
- `Todo` Provider outage response.

### Privacy Leakage Tests

- `In Progress` Local sync does not send raw health data to backend.
- `Todo` Logs do not include health samples.
- `Todo` Crash reports do not include health samples.
- `Done` Export contains only user-requested data.
- `Done` Delete local data removes local vault data.
- `Todo` Delete cloud backup removes backup blob.

### AI Context-Pack Tests

- `Todo` Context preview is shown before sending.
- `Todo` User can cancel before sending.
- `Todo` Context includes summaries, not full raw archive.
- `Todo` Coach refuses diagnosis and treatment requests.
- `Todo` Coach explains uncertainty and data gaps.

### UI Onboarding Tests

- `Todo` First launch explains the app simply.
- `Todo` Apple Health permission step is clear.
- `Todo` Fitbit/Google connection step is clear.
- `Todo` Failed permission state is recoverable.
- `Todo` First sync receipt is understandable.
- `Todo` Empty states do not blame the user.

## 5.1 Verification Log

- `Done` 2026-06-05: Core and API tests passed with `node --test --experimental-transform-types packages/core/test/*.test.ts services/api/test/*.test.ts`.
- `Done` 2026-06-05: SwiftUI app package built with `swift build --package-path apps/ios/HealthPassport`.
- `Done` 2026-06-08: Swift kit smoke tests passed with `swift run --package-path apps/ios/HealthPassport HealthPassportKitSmokeTests`.
- `Done` 2026-06-08: SwiftUI app package rebuilt with `swift build --package-path apps/ios/HealthPassport`.
- `Done` 2026-06-09: Added HealthKit permission/writeback client, entitlement and purpose-string templates, and writeback policy smoke tests.
- `Done` 2026-06-13: Added `HealthPassport.xcodeproj`, shared app scheme, and beginner-friendly Xcode HealthKit setup notes.
- `Done` 2026-06-13: Xcode project lists app and kit targets with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project apps/ios/HealthPassport/HealthPassport.xcodeproj -list`.
- `Done` 2026-06-13: Xcode simulator build passed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project apps/ios/HealthPassport/HealthPassport.xcodeproj -scheme HealthPassportApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- `Done` 2026-06-13: Simulator screenshot confirmed Apple Health writeback permissions reached `granted`.
- `Done` 2026-06-13: Added development HealthKit writeback receipt loop: fake samples, encrypted vault save, Apple Health write attempt, vault receipt persistence, and receipt UI.
- `Blocked` `swift test` is unavailable in the current Command Line Tools environment because the XCTest/Testing modules are not present.
- `Blocked` Real HealthKit sample writeback validation still requires tapping `Run Sample Writeback` in the simulator or on a device.

## 6. Open Questions

- `Blocked` What exact Fitbit/Google API limits apply to the first developer app?
- `Blocked` Which Fitbit/Google metrics require special approval?
- `Blocked` Can HRV be safely written to Apple Health, or should it stay Passport-only?
- `Blocked` Is a backend OAuth broker required for production OAuth?
- `Todo` Should encrypted backup ship in V1 or V1.1?
- `Todo` What is the final company/developer name for bundle ID and App Store listing?
- `Todo` What should the first Pro price be?
- `Todo` Should Garmin, Oura, WHOOP, or Strava be the second connector after Fitbit/Google?

## 7. Risk Tracker

| Risk | Status | Impact | Mitigation |
| --- | --- | --- | --- |
| Fitbit/Google API access is limited | `Blocked` | Some MVP metrics may be unavailable | Confirm scopes early and adjust MVP to reliable metrics |
| Intraday data requires approval | `Blocked` | Less detailed charts and receipts | Start with daily data, add intraday after approval |
| Apple Health review rejects unclear purpose strings | `Todo` | App Store delay | Keep permission text precise and match implementation |
| Privacy policy does not match implementation | `Todo` | Legal and review risk | Review policy before TestFlight and before App Store submission |
| AI coach appears medical | `Todo` | Compliance and trust risk | Keep coach wellness-only and add refusal rules |
| Google adds official writeback | `Todo` | Pure bridge value may shrink | Emphasize continuity, backup, receipts, dedupe, and AI explanations |
| Backend receives raw health data accidentally | `Todo` | Severe privacy risk | Add privacy leakage tests and local-first architecture checks |

## 8. Implementation Notes

- Use fake or generated health data for development screenshots and tests.
- Never commit real health exports, OAuth secrets, private keys, or App Store credentials.
- Prefer small milestones that can be tested independently.
- Keep the user-facing language simple and non-medical.
- Treat every health-data feature as a privacy feature first.
