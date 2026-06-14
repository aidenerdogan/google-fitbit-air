# Xcode And HealthKit Setup

Use this when Xcode does not recognize the repo as an app project or when HealthKit settings are hard to find.

## 1. Open The Correct File

Do not open only the repo folder.

Open this file in Xcode:

`apps/ios/HealthPassport/HealthPassport.xcodeproj`

You should see:

- Scheme: `HealthPassportApp`
- App target: `HealthPassportApp`
- Framework target: `HealthPassportKit`

## 2. Select The App Target

1. In Xcode, click the blue `HealthPassport` project icon in the left navigator.
2. Under `TARGETS`, click `HealthPassportApp`.
3. Make sure you are not editing `HealthPassportKit`.

HealthKit belongs on the app target, not the framework target.

## 3. Set Signing

1. Open the `Signing & Capabilities` tab.
2. Choose your Apple Developer Team.
3. Change `Bundle Identifier` from `com.healthpassport.app` to something unique.
   Example: `com.yourname.HealthPassport`
4. Leave `Automatically manage signing` enabled for local testing.

If you only have a personal Apple account, choose your Personal Team. That is enough for simulator and local device experiments, but not App Store release.

## 4. Confirm HealthKit Capability

The project already includes:

- `apps/ios/HealthPassport/Config/HealthPassport.entitlements`
- `apps/ios/HealthPassport/Config/Info.plist`

In `Signing & Capabilities`:

1. Look for `HealthKit`.
2. If it is already there, leave it.
3. If it is missing, click `+ Capability`.
4. Search for `HealthKit`.
5. Add `HealthKit`.

Do not add extra HealthKit permissions manually yet. The app code requests only the MVP data types it currently supports.

## 5. Run The App

1. Select scheme `HealthPassportApp`.
2. Select an iPhone simulator.
3. Press Run.
4. Open the `Sources` tab in the app.
5. Tap `Request Apple Health Access`.

Expected result:

- Xcode builds the app.
- The app opens.
- The Sources tab shows Apple Health writeback status.
- HealthKit permission status updates after the request.

## 6. Add Google Health OAuth Local Config

Use this after the Google Cloud iOS OAuth client exists.

1. In Xcode, click the blue `HealthPassport` project icon.
2. Select the `HealthPassportApp` target.
3. Open `Build Settings`.
4. Search for `GOOGLE_HEALTH_IOS_CLIENT_ID`.
5. Replace `REPLACE_ME_WITH_GOOGLE_IOS_CLIENT_ID` with the iOS OAuth client ID from Google Cloud.
6. Search for `GOOGLE_HEALTH_OAUTH_REDIRECT_SCHEME`.
7. Set it to your app bundle ID, for example `com.aiden.HealthPassport`, unless your Google OAuth client requires the reversed client ID scheme.
8. Confirm the app builds, then open `Sources`.
9. The `Connect Google Health` button should become enabled when both values are configured.

Do not add a client secret to the app. The iOS flow uses PKCE and stores returned tokens in Keychain.

## 7. If Something Looks Wrong

If Xcode still opens the repo as files only:

1. Close the Xcode window.
2. Use `File > Open...`.
3. Select `apps/ios/HealthPassport/HealthPassport.xcodeproj`.

If command-line Xcode tools still point to Command Line Tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

This is optional for the Xcode app UI, but useful when running `xcodebuild` from terminal.

If HealthKit says unavailable:

1. Confirm you are running the `HealthPassportApp` target.
2. Confirm `HealthKit` exists in `Signing & Capabilities`.
3. Try a real iPhone later if the simulator does not expose the needed HealthKit behavior.
