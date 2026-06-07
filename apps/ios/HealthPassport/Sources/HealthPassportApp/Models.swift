import Foundation
import HealthPassportKit

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
    let status: String
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
            status: "Connect a source to create the first receipt"
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
