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
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }
    
    // MARK: - macOS View
    #if os(macOS)
    private var macOSView: some View {
        VStack(spacing: 0) {
            // Custom header for macOS
            headerBar
            
            // Main content
            HSplitView {
                // Left sidebar (empty for now, could add navigation later)
                Color.clear
                    .frame(minWidth: 0, maxWidth: 0)
                
                // Main settings content
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        VStack(spacing: 20) {
                            apiKeySection
                            statusSection
                            helpSection
                        }
                        .frame(maxWidth: 600)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                }
                .frame(minWidth: 500)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            loadCurrentAPIKey()
        }
        .alert("API Key Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Text("Settings")
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    private var apiKeySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AIHubMix API Key")
                        .font(.headline)
                    
                    Text("Enter your API key to enable word comparison features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Group {
                        if isAPIKeyVisible {
                            TextField("Enter your API key", text: $apiKeyInput)
                        } else {
                            SecureField("Enter your API key", text: $apiKeyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 300)
                    
                    Button(action: {
                        isAPIKeyVisible.toggle()
                    }) {
                        Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
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
                    .foregroundColor(.red)
                    
                    Spacer()
                }
                
                Text("Your API key is stored securely in the device keychain and never shared.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        } label: {
            Label("API Configuration", systemImage: "key.fill")
                .font(.title3)
                .fontWeight(.medium)
        }
    }
    #endif
    
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
        .onAppear {
            loadCurrentAPIKey()
        }
        .alert("API Key Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
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
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Enter your API key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
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
        #if os(macOS)
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(apiKeyManager.hasValidAPIKey ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(apiKeyManager.hasValidAPIKey ? "API Key Configured" : "No API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                if apiKeyManager.hasValidAPIKey {
                    let currentKey = apiKeyManager.getAPIKey()
                    let maskedKey = maskAPIKey(currentKey)
                    
                    Text("Current key: \(maskedKey)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
            }
            .padding(16)
        } label: {
            Label("Status", systemImage: "checkmark.circle.fill")
                .font(.title3)
                .fontWeight(.medium)
        }
        #else
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
        #endif
    }
    
    private var helpSection: some View {
        #if os(macOS)
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Link(destination: URL(string: "https://aihubmix.com")!) {
                    Label("Get API Key from AIHubMix", systemImage: "link")
                        .foregroundColor(.blue)
                }
                
                Link(destination: URL(string: "https://aihubmix.com/docs")!) {
                    Label("API Documentation", systemImage: "book")
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
        } label: {
            Label("Help", systemImage: "questionmark.circle.fill")
                .font(.title3)
                .fontWeight(.medium)
        }
        #else
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
        #endif
    }
    
    // MARK: - Helper Methods
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

#Preview("Settings - iOS") {
    SettingsView()
}

#if os(macOS)
#Preview("Settings - macOS") {
    SettingsView()
        .frame(width: 600, height: 500)
}
#endif

