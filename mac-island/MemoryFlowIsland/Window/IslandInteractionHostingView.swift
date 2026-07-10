import AppKit
import SwiftUI

final class IslandInteractionHostingView: NSHostingView<IslandRootView> {
    var onPointerDown: ((CGPoint) -> Void)?
    var onPointerDragged: ((CGPoint) -> Void)?
    var onPointerUp: ((CGPoint) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var interactiveBounds: CGRect = .zero

    override var isOpaque: Bool {
        false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onPointerDown?(convert(event.locationInWindow, from: nil))
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        onPointerDragged?(convert(event.locationInWindow, from: nil))
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        onPointerUp?(convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        onScrollWheel?(event)
        super.scrollWheel(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveBounds.contains(point) else { return nil }
        return super.hitTest(point)
    }
}
