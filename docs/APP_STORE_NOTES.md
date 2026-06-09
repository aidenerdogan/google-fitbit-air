# App Store Review Notes

## HealthKit

Health Passport will request HealthKit access only for data types needed for
the user-visible sync feature. Purpose strings must explain the exact reason:
preserving wearable history, cleaning duplicates, and writing supported records
to Apple Health.

The app must continue to work in a limited mode when users deny or revoke some
permissions.

Current templates live in `apps/ios/HealthPassport/Config`:

- `HealthPassport.entitlements` enables the HealthKit capability.
- `Info.plist` contains HealthKit share and update purpose strings.

## AI

The coach is a wellness and data-explanation feature. It must not diagnose,
treat, or manage diseases. The app should show a preview of the exact summary
context before any cloud AI request.

## Screenshots

Use fake or generated health data only. Do not include real Apple Health,
Fitbit, Google, or personal health screenshots.

## Privacy Claims

Before TestFlight and App Store submission, verify the privacy policy, App
Store nutrition labels, and implementation all match.
