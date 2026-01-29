//
//  BackgroundTaskRowTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/16/26.
//

import SwiftUI
import SnapshotTesting
import Testing

@testable import WordsLearner

@MainActor
@Suite
struct BackgroundTaskRowTests {
    
    @Test
    func backgroundTaskRowAllStates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tasks: [WordsLearner.BackgroundTask] = [
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                word1: "accept",
                word2: "except",
                sentence: "I accept all of the terms.",
                status: WordsLearner.BackgroundTask.Status.pending.rawValue,
                response: "",
                error: nil,
                createdAt: now,
                updatedAt: now
            ),
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                word1: "advice",
                word2: "advise",
                sentence: "Please give me some advice.",
                status: WordsLearner.BackgroundTask.Status.generating.rawValue,
                response: "",
                error: nil,
                createdAt: now,
                updatedAt: now
            ),
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                word1: "affect",
                word2: "effect",
                sentence: "How does this affect you?",
                status: WordsLearner.BackgroundTask.Status.completed.rawValue,
                response: "Some automated response.",
                error: nil,
                createdAt: now,
                updatedAt: now
            ),
            WordsLearner.BackgroundTask(
                id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
                word1: "stationary",
                word2: "stationery",
                sentence: "The car is stationary.",
                status: WordsLearner.BackgroundTask.Status.failed.rawValue,
                response: "",
                error: "Network error",
                createdAt: now,
                updatedAt: now
            )
        ]
        
        let view = VStack(spacing: 16) {
            ForEach(tasks) { task in
                BackgroundTaskRow(
                    task: task,
                    onRemove: {},
                    onTap: {},
                    onRegenerate: {}
                )
            }
        }
        .padding()
        .frame(width: 500)
        .background(AppColors.background)
        
#if os(macOS)
        let hosting = NSHostingController(rootView: view)
        let size = measuredSize(for: view, width: 500)
        assertSnapshot(of: hosting, as: .imageHiDPI(size: size), named: "macOS")
#elseif os(iOS) || os(tvOS)
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(of: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
#endif
    }
}

#if os(macOS)
import SwiftUI
import AppKit

@MainActor
func measuredSize<V: View>(for view: V, width: CGFloat) -> CGSize {
    // fixedSize(vertical: true) helps the view expand to fit content vertically
    let hosting = NSHostingController(rootView: view.fixedSize(horizontal: false, vertical: true))

    // Give it a width; height can be minimal initially
    hosting.view.frame = CGRect(x: 0, y: 0, width: width, height: 1)
    hosting.view.layoutSubtreeIfNeeded()

    let size = hosting.view.fittingSize
    return CGSize(width: width, height: max(1, ceil(size.height)))
}
#endif

#if os(macOS)
import AppKit
import SnapshotTesting

extension Snapshotting where Value == NSViewController, Format == NSImage {
    static func imageHiDPI(
        size: CGSize,
        scale: CGFloat = 3,
        wait: TimeInterval = 0.1
    ) -> Snapshotting {
        Snapshotting(pathExtension: "png", diffing: .image) { vc in
            _ = vc.view

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentViewController = vc

            vc.view.frame = NSRect(origin: .zero, size: size)
            vc.view.layoutSubtreeIfNeeded()
            vc.view.displayIfNeeded()

            // Let SwiftUI/AppKit finish any scheduled layout/draw work
            RunLoop.main.run(until: Date().addingTimeInterval(wait))
            CATransaction.flush()

            vc.view.layoutSubtreeIfNeeded()
            vc.view.displayIfNeeded()

            let pixelsWide = Int(ceil(size.width * scale))
            let pixelsHigh = Int(ceil(size.height * scale))

            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
            rep.size = NSSize(width: size.width, height: size.height)

            // Render the view hierarchy into our bitmap
            vc.view.cacheDisplay(in: vc.view.bounds, to: rep)

            let img = NSImage(size: rep.size)
            img.addRepresentation(rep)
            return img
        }
    }
}
#endif
