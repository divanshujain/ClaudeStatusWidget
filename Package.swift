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
        // Re-enable once Xcode is installed (XCTest requires Xcode IDE)
        // .testTarget(
        //     name: "ClaudeStatusWidgetTests",
        //     dependencies: ["ClaudeStatusWidget"],
        //     path: "Tests/ClaudeStatusWidgetTests"
        // )
    ]
)
