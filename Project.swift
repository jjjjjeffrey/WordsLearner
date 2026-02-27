import ProjectDescription

let appInfoPlist: InfoPlist = .extendingDefault(with: [
    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
    "UIBackgroundModes": ["fetch", "remote-notification"],
    "ITSAppUsesNonExemptEncryption": false,
    "LSApplicationCategoryType": "public.app-category.productivity",
    "UIApplicationSceneManifest": [
        "UIApplicationSupportsMultipleScenes": true,
        "UISceneConfigurations": [:]
    ],
    "UIApplicationSupportsIndirectInputEvents": true,
    "UILaunchScreen": [
        "UILaunchScreen": [:]
    ],
    "UISupportedInterfaceOrientations~ipad": [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationPortraitUpsideDown",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight"
    ],
    "UISupportedInterfaceOrientations~iphone": [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight"
    ]
])

let copySwiftPMFrameworksScript = TargetScript.post(
    script: """
    set -euo pipefail

    if [ \"${PLATFORM_NAME}\" != \"macosx\" ]; then
      exit 0
    fi

    SRC_DIR=\"${BUILT_PRODUCTS_DIR}/PackageFrameworks\"
    DST_DIR=\"${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Contents/Frameworks\"

    if [ ! -d \"$SRC_DIR\" ]; then
      exit 0
    fi

    mkdir -p \"$DST_DIR\"

    # Copy all SwiftPM-built dynamic frameworks into the app bundle
    for FW in \"$SRC_DIR\"/*.framework; do
      [ -d \"$FW\" ] || continue
      /usr/bin/rsync -a --delete \"$FW\" \"$DST_DIR/\"
    done

    # Sign them with the same identity as the app (required by Library Validation)
    for FW in \"$DST_DIR\"/*.framework; do
      [ -d \"$FW\" ] || continue
      /usr/bin/codesign --force --sign \"${EXPANDED_CODE_SIGN_IDENTITY}\" \
        --timestamp=none --preserve-metadata=identifier,entitlements \
        --deep \"$FW\"
    done
    """,
    name: "Copy SwiftPM Frameworks (macOS)",
    basedOnDependencyAnalysis: false
)

let appSettings: Settings = .settings(
    base: [
        "PRODUCT_BUNDLE_IDENTIFIER": "com.jeffrey.wordslearner",
        "MARKETING_VERSION": "1.0",
        "CURRENT_PROJECT_VERSION": "5",
        "DEVELOPMENT_TEAM": "N2328YCXM3",
        "CODE_SIGN_STYLE": "Automatic",
        "CODE_SIGN_ENTITLEMENTS": "WordsLearner/WordsLearner.entitlements",
        "SWIFT_VERSION": "6.0",
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "None",
        "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
        "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=iphoneos*]": "AppIcon",
        "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=macosx*]": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "ENABLE_PREVIEWS": "YES",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator macosx",
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2"
    ],
    configurations: [
        .debug(
            name: "Debug",
            settings: [
                "PRODUCT_BUNDLE_IDENTIFIER": "com.jeffrey.wordslearner.debug"
            ]
        ),
        .release(
            name: "Release",
            settings: [
                "PRODUCT_BUNDLE_IDENTIFIER": "com.jeffrey.wordslearner"
            ]
        )
    ],
    defaultSettings: .recommended
)

let testsSettings: Settings = .settings(
    base: [
        "MARKETING_VERSION": "1.0",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "N2328YCXM3",
        "CODE_SIGN_STYLE": "Automatic",
        "SWIFT_VERSION": "5.0",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator macosx",
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/WordsLearner.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WordsLearner",
        "BUNDLE_LOADER": "$(TEST_HOST)"
    ],
    configurations: [
        .debug(name: "Debug"),
        .release(name: "Release")
    ],
    defaultSettings: .recommended
)

let project = Project(
    name: "WordsLearner",
    options: .options(
        automaticSchemesOptions: .enabled()
    ),
    settings: .settings(
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ],
        defaultSettings: .recommended
    ),
    targets: [
        .target(
            name: "WordsLearner",
            destinations: [.iPhone, .iPad, .mac],
            product: .app,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER)",
            deploymentTargets: .multiplatform(iOS: "26.0", macOS: "26.0"),
            infoPlist: appInfoPlist,
            sources: ["WordsLearner/**"],
            resources: ["WordsLearner/UIComponents/Assets.xcassets"],
            entitlements: .file(path: "WordsLearner/WordsLearner.entitlements"),
            scripts: [copySwiftPMFrameworksScript],
            dependencies: [
                .external(name: "ComposableArchitecture"),
                .external(name: "Dependencies"),
                .external(name: "IssueReporting"),
                .external(name: "Markdown"),
                .external(name: "SQLiteData")
            ],
            settings: appSettings
        ),
        .target(
            name: "WordsLearnerTests",
            destinations: [.iPhone, .iPad, .mac],
            product: .unitTests,
            bundleId: "com.wordslearner.jeffrey.WordsLearnerTests",
            deploymentTargets: .multiplatform(iOS: "26.0", macOS: "26.0"),
            infoPlist: .default,
            sources: ["WordsLearnerTests/**"],
            dependencies: [
                .target(name: "WordsLearner"),
                .external(name: "DependenciesTestSupport"),
                .external(name: "InlineSnapshotTesting"),
                .external(name: "SnapshotTesting"),
                .external(name: "SnapshotTestingCustomDump"),
                .external(name: "SQLiteDataTestSupport")
            ],
            settings: testsSettings
        )
    ]
)
