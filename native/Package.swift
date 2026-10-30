// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MandarinLens", platforms: [.macOS(.v15)], products: [.executable(name: "MandarinLens", targets: ["MandarinLens"])], targets: [.executableTarget(name: "MandarinLens", swiftSettings: [.swiftLanguageMode(.v5)])])
