import Foundation
import HealthPassportKit

try runEncryptedVaultSmokeTests()
try runAppleHealthWritebackPolicySmokeTests()

private func runEncryptedVaultSmokeTests() throws {
    let fileURL = temporaryVaultURL()
    let store = EncryptedVaultStore(fileURL: fileURL, keyProvider: testKeyProvider())
    let sample = VaultSample(
        id: "sample-1",
        metric: .steps,
        startAt: Date(timeIntervalSince1970: 1_800),
        endAt: Date(timeIntervalSince1970: 3_600),
        numericValue: 1_234,
        unit: "count",
        source: SourceReference(provider: "fitbit", deviceModel: "Fitbit Air"),
        externalId: "fitbit-steps-1",
        confidence: .high,
        importedAt: Date(timeIntervalSince1970: 4_000)
    )
    let snapshot = VaultSnapshot(
        createdAt: Date(timeIntervalSince1970: 1_000),
        updatedAt: Date(timeIntervalSince1970: 1_000),
        sources: [
            VaultSource(
                id: "fitbit",
                displayName: "Fitbit/Google",
                provider: "fitbit",
                connectedAt: Date(timeIntervalSince1970: 1_000)
            )
        ],
        samples: [sample],
        receipts: [
            VaultReceipt(
                id: "receipt-1",
                sourceId: "fitbit",
                startedAt: Date(timeIntervalSince1970: 4_000),
                finishedAt: Date(timeIntervalSince1970: 4_005),
                imported: 1,
                writtenToAppleHealth: 1
            )
        ]
    )

    try store.save(snapshot)
    assert(store.exists, "Vault file should exist after save")

    let storedBytes = try Data(contentsOf: fileURL)
    let storedText = String(data: storedBytes, encoding: .utf8) ?? ""
    assert(!storedText.contains("Fitbit Air"), "Encrypted file must not expose device model")
    assert(!storedText.contains("fitbit-steps-1"), "Encrypted file must not expose external id")

    let loaded = try store.load()
    assert(loaded.sources.count == 1, "Loaded source count mismatch")
    assert(loaded.samples == [sample], "Loaded samples mismatch")
    assert(loaded.receipts.count == 1, "Loaded receipt count mismatch")

    let archive = try store.exportUserArchive()
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let exportedSnapshot = try decoder.decode(VaultSnapshot.self, from: archive)
    assert(exportedSnapshot.sources.first?.displayName == "Fitbit/Google", "User archive should contain decrypted source name")

    try store.deleteLocalData()
    assert(!store.exists, "Vault file should be deleted")
    let emptyAfterDelete = try store.load()
    assert(emptyAfterDelete.samples.isEmpty, "Deleted vault should load as empty")

    do {
        let invalidStore = EncryptedVaultStore(
            fileURL: temporaryVaultURL(),
            keyProvider: StaticVaultKeyProvider(keyData: Data(repeating: 1, count: 12))
        )
        try invalidStore.save(VaultSnapshot())
        assertionFailure("Invalid key size should fail")
    } catch VaultError.invalidKeySize {
        // Expected.
    }

    print("HealthPassportKitSmokeTests passed")
}

private func runAppleHealthWritebackPolicySmokeTests() throws {
    let source = SourceReference(provider: "fitbit", deviceModel: "Fitbit Air")
    let steps = VaultSample(
        id: "steps-1",
        metric: .steps,
        startAt: Date(timeIntervalSince1970: 10),
        endAt: Date(timeIntervalSince1970: 20),
        numericValue: 500,
        unit: "count",
        source: source
    )
    let hrv = VaultSample(
        id: "hrv-1",
        metric: .hrvRmssd,
        startAt: Date(timeIntervalSince1970: 10),
        numericValue: 40,
        unit: "ms",
        source: source
    )
    let emptySteps = VaultSample(
        id: "steps-empty",
        metric: .steps,
        startAt: Date(timeIntervalSince1970: 10),
        source: source
    )

    let stepsDecision = AppleHealthWritebackPolicy.decision(for: steps)
    assert(stepsDecision.readiness == .writeable, "Steps should be writeable")

    let hrvDecision = AppleHealthWritebackPolicy.decision(for: hrv)
    assert(hrvDecision.readiness == .passportOnly, "RMSSD HRV should remain Passport-only")

    let emptyStepsDecision = AppleHealthWritebackPolicy.decision(for: emptySteps)
    assert(emptyStepsDecision.readiness == .invalid, "Steps without a numeric value should be invalid")
}

private func temporaryVaultURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("vault.hpdata")
}

private func testKeyProvider() -> StaticVaultKeyProvider {
    StaticVaultKeyProvider(keyData: Data((0..<32).map { UInt8($0) }))
}
