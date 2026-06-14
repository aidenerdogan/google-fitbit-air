import Foundation
import HealthPassportKit

#if os(iOS) && canImport(HealthKit)
import HealthKit
#endif

@MainActor
protocol HealthWritebackClient {
    func requestWritePermissions() async throws -> HealthPermissionSnapshot
    func write(_ samples: [VaultSample]) async -> AppleHealthWritebackReceipt
}

struct HealthPermissionSnapshot: Hashable {
    let status: HealthPermissionStatus
    let message: String
    let requestedTypes: [HealthPermissionTypeSnapshot]

    static let notRequested = HealthPermissionSnapshot(
        status: .notRequested,
        message: "Apple Health access has not been requested yet.",
        requestedTypes: HealthPermissionCatalog.fallbackTypes
    )
}

enum HealthPermissionStatus: String {
    case notRequested
    case granted
    case partiallyGranted
    case denied
    case unavailable

    var needsSettingsRecovery: Bool {
        self == .partiallyGranted || self == .denied
    }

    var recoveryHint: String {
        switch self {
        case .partiallyGranted:
            return "Open Settings to turn on missing write permissions when you want full Apple Health writeback."
        case .denied:
            return "Open Settings to allow Apple Health writeback for supported metrics."
        case .notRequested, .granted, .unavailable:
            return ""
        }
    }
}

struct HealthPermissionTypeSnapshot: Identifiable, Hashable {
    let id: String
    let name: String
    let direction: HealthPermissionDirection
    let access: HealthPermissionAccess
}

enum HealthPermissionDirection: String {
    case read = "Read"
    case write = "Write"
}

enum HealthPermissionAccess: String {
    case authorized = "Authorized"
    case denied = "Denied"
    case notDetermined = "Not determined"
    case privacyProtected = "Protected by HealthKit"
    case unavailable = "Unavailable"
}

struct HealthKitWritebackClient: HealthWritebackClient {
    #if os(iOS) && canImport(HealthKit)
    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }
    #else
    init() {}
    #endif

    func requestWritePermissions() async throws -> HealthPermissionSnapshot {
        #if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthPermissionSnapshot(
                status: .unavailable,
                message: "Apple Health is not available on this device.",
                requestedTypes: HealthPermissionCatalog.unavailableTypes
            )
        }

        try await store.requestAuthorization(
            toShare: HealthPermissionCatalog.shareTypes,
            read: HealthPermissionCatalog.readTypes
        )

        return HealthPermissionCatalog.snapshot(for: store)
        #else
        return HealthPermissionSnapshot(
            status: .unavailable,
            message: "HealthKit is unavailable in this build environment.",
            requestedTypes: HealthPermissionCatalog.unavailableTypes
        )
        #endif
    }

    func write(_ samples: [VaultSample]) async -> AppleHealthWritebackReceipt {
        let startedAt = Date()

        #if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return AppleHealthWritebackReceipt(
                startedAt: startedAt,
                finishedAt: Date(),
                results: samples.map { sample in
                    AppleHealthWritebackResult(
                        sampleId: sample.id,
                        metric: sample.metric,
                        status: .failed,
                        message: "Apple Health is not available on this device."
                    )
                }
            )
        }

        var results: [AppleHealthWritebackResult] = []

        for sample in samples {
            let decision = AppleHealthWritebackPolicy.decision(for: sample)
            guard decision.readiness == .writeable else {
                results.append(
                    AppleHealthWritebackResult(
                        sampleId: sample.id,
                        metric: sample.metric,
                        status: decision.readiness == .invalid ? .skipped : .unsupported,
                        message: decision.reason
                    )
                )
                continue
            }

            do {
                let healthSample = try HealthPermissionCatalog.healthKitSample(from: sample)
                try await store.save(healthSample)
                results.append(
                    AppleHealthWritebackResult(
                        sampleId: sample.id,
                        metric: sample.metric,
                        status: .written,
                        message: "Written to Apple Health."
                    )
                )
            } catch {
                results.append(
                    AppleHealthWritebackResult(
                        sampleId: sample.id,
                        metric: sample.metric,
                        status: .failed,
                        message: error.localizedDescription
                    )
                )
            }
        }

        return AppleHealthWritebackReceipt(startedAt: startedAt, finishedAt: Date(), results: results)
        #else
        let results = samples.map { sample in
            AppleHealthWritebackResult(
                sampleId: sample.id,
                metric: sample.metric,
                status: .failed,
                message: "HealthKit is unavailable in this build environment."
            )
        }
        return AppleHealthWritebackReceipt(startedAt: startedAt, finishedAt: Date(), results: results)
        #endif
    }
}

private enum HealthPermissionCatalog {
    static let fallbackTypes: [HealthPermissionTypeSnapshot] = [
        HealthPermissionTypeSnapshot(id: "write.steps", name: "Steps", direction: .write, access: .notDetermined),
        HealthPermissionTypeSnapshot(id: "write.sleep", name: "Sleep", direction: .write, access: .notDetermined),
        HealthPermissionTypeSnapshot(id: "write.heartRate", name: "Heart Rate", direction: .write, access: .notDetermined),
        HealthPermissionTypeSnapshot(id: "write.restingHeartRate", name: "Resting Heart Rate", direction: .write, access: .notDetermined),
        HealthPermissionTypeSnapshot(id: "write.activeEnergy", name: "Active Energy", direction: .write, access: .notDetermined),
        HealthPermissionTypeSnapshot(id: "write.distance", name: "Distance", direction: .write, access: .notDetermined),
        HealthPermissionTypeSnapshot(id: "read.steps", name: "Steps", direction: .read, access: .privacyProtected),
        HealthPermissionTypeSnapshot(id: "read.sleep", name: "Sleep", direction: .read, access: .privacyProtected),
        HealthPermissionTypeSnapshot(id: "read.heartRate", name: "Heart Rate", direction: .read, access: .privacyProtected),
        HealthPermissionTypeSnapshot(id: "read.restingHeartRate", name: "Resting Heart Rate", direction: .read, access: .privacyProtected),
        HealthPermissionTypeSnapshot(id: "read.activeEnergy", name: "Active Energy", direction: .read, access: .privacyProtected),
        HealthPermissionTypeSnapshot(id: "read.distance", name: "Distance", direction: .read, access: .privacyProtected)
    ]

    static let unavailableTypes = fallbackTypes.map {
        HealthPermissionTypeSnapshot(id: $0.id, name: $0.name, direction: $0.direction, access: .unavailable)
    }

    #if os(iOS) && canImport(HealthKit)
    static let writableQuantityTypes: [(id: String, name: String, type: HKQuantityType)] = [
        ("write.steps", "Steps", quantityType(.stepCount)),
        ("write.heartRate", "Heart Rate", quantityType(.heartRate)),
        ("write.restingHeartRate", "Resting Heart Rate", quantityType(.restingHeartRate)),
        ("write.activeEnergy", "Active Energy", quantityType(.activeEnergyBurned)),
        ("write.distance", "Distance", quantityType(.distanceWalkingRunning))
    ]

    static let writableCategoryTypes: [(id: String, name: String, type: HKCategoryType)] = [
        ("write.sleep", "Sleep", categoryType(.sleepAnalysis))
    ]

    static let readableTypes: [(id: String, name: String, type: HKObjectType)] = [
        ("read.steps", "Steps", quantityType(.stepCount)),
        ("read.sleep", "Sleep", categoryType(.sleepAnalysis)),
        ("read.heartRate", "Heart Rate", quantityType(.heartRate)),
        ("read.restingHeartRate", "Resting Heart Rate", quantityType(.restingHeartRate)),
        ("read.activeEnergy", "Active Energy", quantityType(.activeEnergyBurned)),
        ("read.distance", "Distance", quantityType(.distanceWalkingRunning))
    ]

    static var shareTypes: Set<HKSampleType> {
        Set(writableQuantityTypes.map(\.type) + writableCategoryTypes.map(\.type))
    }

    static var readTypes: Set<HKObjectType> {
        Set(readableTypes.map(\.type))
    }

    static func snapshot(for store: HKHealthStore) -> HealthPermissionSnapshot {
        let writeSnapshots = writableQuantityTypes.map { typeSnapshot(id: $0.id, name: $0.name, type: $0.type, store: store) }
            + writableCategoryTypes.map { typeSnapshot(id: $0.id, name: $0.name, type: $0.type, store: store) }
        let readSnapshots = readableTypes.map {
            HealthPermissionTypeSnapshot(
                id: $0.id,
                name: $0.name,
                direction: .read,
                access: .privacyProtected
            )
        }
        let requestedTypes = writeSnapshots + readSnapshots
        let writeAccess = writeSnapshots.map(\.access)
        let authorizedCount = writeAccess.filter { $0 == .authorized }.count
        let status: HealthPermissionStatus

        if authorizedCount == writeAccess.count {
            status = .granted
        } else if authorizedCount == 0 && writeAccess.allSatisfy({ $0 == .denied }) {
            status = .denied
        } else {
            status = .partiallyGranted
        }

        let message: String
        switch status {
        case .granted:
            message = "Apple Health write permissions are granted for supported MVP metrics."
        case .partiallyGranted:
            message = "Some Apple Health write permissions are missing. Health Passport will write only authorized types."
        case .denied:
            message = "Apple Health write permissions were denied. You can change this in Settings."
        case .notRequested:
            message = "Apple Health access has not been requested yet."
        case .unavailable:
            message = "Apple Health is not available on this device."
        }

        return HealthPermissionSnapshot(status: status, message: message, requestedTypes: requestedTypes)
    }

    static func healthKitSample(from sample: VaultSample) throws -> HKSample {
        let start = sample.startAt
        let end = sample.endAt ?? sample.startAt.addingTimeInterval(1)

        switch sample.metric {
        case .steps:
            return try quantitySample(type: quantityType(.stepCount), unit: .count(), sample: sample, start: start, end: end)
        case .heartRate:
            return try quantitySample(
                type: quantityType(.heartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                sample: sample,
                start: start,
                end: end
            )
        case .restingHeartRate:
            return try quantitySample(
                type: quantityType(.restingHeartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                sample: sample,
                start: start,
                end: end
            )
        case .activeEnergy:
            return try quantitySample(type: quantityType(.activeEnergyBurned), unit: .kilocalorie(), sample: sample, start: start, end: end)
        case .distance:
            return try quantitySample(type: quantityType(.distanceWalkingRunning), unit: .meter(), sample: sample, start: start, end: end)
        case .sleep:
            return sleepSample(from: sample, start: start, end: end)
        case .workout, .hrvSdnn, .hrvRmssd:
            throw HealthWritebackError.unsupportedMetric
        }
    }

    private static func typeSnapshot(id: String, name: String, type: HKSampleType, store: HKHealthStore) -> HealthPermissionTypeSnapshot {
        HealthPermissionTypeSnapshot(
            id: id,
            name: name,
            direction: .write,
            access: access(for: store.authorizationStatus(for: type))
        )
    }

    private static func quantitySample(
        type: HKQuantityType,
        unit: HKUnit,
        sample: VaultSample,
        start: Date,
        end: Date
    ) throws -> HKQuantitySample {
        guard let value = sample.numericValue else {
            throw HealthWritebackError.missingValue
        }

        return HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: value),
            start: start,
            end: max(end, start.addingTimeInterval(1))
        )
    }

    private static func sleepSample(from sample: VaultSample, start: Date, end: Date) -> HKCategorySample {
        let sleepValue = sleepAnalysisValue(from: sample.textValue)
        return HKCategorySample(
            type: categoryType(.sleepAnalysis),
            value: sleepValue.rawValue,
            start: start,
            end: max(end, start.addingTimeInterval(1))
        )
    }

    private static func sleepAnalysisValue(from textValue: String?) -> HKCategoryValueSleepAnalysis {
        switch textValue?.lowercased() {
        case "inbed", "in_bed":
            return .inBed
        case "awake":
            return .awake
        case "core":
            return .asleepCore
        case "deep":
            return .asleepDeep
        case "rem":
            return .asleepREM
        default:
            return .asleepUnspecified
        }
    }

    private static func access(for status: HKAuthorizationStatus) -> HealthPermissionAccess {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    private static func quantityType(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            preconditionFailure("Missing HealthKit quantity type: \(identifier.rawValue)")
        }
        return type
    }

    private static func categoryType(_ identifier: HKCategoryTypeIdentifier) -> HKCategoryType {
        guard let type = HKObjectType.categoryType(forIdentifier: identifier) else {
            preconditionFailure("Missing HealthKit category type: \(identifier.rawValue)")
        }
        return type
    }
    #endif
}

enum HealthWritebackError: LocalizedError {
    case missingValue
    case unsupportedMetric

    var errorDescription: String? {
        switch self {
        case .missingValue:
            return "The sample is missing a value required for Apple Health writeback."
        case .unsupportedMetric:
            return "This metric is not supported for Apple Health writeback yet."
        }
    }
}

#if os(iOS) && canImport(HealthKit)
private extension HKHealthStore {
    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthWritebackError.unsupportedMetric)
                }
            }
        }
    }

    func save(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthWritebackError.unsupportedMetric)
                }
            }
        }
    }
}
#endif
