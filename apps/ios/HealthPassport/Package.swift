// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HealthPassport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HealthPassportKit", targets: ["HealthPassportKit"]),
        .executable(name: "HealthPassportApp", targets: ["HealthPassportApp"]),
        .executable(name: "HealthPassportKitSmokeTests", targets: ["HealthPassportKitSmokeTests"])
    ],
    targets: [
        .target(name: "HealthPassportKit"),
        .executableTarget(
            name: "HealthPassportApp",
            dependencies: ["HealthPassportKit"]
        ),
        .executableTarget(
            name: "HealthPassportKitSmokeTests",
            dependencies: ["HealthPassportKit"]
        )
    ]
)
