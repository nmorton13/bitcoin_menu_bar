// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BitcoinBar",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "BitcoinBar",
            targets: ["BitcoinBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "BitcoinBar",
            path: "Sources/BitcoinBar"
        )
    ]
)
