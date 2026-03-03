//
//  SettingsView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }
    
    // MARK: - iOS View
    #if os(iOS)
    private var iOSView: some View {
        NavigationStack {
            Form {
                Section {
                    headerSection
                } header: {
                    Label("API Configuration", systemImage: "key.fill")
                }
                
                Section {
                    aiHubMixAPIKeyInputSection
                } header: {
                    Text("AIHubMix API Key")
                } footer: {
                    Text("Your API key is stored securely in the device keychain and never shared.")
                        .font(.caption)
                }

                Section {
                    elevenLabsAPIKeyInputSection
                } header: {
                    Text("ElevenLabs API Key")
                } footer: {
                    Text("Used for multimodal audio narration generation.")
                        .font(.caption)
                }
                
                Section {
                    statusSection
                } header: {
                    Text("Status")
                }
                
                Section {
                    helpSection
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    #endif
    
    // MARK: - macOS View
    #if os(macOS)
    private var macOSView: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    aiHubMixAPIKeySection
                    elevenLabsAPIKeySection
                    statusSection
                    helpSection
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear { store.send(.onAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    private var headerBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Text("Settings").font(.headline)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var aiHubMixAPIKeySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AIHubMix API Key").font(.headline)
                    Text("Enter your API key to enable word comparison features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Group {
                        if store.isAPIKeyVisible {
                            TextField("Enter your API key", text: $store.apiKeyInput)
                        } else {
                            SecureField("Enter your API key", text: $store.apiKeyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    
                    Button { store.send(.toggleVisibilityButtonTapped) } label: {
                        Image(systemName: store.isAPIKeyVisible ? "eye.slash" : "eye")
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Save") { store.send(.saveButtonTapped) }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Clear") { store.send(.clearButtonTapped) }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
            .padding(16)
        }
    }

    private var elevenLabsAPIKeySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ElevenLabs API Key").font(.headline)
                    Text("Enter your ElevenLabs API key to generate audio narrations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Group {
                        if store.isElevenLabsAPIKeyVisible {
                            TextField("Enter your ElevenLabs API key", text: $store.elevenLabsAPIKeyInput)
                        } else {
                            SecureField("Enter your ElevenLabs API key", text: $store.elevenLabsAPIKeyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button { store.send(.toggleElevenLabsVisibilityButtonTapped) } label: {
                        Image(systemName: store.isElevenLabsAPIKeyVisible ? "eye.slash" : "eye")
                    }
                }

                HStack(spacing: 12) {
                    Button("Save") { store.send(.saveElevenLabsButtonTapped) }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.elevenLabsAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear") { store.send(.clearElevenLabsButtonTapped) }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)

                    Spacer()
                }
            }
            .padding(16)
        }
    }
    #endif
    
    // MARK: - Shared Components
    private var headerSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "key.radiowaves.forward")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primary)
            
            Text("API Key Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure AIHubMix and ElevenLabs API keys for text and audio generation")
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var aiHubMixAPIKeyInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                if store.isAPIKeyVisible {
                    TextField("Enter your API key", text: $store.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Enter your API key", text: $store.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button { store.send(.toggleVisibilityButtonTapped) } label: {
                    Image(systemName: store.isAPIKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            HStack(spacing: 12) {
                Button("Save") { store.send(.saveButtonTapped) }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("Clear") { store.send(.clearButtonTapped) }
                    .buttonStyle(.bordered)
                    .foregroundColor(AppColors.error)
                
                Spacer()
            }
        }
    }

    private var elevenLabsAPIKeyInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                if store.isElevenLabsAPIKeyVisible {
                    TextField("Enter your ElevenLabs API key", text: $store.elevenLabsAPIKeyInput)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Enter your ElevenLabs API key", text: $store.elevenLabsAPIKeyInput)
                        .textFieldStyle(.roundedBorder)
                }

                Button { store.send(.toggleElevenLabsVisibilityButtonTapped) } label: {
                    Image(systemName: store.isElevenLabsAPIKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(AppColors.secondaryText)
                }
            }

            HStack(spacing: 12) {
                Button("Save") { store.send(.saveElevenLabsButtonTapped) }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.elevenLabsAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") { store.send(.clearElevenLabsButtonTapped) }
                    .buttonStyle(.bordered)
                    .foregroundColor(AppColors.error)

                Spacer()
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(store.hasValidAPIKey ? AppColors.success : AppColors.error)
                    .frame(width: 12, height: 12)
                
                Text(store.hasValidAPIKey ? "AIHubMix Key Configured" : "No AIHubMix Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            if store.hasValidAPIKey && !store.currentMaskedKey.isEmpty {
                Text("Current key: \(store.currentMaskedKey)")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .fontDesign(.monospaced)
            }

            HStack {
                Circle()
                    .fill(store.hasValidElevenLabsAPIKey ? AppColors.success : AppColors.error)
                    .frame(width: 12, height: 12)

                Text(store.hasValidElevenLabsAPIKey ? "ElevenLabs Key Configured" : "No ElevenLabs Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }

            if store.hasValidElevenLabsAPIKey && !store.currentMaskedElevenLabsKey.isEmpty {
                Text("ElevenLabs key: \(store.currentMaskedElevenLabsKey)")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .fontDesign(.monospaced)
            }
        }
    }
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "https://aihubmix.com")!) {
                Label("Get API Key from AIHubMix", systemImage: "link")
                    .foregroundColor(AppColors.primary)
            }
            
            Link(destination: URL(string: "https://aihubmix.com/docs")!) {
                Label("API Documentation", systemImage: "book")
                    .foregroundColor(AppColors.primary)
            }

            Link(destination: URL(string: "https://elevenlabs.io")!) {
                Label("Get API Key from ElevenLabs", systemImage: "link")
                    .foregroundColor(AppColors.primary)
            }
        }
    }
}

#if DEBUG
#Preview("Empty State") {
    withDependencies {
        $0.apiKeyManager = .testNoValidAPIKeyValue
    } operation: {
        SettingsView(
            store: Store(initialState: .init()) {
                SettingsFeature()
            }
        )
    }
}

#Preview("Configured State") {
    withDependencies {
        $0.apiKeyManager = .testValue
    } operation: {
        SettingsView(
            store: Store(initialState: .init()) {
                SettingsFeature()
            }
        )
    }
}
#endif

