//
//  AppColors.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/17/25.
//

import SwiftUI

struct AppColors {
    
    // MARK: - Primary Colors
    static let primary = Color("Primary") // Light 007AFF Dark 0A84FF
    static let secondary = Color("Secondary") // Light 8E8E93 Dark 8E8E93
    static let accent = Color("Accent") // Light FF9500 Dark FF9F0A
    
    // MARK: - Background Colors
    static let background = Color("Background") // Light FFFFFF Dark 000000
    static let secondaryBackground = Color("SecondaryBackground") // Light F2F2F7 Dark 1C1C1E
    static let tertiaryBackground = Color("TertiaryBackground") // Light FFFFFF Dark 2C2C2E
    static let cardBackground = Color("CardBackground") // Light FFFFFF Dark 1C1C1E
    
    // MARK: - Text Colors
    static let primaryText = Color("PrimaryText") // Light 000000 Dark FFFFFF
    static let secondaryText = Color("SecondaryText") // Light 8E8E93 Dark 8E8E93
    static let tertiaryText = Color("TertiaryText") // Light C7C7CC Dark 48484A
    
    // MARK: - Semantic Colors
    static let success = Color("Success") // Light 34C759 Dark 30D158
    static let warning = Color("Warning") // Light FF9500 Dark FF9F0A
    static let error = Color("Error") // Light FF3B30 Dark FF453A
    static let info = Color("Info") // Light 007AFF Dark 0A84FF
    
    // MARK: - Word Comparison Specific
    static let word1Color = Color("Word1Color") // Light 007AFF Dark 0A84FF
    static let word2Color = Color("Word2Color") // Light 34C759 Dark 30D158
    static let word1Background = Color("Word1Background") // Light E3F2FF Dark 1A2332
    static let word2Background = Color("Word2Background") // Light E8F5E8 Dark 1E2A1E
    
    // MARK: - Interactive Elements
    static let buttonBackground = Color("ButtonBackground") // Light 007AFF Dark 0A84FF
    static let buttonText = Color("ButtonText") // Light FFFFFF Dark FFFFFF
    static let fieldBackground = Color("FieldBackground") // Light F2F2F7 Dark 1C1C1E
    static let fieldBorder = Color("FieldBorder") // Light C7C7CC Dark 48484A
    static let separator = Color("Separator") // Light C6C6C8 Dark 38383A
    
    // MARK: - List & Card Colors
    static let listRowBackground = Color("ListRowBackground") // Light FAFBFC Dark 1C1C1E
    static let cardShadow = Color("CardShadow") // Light 000000 opacity 0.12 Dark 000000 opacity 0.25
    static let hoverBackground = Color("HoverBackground") // Light F0F4F8 Dark 2C2C2E
    
    // MARK: - System Fallbacks (for compatibility)
    static let systemGray6Fallback: Color = {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(.windowBackgroundColor).opacity(0.6)
        #endif
    }()
    
    static let systemGray4Fallback: Color = {
        #if os(iOS)
        return Color(.systemGray4)
        #else
        return Color(.separatorColor)
        #endif
    }()
    
    static let systemBackgroundFallback: Color = {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }()
    
    // MARK: - Dynamic Colors for Cross-Platform
    static let dynamicCardBackground: Color = {
        #if os(iOS)
        return cardBackground
        #else
        return cardBackground.opacity(0.8)
        #endif
    }()
    
    static let dynamicSeparator: Color = {
        #if os(iOS)
        return separator
        #else
        return separator.opacity(0.6)
        #endif
    }()
}

// MARK: - Color Extensions
extension AppColors {
    #if canImport(UIKit)
    /// Creates a color with light and dark mode variants
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    #endif
    
    /// Creates a color with different variants for iOS and macOS
    static func platform(ios: Color, mac: Color) -> Color {
        #if os(iOS)
        return ios
        #else
        return mac
        #endif
    }
}
