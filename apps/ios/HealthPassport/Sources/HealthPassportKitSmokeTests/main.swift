import Foundation
import HealthPassportKit

try runEncryptedVaultSmokeTests()
try runAppleHealthWritebackPolicySmokeTests()
try runAppleHealthWritebackReceiptMappingSmokeTests()
try runLegacyVaultReceiptDecodeSmokeTests()
try runFitbitFixtureImportReceiptSmokeTests()
try runDuplicateImportReceiptSmokeTests()
try runPassportGapAnalysisSmokeTests()
print("HealthPassportKitSmokeTests passed")

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

private func runAppleHealthWritebackReceiptMappingSmokeTests() throws {
    let source = SourceReference(provider: "fitbit")
    let importedSamples = [
        VaultSample(id: "steps-1", metric: .steps, startAt: Date(timeIntervalSince1970: 10), numericValue: 500, source: source),
        VaultSample(id: "hrv-1", metric: .hrvRmssd, startAt: Date(timeIntervalSince1970: 20), numericValue: 42, source: source),
        VaultSample(id: "distance-1", metric: .distance, startAt: Date(timeIntervalSince1970: 30), source: source),
        VaultSample(id: "energy-1", metric: .activeEnergy, startAt: Date(timeIntervalSince1970: 40), numericValue: 12, source: source)
    ]
    let receipt = AppleHealthWritebackReceipt(
        id: "writeback-1",
        startedAt: Date(timeIntervalSince1970: 100),
        finishedAt: Date(timeIntervalSince1970: 110),
        results: [
            AppleHealthWritebackResult(sampleId: "steps-1", metric: .steps, status: .written, message: "ok"),
            AppleHealthWritebackResult(sampleId: "hrv-1", metric: .hrvRmssd, status: .unsupported, message: "passport only"),
            AppleHealthWritebackResult(sampleId: "distance-1", metric: .distance, status: .skipped, message: "missing value"),
            AppleHealthWritebackResult(sampleId: "energy-1", metric: .activeEnergy, status: .failed, message: "denied")
        ]
    )

    let vaultReceipt = AppleHealthWritebackReceiptMapper.makeVaultReceipt(
        sourceId: "dev-fitbit-fixture",
        importedSamples: importedSamples,
        writebackReceipt: receipt
    )

    assert(vaultReceipt.id == "writeback-1", "Vault receipt should keep writeback id")
    assert(vaultReceipt.imported == 4, "Imported count mismatch")
    assert(vaultReceipt.writtenToAppleHealth == 1, "Written count mismatch")
    assert(vaultReceipt.skippedWriteback == 1, "Skipped writeback count mismatch")
    assert(vaultReceipt.failedToAppleHealth == 1, "Failed writeback count mismatch")
    assert(vaultReceipt.unsupportedMetrics == [.hrvRmssd], "Unsupported metric mismatch")
}

private func runLegacyVaultReceiptDecodeSmokeTests() throws {
    let json = """
    {
      "id": "legacy-receipt",
      "sourceId": "fitbit",
      "startedAt": "2026-06-13T10:00:00Z",
      "finishedAt": "2026-06-13T10:00:05Z",
      "imported": 1,
      "writtenToAppleHealth": 1,
      "skippedDuplicates": 0,
      "gapsDetected": 0,
      "unsupportedMetrics": []
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let receipt = try decoder.decode(VaultReceipt.self, from: Data(json.utf8))
    assert(receipt.skippedWriteback == 0, "Legacy receipt should default skipped writeback to zero")
    assert(receipt.failedToAppleHealth == 0, "Legacy receipt should default failed writeback to zero")
}

private func runFitbitFixtureImportReceiptSmokeTests() throws {
    let receipt = VaultReceipt(
        id: "fitbit-import",
        sourceId: "fitbit-fixture",
        startedAt: Date(timeIntervalSince1970: 100),
        finishedAt: Date(timeIntervalSince1970: 101),
        imported: 7,
        writtenToAppleHealth: 0,
        unsupportedMetrics: [.hrvRmssd, .hrvRmssd]
    )

    assert(receipt.imported == 7, "Fitbit fixture import should count imported samples")
    assert(receipt.writtenToAppleHealth == 0, "Fitbit fixture import should not write to Apple Health")
    assert(receipt.unsupportedMetrics == [.hrvRmssd], "Unsupported metrics should be unique and sorted")
}

private func runDuplicateImportReceiptSmokeTests() throws {
    let receipt = VaultReceipt(
        id: "fitbit-import-repeat",
        sourceId: "fitbit-fixture",
        startedAt: Date(timeIntervalSince1970: 100),
        finishedAt: Date(timeIntervalSince1970: 101),
        imported: 0,
        writtenToAppleHealth: 0,
        skippedDuplicates: 7,
        unsupportedMetrics: [.hrvRmssd]
    )

    assert(receipt.imported == 0, "Repeat fixture import should not accept duplicates")
    assert(receipt.skippedDuplicates == 7, "Repeat fixture import should record skipped duplicates")
}

private func runPassportGapAnalysisSmokeTests() throws {
    let source = SourceReference(provider: "fitbit", deviceModel: "Fitbit Fixture")
    let dayOneSteps = VaultSample(
        id: "steps-1",
        metric: .steps,
        startAt: Date(timeIntervalSince1970: 1_781_337_600),
        endAt: Date(timeIntervalSince1970: 1_781_341_200),
        numericValue: 1_200,
        source: source
    )
    let dayTwoSteps = VaultSample(
        id: "steps-2",
        metric: .steps,
        startAt: Date(timeIntervalSince1970: 1_781_424_000),
        endAt: Date(timeIntervalSince1970: 1_781_427_600),
        numericValue: 1_320,
        source: source
    )
    let dayOneSleep = VaultSample(
        id: "sleep-1",
        metric: .sleep,
        startAt: Date(timeIntervalSince1970: 1_781_290_800),
        endAt: Date(timeIntervalSince1970: 1_781_317_800),
        textValue: "asleep",
        source: source
    )
    let snapshot = VaultSnapshot(samples: [dayOneSteps, dayTwoSteps, dayOneSleep])
    let analysis = PassportGapAnalyzer.analyze(
        snapshot: snapshot,
        metrics: [.steps, .sleep, .workout],
        windowStart: Date(timeIntervalSince1970: 1_781_308_800),
        windowEnd: Date(timeIntervalSince1970: 1_781_481_540)
    )

    let steps = analysis.metrics.first { $0.metric == .steps }
    let sleep = analysis.metrics.first { $0.metric == .sleep }
    let workout = analysis.metrics.first { $0.metric == .workout }

    assert(analysis.totalMissingDays == 3, "Gap analysis should count missing metric days")
    assert(steps?.status == .ready, "Steps should cover both test days")
    assert(sleep?.status == .gap, "Sleep should show a missing second day")
    assert(sleep?.missingDays.count == 1, "Sleep should miss exactly one day")
    assert(workout?.status == .blocked, "Workout should be blocked without samples")
    assert(workout?.missingDays.count == 2, "Workout should miss both days")
}

private func temporaryVaultURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("vault.hpdata")
}

private func testKeyProvider() -> StaticVaultKeyProvider {
    StaticVaultKeyProvider(keyData: Data((0..<32).map { UInt8($0) }))
}
