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
        var isAPIKeyVisible: Bool = false
        var hasValidAPIKey: Bool = false
        var currentMaskedKey: String = ""
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case saveButtonTapped
        case clearButtonTapped
        case toggleVisibilityButtonTapped
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        
        enum Alert: Equatable {}
        
        enum Delegate: Equatable {
            case apiKeyChanged
        }
    }
    
    private var apiKeyManager: APIKeyManagerClient { DependencyValues._current.apiKeyManager }
    @Dependency(\.dismiss) var dismiss
    
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
