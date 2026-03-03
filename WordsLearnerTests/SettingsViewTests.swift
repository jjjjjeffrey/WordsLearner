import SwiftUI
#if os(macOS)
import AppKit
#endif
import ComposableArchitecture
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct SettingsViewTests {
    private func assertSnapshots<V: View>(
        _ view: V,
        name: String,
        record: Bool = false,
        file: StaticString = #filePath,
        testName: String = #function
    ) {
        let shouldRecord = record || ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
        let recording: Bool? = shouldRecord ? true : nil
#if os(macOS)
        let size = measuredFittingSize(for: view, width: 700)
        let wrappedView = ZStack {
            Color(nsColor: .windowBackgroundColor)
            view
        }
        .frame(width: size.width, height: size.height)
        let hosting = NSHostingController(rootView: wrappedView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let failure = verifySnapshot(
            of: hosting,
            as: .imageHiDPI(size: size),
            named: name,
            record: recording,
            file: file,
            testName: testName
        )
        #expect(failure == nil)
#elseif os(iOS) || os(tvOS)
        let lightFailure = verifySnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "\(name).light",
            record: recording,
            file: file,
            testName: testName
        )
        #expect(lightFailure == nil)
        let darkFailure = verifySnapshot(
            of: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "\(name).dark",
            record: recording,
            file: file,
            testName: testName
        )
        #expect(darkFailure == nil)
#endif
    }

    @Test
    func settingsViewNoKeysConfigured() {
        let view = SettingsView(
            store: Store(initialState: SettingsFeature.State()) {
                SettingsFeature()
            } withDependencies: {
                $0.apiKeyManager = .testNoValidAPIKeyValue
            }
        )
#if os(macOS)
        .frame(width: 700, height: 760)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "noKeysConfigured")
    }

    @Test
    func settingsViewBothKeysConfigured() {
        let view = SettingsView(
            store: Store(initialState: SettingsFeature.State()) {
                SettingsFeature()
            } withDependencies: {
                $0.apiKeyManager = APIKeyManagerClient(
                    hasValidAPIKey: { true },
                    getAPIKey: { "aihubmix-key-12345678" },
                    saveAPIKey: { _ in true },
                    deleteAPIKey: { true },
                    validateAPIKey: { _ in true },
                    hasValidElevenLabsAPIKey: { true },
                    getElevenLabsAPIKey: { "elevenlabs-key-abcdefgh" },
                    saveElevenLabsAPIKey: { _ in true },
                    deleteElevenLabsAPIKey: { true },
                    validateElevenLabsAPIKey: { _ in true }
                )
            }
        )
#if os(macOS)
        .frame(width: 700, height: 760)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "bothKeysConfigured")
    }

    @Test
    func settingsViewEditingVisibleKeyInputs() {
        let view = SettingsView(
            store: Store(
                initialState: SettingsFeature.State(
                    apiKeyInput: "live-ai-key",
                    elevenLabsAPIKeyInput: "live-elevenlabs-key",
                    isAPIKeyVisible: true,
                    isElevenLabsAPIKeyVisible: true
                )
            ) {
                SettingsFeature()
            } withDependencies: {
                $0.apiKeyManager = .testNoValidAPIKeyValue
            }
        )
#if os(macOS)
        .frame(width: 700, height: 760)
#elseif os(iOS) || os(tvOS)
        .frame(width: 390, height: 844)
#endif

        assertSnapshots(view, name: "editingVisibleInputs")
    }
}
