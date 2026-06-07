import Foundation

protocol HealthWritebackClient {
    func requestWritePermissions() async throws -> HealthPermissionSnapshot
}

struct HealthPermissionSnapshot: Hashable {
    let status: HealthPermissionStatus
    let message: String
}

enum HealthPermissionStatus: String {
    case notRequested
    case granted
    case partiallyGranted
    case denied
    case unavailable
}

struct HealthKitWritebackClient: HealthWritebackClient {
    func requestWritePermissions() async throws -> HealthPermissionSnapshot {
        #if canImport(HealthKit)
        return HealthPermissionSnapshot(
            status: .notRequested,
            message: "HealthKit wiring is planned for Phase 4."
        )
        #else
        return HealthPermissionSnapshot(
            status: .unavailable,
            message: "HealthKit is unavailable in this build environment."
        )
        #endif
    }
}
