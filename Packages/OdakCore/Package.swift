// swift-tools-version: 6.0
import PackageDescription

// Derin's rules (stars, Işık, streaks, collection layers) with no UI or Apple-only frameworks,
// so they can be unit tested with `swift test` on any machine.
let package = Package(
    name: "OdakCore",
    defaultLocalization: "tr",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [.library(name: "OdakCore", targets: ["OdakCore"])],
    targets: [
        .target(name: "OdakCore", resources: [.copy("Resources/sky-calendar.json"), .process("Resources/Localizable.xcstrings")]),
        .testTarget(name: "OdakCoreTests", dependencies: ["OdakCore"]),
    ],
    swiftLanguageModes: [.v5]
)
