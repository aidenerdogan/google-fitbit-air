// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HealthPassport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HealthPassportApp", targets: ["HealthPassportApp"])
    ],
    targets: [
        .executableTarget(name: "HealthPassportApp")
    ]
)
