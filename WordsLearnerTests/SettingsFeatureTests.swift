//
//  SettingsFeatureTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 11/18/25.
//

import Foundation
import ComposableArchitecture
import Testing
import DependenciesTestSupport

@testable import WordsLearner

@MainActor
struct SettingsFeatureTests {
    
    // MARK: - Initial State Tests
    
    @Test
    func initialState() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
        }
        
        #expect(store.state.apiKeyInput == "")
        #expect(store.state.isAPIKeyVisible == false)
        #expect(store.state.hasValidAPIKey == false)
        #expect(store.state.currentMaskedKey == "")
        #expect(store.state.alert == nil)
    }
    
    // MARK: - onAppear Action Tests
    
    @Test
    func onAppearWithExistingAPIKey() async {
        let testKey = "test-api-key-12345678"
        let expectedMasked = "test••••••••5678"
        
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { true },
                getAPIKey: { testKey },
                saveAPIKey: { _ in true },
                deleteAPIKey: { true },
                validateAPIKey: { _ in true }
            )
        }
        
        await store.send(.onAppear) {
            $0.apiKeyInput = testKey
            $0.hasValidAPIKey = true
            $0.currentMaskedKey = expectedMasked
        }
    }
    
    @Test
    func onAppearWithNoAPIKey() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testNoValidAPIKeyValue
        }
        
        await store.send(.onAppear)
        
        #expect(store.state.apiKeyInput == "")
        #expect(store.state.currentMaskedKey == "")
    }
    
    @Test
    func onAppearWithShortAPIKey() async {
        let testKey = "short"
        let expectedMasked = "••••••••"
        
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { true },
                getAPIKey: { testKey },
                saveAPIKey: { _ in true },
                deleteAPIKey: { true },
                validateAPIKey: { _ in true }
            )
        }
        
        await store.send(.onAppear) {
            $0.apiKeyInput = testKey
            $0.hasValidAPIKey = true
            $0.currentMaskedKey = expectedMasked
        }
    }
    
    // MARK: - saveButtonTapped Action Tests
    
    @Test
    func saveButtonTappedWithValidAPIKey() async {
        let testKey = "valid-api-key-12345678"
        let trimmedKey = "  valid-api-key-12345678  "
        let expectedMasked = "vali••••••••5678"
        
        let store = TestStore(initialState: SettingsFeature.State(
            apiKeyInput: trimmedKey
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { true },
                getAPIKey: { testKey },
                saveAPIKey: { _ in true },
                deleteAPIKey: { true },
                validateAPIKey: { _ in true }
            )
        }
        
        await store.send(.saveButtonTapped) {
            $0.hasValidAPIKey = true
            $0.currentMaskedKey = expectedMasked
            $0.alert = AlertState {
                TextState("Success")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("API key saved successfully")
            }
        }
        
        await store.receive(.delegate(.apiKeyChanged))
    }
    
    @Test
    func saveButtonTappedWithInvalidAPIKey() async {
        let invalidKey = "invalid-key"
        
        let store = TestStore(initialState: SettingsFeature.State(
            apiKeyInput: invalidKey
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { false },
                getAPIKey: { "" },
                saveAPIKey: { _ in false },
                deleteAPIKey: { false },
                validateAPIKey: { _ in false }
            )
        }
        
        await store.send(.saveButtonTapped) {
            $0.alert = AlertState {
                TextState("Invalid API Key")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("Please enter a valid API key")
            }
        }
    }
    
    @Test
    func saveButtonTappedWithSaveFailure() async {
        let testKey = "valid-api-key-12345678"
        
        let store = TestStore(initialState: SettingsFeature.State(
            apiKeyInput: testKey
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { true },
                getAPIKey: { testKey },
                saveAPIKey: { _ in false },
                deleteAPIKey: { true },
                validateAPIKey: { _ in true }
            )
        }
        
        await store.send(.saveButtonTapped) {
            $0.alert = AlertState {
                TextState("Error")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("Failed to save API key. Please try again.")
            }
        }
    }
    
    @Test
    func saveButtonTappedTrimsWhitespace() async {
        let testKey = "  valid-key-12345678  "
        let trimmedKey = "valid-key-12345678"
        let expectedMasked = "vali••••••••5678"
        
        let store = TestStore(initialState: SettingsFeature.State(
            apiKeyInput: testKey
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { true },
                getAPIKey: { trimmedKey },
                saveAPIKey: { key in
                    #expect(key == trimmedKey)
                    return true
                },
                deleteAPIKey: { true },
                validateAPIKey: { key in
                    #expect(key == trimmedKey)
                    return true
                }
            )
        }
        
        await store.send(.saveButtonTapped) {
            $0.hasValidAPIKey = true
            $0.currentMaskedKey = expectedMasked
            $0.alert = AlertState {
                TextState("Success")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("API key saved successfully")
            }
        }
        
        await store.receive(.delegate(.apiKeyChanged))
    }
    
    // MARK: - clearButtonTapped Action Tests
    
    @Test
    func clearButtonTappedSuccessfully() async {
        let store = TestStore(initialState: SettingsFeature.State(
            apiKeyInput: "existing-key",
            hasValidAPIKey: true,
            currentMaskedKey: "exis••••••••-key"
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { false },
                getAPIKey: { "" },
                saveAPIKey: { _ in true },
                deleteAPIKey: { true },
                validateAPIKey: { _ in true }
            )
        }
        
        await store.send(.clearButtonTapped) {
            $0.apiKeyInput = ""
            $0.hasValidAPIKey = false
            $0.currentMaskedKey = ""
            $0.alert = AlertState {
                TextState("Success")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("API key cleared successfully")
            }
        }
        
        await store.receive(.delegate(.apiKeyChanged))
    }
    
    @Test
    func clearButtonTappedWithDeleteFailure() async {
        let store = TestStore(initialState: SettingsFeature.State(
            apiKeyInput: "existing-key",
            hasValidAPIKey: true,
            currentMaskedKey: "exis••••••••-key"
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = APIKeyManagerClient(
                hasValidAPIKey: { true },
                getAPIKey: { "existing-key" },
                saveAPIKey: { _ in true },
                deleteAPIKey: { false },
                validateAPIKey: { _ in true }
            )
        }
        
        await store.send(.clearButtonTapped)
        
        // State should remain unchanged when delete fails
        #expect(store.state.apiKeyInput == "existing-key")
        #expect(store.state.hasValidAPIKey == true)
        #expect(store.state.currentMaskedKey == "exis••••••••-key")
        #expect(store.state.alert == nil)
    }
    
    // MARK: - toggleVisibilityButtonTapped Action Tests
    
    @Test
    func toggleVisibilityButtonTapped() async {
        let store = TestStore(initialState: SettingsFeature.State(
            isAPIKeyVisible: false
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
        }
        
        await store.send(.toggleVisibilityButtonTapped) {
            $0.isAPIKeyVisible = true
        }
        
        await store.send(.toggleVisibilityButtonTapped) {
            $0.isAPIKeyVisible = false
        }
    }
    
    // MARK: - Binding Action Tests
    
    @Test
    func bindingAPIKeyInput() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
        }
        
        await store.send(\.binding.apiKeyInput, "new-api-key") {
            $0.apiKeyInput = "new-api-key"
        }
    }
    
    @Test
    func bindingIsAPIKeyVisible() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
        }
        
        await store.send(\.binding.isAPIKeyVisible, true) {
            $0.isAPIKeyVisible = true
        }
    }
    
    // MARK: - Alert Action Tests
    
    @Test
    func alertDismiss() async {
        let store = TestStore(initialState: SettingsFeature.State(
            alert: AlertState {
                TextState("Test Alert")
            }
        )) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
        }
        
        await store.send(\.alert.dismiss) {
            $0.alert = nil
        }
    }
    
    // MARK: - Delegate Action Tests
    
    @Test
    func delegateAction() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
        }
        
        await store.send(.delegate(.apiKeyChanged))
    }
}
