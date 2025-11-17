//
//  SettingsView.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var apiKeyManager = APIKeyManager.shared
        @State private var apiKeyInput: String = ""
        @State private var showingAlert = false
        @State private var alertMessage = ""
        @State private var isAPIKeyVisible = false
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack { // 使用 NavigationStack 而不是 NavigationView
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
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            #if os(MacOS)
            .frame(minWidth: 500, minHeight: 600) // 为 macOS 设置最小尺寸
            #endif
            .onAppear {
                loadCurrentAPIKey()
            }
            .alert("API Key Status", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        
        private var headerSection: some View {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "key.radiowaves.forward")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.primary)
                
                Text("API Key Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
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
                    if isAPIKeyVisible {
                        TextField("Enter your API key", text: $apiKeyInput)
                            #if os(iOS)
                            .textFieldStyle(.roundedBorder)
                            #else
                            .textFieldStyle(.roundedBorder)
                            #endif
                    } else {
                        SecureField("Enter your API key", text: $apiKeyInput)
                            #if os(iOS)
                            .textFieldStyle(.roundedBorder)
                            #else
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }
                    
                    Button(action: {
                        isAPIKeyVisible.toggle()
                    }) {
                        Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Clear") {
                        clearAPIKey()
                    }
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
                        .fill(apiKeyManager.hasValidAPIKey ? AppColors.success : AppColors.error)
                        .frame(width: 12, height: 12)
                    
                    Text(apiKeyManager.hasValidAPIKey ? "API Key Configured" : "No API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                }
                
                if apiKeyManager.hasValidAPIKey {
                    let currentKey = apiKeyManager.getAPIKey()
                    let maskedKey = maskAPIKey(currentKey)
                    
                    Text("Current key: \(maskedKey)")
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
    
    private func loadCurrentAPIKey() {
        let currentKey = apiKeyManager.getAPIKey()
        if !currentKey.isEmpty {
            apiKeyInput = currentKey
        }
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard apiKeyManager.validateAPIKey(trimmedKey) else {
            alertMessage = "Please enter a valid API key"
            showingAlert = true
            return
        }
        
        if apiKeyManager.saveAPIKey(trimmedKey) {
            alertMessage = "API key saved successfully"
            showingAlert = true
        } else {
            alertMessage = "Failed to save API key. Please try again."
            showingAlert = true
        }
    }
    
    private func clearAPIKey() {
        if apiKeyManager.deleteAPIKey() {
            apiKeyInput = ""
            alertMessage = "API key cleared successfully"
            showingAlert = true
        } else {
            alertMessage = "Failed to clear API key"
            showingAlert = true
        }
    }
    
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "••••••••" }
        let start = String(key.prefix(4))
        let end = String(key.suffix(4))
        return "\(start)••••••••\(end)"
    }
}

#Preview {
    SettingsView()
}
