//
//  APIKeyManager.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import Foundation
import Security
import Combine

class APIKeyManager: ObservableObject {
    @Published var hasValidAPIKey: Bool = false
    
    private let service = "EnglishWordComparatorApp"
    private let account = "aihubmix-api-key"
    
    static let shared: APIKeyManager = .init()
    
    private init() {
        hasValidAPIKey = !getAPIKey().isEmpty
    }
    
    func saveAPIKey(_ key: String) -> Bool {
        let keyData = key.data(using: .utf8)!
        
        // Delete any existing key first
        deleteAPIKey()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess
        
        if success {
            hasValidAPIKey = !key.isEmpty
        }
        
        return success
    }
    
    func getAPIKey() -> String {
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
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        
        return ""
    }
    
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        
        if success {
            hasValidAPIKey = false
        }
        
        return success
    }
    
    func validateAPIKey(_ key: String) -> Bool {
        // Basic validation - you can make this more sophisticated
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               key.count > 10 && // Reasonable minimum length
               !key.contains(" ") // API keys typically don't have spaces
    }
}

