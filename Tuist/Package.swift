// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WordsLearner",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.1"),
        .package(url: "https://github.com/apple/swift-markdown", from: "0.7.3"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.3.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.7.0")
    ]
)

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "CasePaths": .framework,
        "Clocks": .framework,
        "CombineSchedulers": .framework,
        "ComposableArchitecture": .framework,
        "ConcurrencyExtras": .framework,
        "CustomDump": .framework,
        "Dependencies": .framework,
        "IdentifiedCollections": .framework,
        "InternalCollectionsUtilities": .framework,
        "IssueReporting": .framework,
        "IssueReportingPackageSupport": .framework,
        "IssueReportingTestSupport": .framework,
        "OrderedCollections": .framework,
        "Perception": .framework,
        "PerceptionCore": .framework,
        "Sharing": .framework,
        "SwiftUINavigation": .framework,
        "UIKitNavigation": .framework,
        "XCTestDynamicOverlay": .framework
    ]
)
#endif
