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
                    apiKeyInputSection
                } header: {
                    Text("AIHubMix API Key")
                } footer: {
                    Text("Your API key is stored securely in the device keychain and never shared.")
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
                    apiKeySection
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
    
    private var apiKeySection: some View {
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
            
            Text("Enter your AIHubMix API key to enable word comparison features")
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var apiKeyInputSection: some View {
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
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(store.hasValidAPIKey ? AppColors.success : AppColors.error)
                    .frame(width: 12, height: 12)
                
                Text(store.hasValidAPIKey ? "API Key Configured" : "No API Key")
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
        }
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
    )
}


