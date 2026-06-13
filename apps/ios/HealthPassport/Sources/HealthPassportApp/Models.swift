import Foundation
import HealthPassportKit
import Security
import SwiftUI

struct PassportMetric: Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let status: MetricStatus
    let detail: String
}

enum MetricStatus: String {
    case ready = "Ready"
    case gap = "Gap"
    case blocked = "Blocked"
    case unsupported = "Unsupported"
}

struct SyncReceiptSummary: Identifiable, Hashable {
    let id: String
    let source: String
    let imported: Int
    let written: Int
    let skipped: Int
    let unsupported: Int
    let failed: Int
    let status: String
    let finishedAt: Date?
}

enum DemoData {
    static let metrics: [PassportMetric] = [
        PassportMetric(
            id: "steps",
            name: "Steps",
            source: "Fitbit/Google",
            status: .ready,
            detail: "Ready for Apple Health writeback"
        ),
        PassportMetric(
            id: "sleep",
            name: "Sleep",
            source: "Fitbit/Google",
            status: .gap,
            detail: "Will show missing nights after first sync"
        ),
        PassportMetric(
            id: "hrv",
            name: "HRV",
            source: "Fitbit/Google",
            status: .unsupported,
            detail: "Kept Passport-only until metric mapping is confirmed"
        )
    ]

    static let receipts: [SyncReceiptSummary] = [
        SyncReceiptSummary(
            id: "placeholder",
            source: "No sync yet",
            imported: 0,
            written: 0,
            skipped: 0,
            unsupported: 0,
            failed: 0,
            status: "Connect a source to create the first receipt",
            finishedAt: nil
        )
    ]

    static let onboardingSteps: [OnboardingStep] = [
        OnboardingStep(
            title: "Connect your source",
            detail: "Fitbit/Google will be the first wearable connection. No account tokens are stored in plain app files."
        ),
        OnboardingStep(
            title: "Review Apple Health permissions",
            detail: "Health Passport asks only for the data types needed for writeback and keeps working when some access is denied."
        ),
        OnboardingStep(
            title: "Keep a private vault",
            detail: "Imported records are normalized into an encrypted local vault before any optional backup or AI feature."
        )
    ]

    static let vaultPreview = VaultSnapshot(
        sources: [
            VaultSource(
                id: "local-vault",
                displayName: "Encrypted Local Vault",
                provider: "health_passport",
                connectedAt: Date(timeIntervalSince1970: 1_771_200_000)
            )
        ]
    )
}

struct OnboardingStep: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
}

@MainActor
final class HealthPassportAppState: ObservableObject {
    @Published private(set) var vaultSnapshot: VaultSnapshot = .empty
    @Published var permissionSnapshot = HealthPermissionSnapshot.notRequested
    @Published var isRequestingAppleHealth = false
    @Published var isRunningWritebackLoop = false
    @Published var isImportingFitbitFixture = false
    @Published var loopStatusMessage = "No writeback loop has run yet."
    @Published var fitbitImportStatusMessage = "No Fitbit fixture has been imported yet."

    private let vaultStore: EncryptedVaultStore?
    private let healthClient: HealthWritebackClient
    private let startupError: String?

    init(vaultStore: EncryptedVaultStore?, healthClient: HealthWritebackClient, startupError: String? = nil) {
        self.vaultStore = vaultStore
        self.healthClient = healthClient
        self.startupError = startupError
        loadVault()
    }

    static func live() -> HealthPassportAppState {
        do {
            let store = try EncryptedVaultStore.live()
            return HealthPassportAppState(vaultStore: store, healthClient: HealthKitWritebackClient())
        } catch {
            return HealthPassportAppState(
                vaultStore: nil,
                healthClient: HealthKitWritebackClient(),
                startupError: error.localizedDescription
            )
        }
    }

    var receiptSummaries: [SyncReceiptSummary] {
        let sourceNames = Dictionary(uniqueKeysWithValues: vaultSnapshot.sources.map { ($0.id, $0.displayName) })
        let summaries = vaultSnapshot.receipts
            .sorted { $0.finishedAt > $1.finishedAt }
            .map { receipt in
                let skipped = receipt.skippedDuplicates + receipt.skippedWriteback
                let source = sourceNames[receipt.sourceId] ?? receipt.sourceId
                let unsupportedCount = receipt.unsupportedMetrics.count
                let status = "\(receipt.writtenToAppleHealth) written, \(skipped) skipped, \(unsupportedCount) unsupported, \(receipt.failedToAppleHealth) failed"

                return SyncReceiptSummary(
                    id: receipt.id,
                    source: source,
                    imported: receipt.imported,
                    written: receipt.writtenToAppleHealth,
                    skipped: skipped,
                    unsupported: unsupportedCount,
                    failed: receipt.failedToAppleHealth,
                    status: status,
                    finishedAt: receipt.finishedAt
                )
            }

        return summaries.isEmpty ? DemoData.receipts : summaries
    }

    var vaultSourceCount: Int {
        vaultSnapshot.sources.count
    }

    func loadVault() {
        guard let vaultStore else {
            loopStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        do {
            vaultSnapshot = try vaultStore.load()
        } catch {
            loopStatusMessage = "Local vault could not be loaded: \(error.localizedDescription)"
        }
    }

    func requestAppleHealthAccess() async {
        isRequestingAppleHealth = true
        defer { isRequestingAppleHealth = false }

        do {
            permissionSnapshot = try await healthClient.requestWritePermissions()
        } catch {
            permissionSnapshot = HealthPermissionSnapshot(
                status: .denied,
                message: error.localizedDescription,
                requestedTypes: permissionSnapshot.requestedTypes
            )
        }
    }

    func runDevelopmentWritebackLoop() async {
        guard let vaultStore else {
            loopStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        isRunningWritebackLoop = true
        loopStatusMessage = "Preparing development samples."
        defer { isRunningWritebackLoop = false }

        do {
            if permissionSnapshot.status != .granted {
                permissionSnapshot = try await healthClient.requestWritePermissions()
            }

            var snapshot = try vaultStore.load()
            let source = DevelopmentHealthSamples.source
            if !snapshot.sources.contains(where: { $0.id == source.id }) {
                snapshot.sources.append(source)
            }

            let samples = DevelopmentHealthSamples.makeSamples()
            snapshot.samples.append(contentsOf: samples)
            loopStatusMessage = "Writing supported samples to Apple Health."

            let writebackReceipt = await healthClient.write(samples)
            let vaultReceipt = AppleHealthWritebackReceiptMapper.makeVaultReceipt(
                sourceId: source.id,
                importedSamples: samples,
                writebackReceipt: writebackReceipt
            )

            snapshot.receipts.append(vaultReceipt)
            try vaultStore.save(snapshot)
            vaultSnapshot = try vaultStore.load()
            loopStatusMessage = "Writeback receipt saved."
        } catch {
            loopStatusMessage = "Writeback loop failed: \(error.localizedDescription)"
        }
    }

    func importFitbitFixture() async {
        guard let vaultStore else {
            fitbitImportStatusMessage = startupError ?? "Local vault is unavailable."
            return
        }

        isImportingFitbitFixture = true
        fitbitImportStatusMessage = "Importing Fitbit fixture."
        defer { isImportingFitbitFixture = false }

        do {
            var snapshot = try vaultStore.load()
            let source = FitbitFixtureImport.source
            if !snapshot.sources.contains(where: { $0.id == source.id }) {
                snapshot.sources.append(source)
            }

            let samples = FitbitFixtureImport.makeSamples()
            snapshot.samples.append(contentsOf: samples)
            let receipt = VaultReceipt(
                id: UUID().uuidString,
                sourceId: source.id,
                startedAt: Date(),
                finishedAt: Date(),
                imported: samples.count,
                writtenToAppleHealth: 0,
                skippedDuplicates: 0,
                unsupportedMetrics: [.hrvRmssd]
            )
            snapshot.receipts.append(receipt)

            try vaultStore.save(snapshot)
            vaultSnapshot = try vaultStore.load()
            fitbitImportStatusMessage = "Fitbit fixture imported into the local vault."
        } catch {
            fitbitImportStatusMessage = "Fitbit fixture import failed: \(error.localizedDescription)"
        }
    }
}

private enum DevelopmentHealthSamples {
    static let source = VaultSource(
        id: "dev-fitbit-fixture",
        displayName: "Development Fitbit Fixture",
        provider: "fitbit_fixture",
        connectedAt: Date(timeIntervalSince1970: 1_771_200_000)
    )

    static func makeSamples(now: Date = Date()) -> [VaultSample] {
        let runId = UUID().uuidString
        let start = now.addingTimeInterval(-3_600)
        let end = now.addingTimeInterval(-1_800)
        let sourceReference = SourceReference(provider: source.provider, deviceModel: "Development Fixture", appName: "Health Passport")

        return [
            VaultSample(
                id: "dev-steps-\(runId)",
                metric: .steps,
                startAt: start,
                endAt: end,
                numericValue: 1_240,
                unit: "count",
                source: sourceReference,
                externalId: "dev-steps-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "dev-energy-\(runId)",
                metric: .activeEnergy,
                startAt: start,
                endAt: end,
                numericValue: 82,
                unit: "kcal",
                source: sourceReference,
                externalId: "dev-energy-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "dev-hrv-\(runId)",
                metric: .hrvRmssd,
                startAt: end,
                numericValue: 43,
                unit: "ms",
                source: sourceReference,
                externalId: "dev-hrv-\(runId)",
                confidence: .medium,
                importedAt: now
            ),
            VaultSample(
                id: "dev-distance-invalid-\(runId)",
                metric: .distance,
                startAt: start,
                endAt: end,
                unit: "m",
                source: sourceReference,
                externalId: "dev-distance-invalid-\(runId)",
                confidence: .low,
                importedAt: now
            )
        ]
    }
}

private enum FitbitFixtureImport {
    static let source = VaultSource(
        id: "fitbit-fixture",
        displayName: "Fitbit Fixture",
        provider: "fitbit",
        connectedAt: Date(timeIntervalSince1970: 1_771_200_000)
    )

    static func makeSamples(now: Date = Date()) -> [VaultSample] {
        let runId = UUID().uuidString
        let sourceReference = SourceReference(provider: source.provider, deviceModel: "Fitbit Fixture", appName: "Health Passport")
        let morningStart = now.addingTimeInterval(-12_000)
        let morningEnd = now.addingTimeInterval(-8_400)
        let sleepStart = now.addingTimeInterval(-36_000)
        let sleepEnd = now.addingTimeInterval(-9_000)

        return [
            VaultSample(
                id: "fitbit-steps-\(runId)",
                metric: .steps,
                startAt: morningStart,
                endAt: morningEnd,
                numericValue: 1_280,
                unit: "count",
                source: sourceReference,
                externalId: "fitbit-fixture-steps-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-sleep-\(runId)",
                metric: .sleep,
                startAt: sleepStart,
                endAt: sleepEnd,
                textValue: "asleep",
                source: sourceReference,
                externalId: "fitbit-fixture-sleep-\(runId)",
                confidence: .medium,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-heart-rate-\(runId)",
                metric: .heartRate,
                startAt: morningEnd,
                numericValue: 72,
                unit: "count/min",
                source: sourceReference,
                externalId: "fitbit-fixture-hr-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-resting-heart-rate-\(runId)",
                metric: .restingHeartRate,
                startAt: sleepEnd,
                numericValue: 58,
                unit: "count/min",
                source: sourceReference,
                externalId: "fitbit-fixture-rhr-\(runId)",
                confidence: .medium,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-active-energy-\(runId)",
                metric: .activeEnergy,
                startAt: morningStart,
                endAt: morningEnd,
                numericValue: 86,
                unit: "kcal",
                source: sourceReference,
                externalId: "fitbit-fixture-energy-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-distance-\(runId)",
                metric: .distance,
                startAt: morningStart,
                endAt: morningEnd,
                numericValue: 920,
                unit: "m",
                source: sourceReference,
                externalId: "fitbit-fixture-distance-\(runId)",
                confidence: .high,
                importedAt: now
            ),
            VaultSample(
                id: "fitbit-hrv-rmssd-\(runId)",
                metric: .hrvRmssd,
                startAt: sleepEnd,
                numericValue: 44,
                unit: "ms",
                source: sourceReference,
                externalId: "fitbit-fixture-hrv-rmssd-\(runId)",
                confidence: .low,
                importedAt: now
            )
        ]
    }
}

private enum AppVaultError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case randomKeyGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case .keychainReadFailed(let status):
            return "Could not read the vault key from Keychain: \(status)."
        case .keychainWriteFailed(let status):
            return "Could not save the vault key to Keychain: \(status)."
        case .randomKeyGenerationFailed(let status):
            return "Could not create a local vault key: \(status)."
        }
    }
}

private struct KeychainVaultKeyProvider: VaultKeyProviding {
    private let service = "com.healthpassport.local-vault"
    private let account = "vault-key-v1"

    func vaultKeyData() throws -> Data {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &item)
        if readStatus == errSecSuccess, let data = item as? Data {
            return data
        }
        guard readStatus == errSecItemNotFound else {
            throw AppVaultError.keychainReadFailed(readStatus)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw AppVaultError.randomKeyGenerationFailed(randomStatus)
        }

        let keyData = Data(bytes)
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = keyData
        #if os(iOS)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppVaultError.keychainWriteFailed(addStatus)
        }

        return keyData
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private extension EncryptedVaultStore {
    static func live() throws -> EncryptedVaultStore {
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppVaultError.applicationSupportDirectoryUnavailable
        }

        let fileURL = applicationSupportURL
            .appendingPathComponent("HealthPassport", isDirectory: true)
            .appendingPathComponent("vault.hpdata")

        return EncryptedVaultStore(fileURL: fileURL, keyProvider: KeychainVaultKeyProvider())
    }
}
