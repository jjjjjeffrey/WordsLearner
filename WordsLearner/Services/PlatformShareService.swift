//
//  PlatformShareService.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/17/25.
//

import SwiftUI
import ComposableArchitecture
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PlatformShareService {
    
    static func share(text: String, completion: ((Bool) -> Void)? = nil) {
        #if os(iOS)
        shareOnIOS(text: text, completion: completion)
        #else
        shareOnMacOS(text: text, completion: completion)
        #endif
    }
    
    #if os(iOS)
    private static func shareOnIOS(text: String, completion: ((Bool) -> Void)?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            completion?(false)
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        // iPad 支持
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        
        rootViewController.present(activityVC, animated: true)
    }
    #endif
    
    #if os(macOS)
    private static func shareOnMacOS(text: String, completion: ((Bool) -> Void)?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        
        if success {
            // 显示通知（可选）
            showCopyNotification()
        }
        
        completion?(success)
    }
    
    private static func showCopyNotification() {
        let notification = NSUserNotification()
        notification.title = "Copied to Clipboard"
        notification.informativeText = "Comparison content has been copied to clipboard"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    #endif
}

struct PlatformShareClient: Sendable {
    var share: @Sendable (String) -> Void
}

extension PlatformShareClient: DependencyKey {
    static let liveValue = Self(
        share: { text in
            if Thread.isMainThread {
                PlatformShareService.share(text: text)
            } else {
                DispatchQueue.main.async {
                    PlatformShareService.share(text: text)
                }
            }
        }
    )
    
    static let testValue = Self(
        share: { _ in }
    )
}

extension DependencyValues {
    var platformShare: PlatformShareClient {
        get { self[PlatformShareClient.self] }
        set { self[PlatformShareClient.self] = newValue }
    }
}

// SwiftUI View Modifier for easy sharing
struct ShareViewModifier: ViewModifier {
    let text: String
    @State private var showingShareSuccess = false
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                PlatformShareService.share(text: text) { success in
                    showingShareSuccess = success
                }
            }
            #if os(macOS)
            .alert("Copied!", isPresented: $showingShareSuccess) {
                Button("OK") { }
            } message: {
                Text("Content has been copied to clipboard")
            }
            #endif
    }
}

extension View {
    func shareContent(_ text: String) -> some View {
        modifier(ShareViewModifier(text: text))
    }
}
