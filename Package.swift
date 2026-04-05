// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeStatusWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeStatusWidget",
            path: "Sources/ClaudeStatusWidget",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/ClaudeStatusWidget/Info.plist"])
            ]
        ),
        // NOTE: XCTest is unavailable in Command Line Tools-only environment (no Xcode IDE).
        // Test target is declared but disabled until Xcode is present or testing is restructured.
        // .testTarget(
        //     name: "ClaudeStatusWidgetTests",
        //     dependencies: ["ClaudeStatusWidget"],
        //     path: "Tests/ClaudeStatusWidgetTests"
        // )
    ]
)
