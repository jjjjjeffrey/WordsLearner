#if os(macOS)
import AppKit
import SnapshotTesting
import SwiftUI

@MainActor
func measuredFittingSize<V: View>(for view: V, width: CGFloat) -> CGSize {
    let hosting = NSHostingController(rootView: view.fixedSize(horizontal: false, vertical: true))

    hosting.view.frame = CGRect(x: 0, y: 0, width: width, height: 1)
    hosting.view.layoutSubtreeIfNeeded()

    let size = hosting.view.fittingSize
    return CGSize(width: width, height: max(1, ceil(size.height)))
}

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

            vc.view.cacheDisplay(in: vc.view.bounds, to: rep)

            let img = NSImage(size: rep.size)
            img.addRepresentation(rep)
            return img
        }
    }
}
#endif
