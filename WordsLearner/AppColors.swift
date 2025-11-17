//
//  AppColors.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/17/25.
//

import SwiftUI

struct AppColors {
    
    // MARK: - Primary Colors
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let accent = Color("Accent")
    
    // MARK: - Background Colors
    static let background = Color("Background")
    static let secondaryBackground = Color("SecondaryBackground")
    static let tertiaryBackground = Color("TertiaryBackground")
    static let cardBackground = Color("CardBackground")
    
    // MARK: - Text Colors
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let tertiaryText = Color("TertiaryText")
    
    // MARK: - Semantic Colors
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")
    static let info = Color("Info")
    
    // MARK: - Word Comparison Specific
    static let word1Color = Color("Word1Color")
    static let word2Color = Color("Word2Color")
    static let word1Background = Color("Word1Background")
    static let word2Background = Color("Word2Background")
    
    // MARK: - Interactive Elements
    static let buttonBackground = Color("ButtonBackground")
    static let buttonText = Color("ButtonText")
    static let fieldBackground = Color("FieldBackground")
    static let fieldBorder = Color("FieldBorder")
    static let separator = Color("Separator")
    
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
