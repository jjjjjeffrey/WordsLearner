//
//  SettingsFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var apiKeyInput: String = ""
        var elevenLabsAPIKeyInput: String = ""
        var isAPIKeyVisible: Bool = false
        var isElevenLabsAPIKeyVisible: Bool = false
        var hasValidAPIKey: Bool = false
        var hasValidElevenLabsAPIKey: Bool = false
        var currentMaskedKey: String = ""
        var currentMaskedElevenLabsKey: String = ""
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case saveButtonTapped
        case clearButtonTapped
        case toggleVisibilityButtonTapped
        case saveElevenLabsButtonTapped
        case clearElevenLabsButtonTapped
        case toggleElevenLabsVisibilityButtonTapped
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        
        enum Alert: Equatable {}
        
        enum Delegate: Equatable {
            case apiKeyChanged
        }
    }
    
    @Dependency(\.apiKeyManager) var apiKeyManager
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                let currentKey = apiKeyManager.getAPIKey()
                state.hasValidAPIKey = !currentKey.isEmpty
                if !currentKey.isEmpty {
                    state.apiKeyInput = currentKey
                    state.currentMaskedKey = maskAPIKey(currentKey)
                }
                let currentElevenLabsKey = apiKeyManager.getElevenLabsAPIKey()
                state.hasValidElevenLabsAPIKey = !currentElevenLabsKey.isEmpty
                if !currentElevenLabsKey.isEmpty {
                    state.elevenLabsAPIKeyInput = currentElevenLabsKey
                    state.currentMaskedElevenLabsKey = maskAPIKey(currentElevenLabsKey)
                }
                return .none
                
            case .saveButtonTapped:
                let trimmedKey = state.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard apiKeyManager.validateAPIKey(trimmedKey) else {
                    state.alert = AlertState {
                        TextState("Invalid API Key")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Please enter a valid API key")
                    }
                    return .none
                }
                
                if apiKeyManager.saveAPIKey(trimmedKey) {
                    state.hasValidAPIKey = true
                    state.currentMaskedKey = maskAPIKey(trimmedKey)
                    state.alert = AlertState {
                        TextState("Success")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("API key saved successfully")
                    }
                    return .send(.delegate(.apiKeyChanged))
                } else {
                    state.alert = AlertState {
                        TextState("Error")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Failed to save API key. Please try again.")
                    }
                    return .none
                }
                
            case .clearButtonTapped:
                if apiKeyManager.deleteAPIKey() {
                    state.apiKeyInput = ""
                    state.hasValidAPIKey = false
                    state.currentMaskedKey = ""
                    state.alert = AlertState {
                        TextState("Success")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("API key cleared successfully")
                    }
                    return .send(.delegate(.apiKeyChanged))
                }
                return .none
                
            case .toggleVisibilityButtonTapped:
                state.isAPIKeyVisible.toggle()
                return .none

            case .saveElevenLabsButtonTapped:
                let trimmedKey = state.elevenLabsAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard apiKeyManager.validateElevenLabsAPIKey(trimmedKey) else {
                    state.alert = AlertState {
                        TextState("Invalid ElevenLabs API Key")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Please enter a valid ElevenLabs API key")
                    }
                    return .none
                }
                if apiKeyManager.saveElevenLabsAPIKey(trimmedKey) {
                    state.hasValidElevenLabsAPIKey = true
                    state.currentMaskedElevenLabsKey = maskAPIKey(trimmedKey)
                    state.alert = AlertState {
                        TextState("Success")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("ElevenLabs API key saved successfully")
                    }
                    return .send(.delegate(.apiKeyChanged))
                } else {
                    state.alert = AlertState {
                        TextState("Error")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Failed to save ElevenLabs API key. Please try again.")
                    }
                }
                return .none

            case .clearElevenLabsButtonTapped:
                if apiKeyManager.deleteElevenLabsAPIKey() {
                    state.elevenLabsAPIKeyInput = ""
                    state.hasValidElevenLabsAPIKey = false
                    state.currentMaskedElevenLabsKey = ""
                    state.alert = AlertState {
                        TextState("Success")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("ElevenLabs API key cleared successfully")
                    }
                    return .send(.delegate(.apiKeyChanged))
                }
                return .none

            case .toggleElevenLabsVisibilityButtonTapped:
                state.isElevenLabsAPIKeyVisible.toggle()
                return .none
                
            case .alert:
                return .none
                
            case .delegate:
                return .none
                
            case .binding:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

private func maskAPIKey(_ key: String) -> String {
    guard key.count > 8 else { return "••••••••" }
    let start = String(key.prefix(4))
    let end = String(key.suffix(4))
    return "\(start)••••••••\(end)"
}
