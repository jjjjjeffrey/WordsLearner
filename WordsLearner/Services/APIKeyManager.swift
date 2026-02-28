//
//  APIKeyManager.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import Foundation
import Security
import Combine

@MainActor
class APIKeyManager: ObservableObject {
    @Published var hasValidAPIKey: Bool = false
    
    private let service = "EnglishWordComparatorApp"
    private let aihubmixAccount = "aihubmix-api-key"
    private let elevenLabsAccount = "elevenlabs-api-key"
    
    static let shared: APIKeyManager = .init()
    
    private init() {
        hasValidAPIKey = !getAPIKey().isEmpty
    }
    
    func saveAPIKey(_ key: String) -> Bool {
        let success = saveKey(key, account: aihubmixAccount)
        
        if success {
            hasValidAPIKey = !key.isEmpty
        }
        
        return success
    }
    
    func getAPIKey() -> String {
        getKey(account: aihubmixAccount)
    }
    
    func deleteAPIKey() -> Bool {
        let success = deleteKey(account: aihubmixAccount)
        
        if success {
            hasValidAPIKey = false
        }
        
        return success
    }

    func saveElevenLabsAPIKey(_ key: String) -> Bool {
        saveKey(key, account: elevenLabsAccount)
    }

    func getElevenLabsAPIKey() -> String {
        getKey(account: elevenLabsAccount)
    }

    func deleteElevenLabsAPIKey() -> Bool {
        deleteKey(account: elevenLabsAccount)
    }

    func validateElevenLabsAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains(" ") && trimmed.count >= 20
    }

    func validateAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count > 10 && !trimmed.contains(" ")
    }

    private func saveKey(_ key: String, account: String) -> Bool {
        let keyData = key.data(using: .utf8)!
        _ = deleteKey(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func getKey(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return ""
    }

    private func deleteKey(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
