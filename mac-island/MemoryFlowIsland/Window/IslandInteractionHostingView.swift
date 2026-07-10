import AppKit
import SwiftUI

struct IslandPointerInput {
    let identifier: Int
    let location: CGPoint
    let isButtonOrigin: Bool
}

final class IslandInteractionHostingView: NSHostingView<IslandRootView> {
    var onPointerDown: ((IslandPointerInput) -> Void)?
    var onPointerDragged: ((IslandPointerInput) -> Void)?
    var onPointerUp: ((IslandPointerInput) -> Void)?
    var onPointerCancelled: ((Int?) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var interactiveBounds: CGRect = .zero
    private var pointerTrackingArea: NSTrackingArea?
    private var consumesNextPointerTap = false
    private var nextPointerIdentifier = 0
    private var activePointerIdentifier: Int?

    func consumeNextPointerTap() {
        consumesNextPointerTap = true
    }

    override var isOpaque: Bool {
        false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        nextPointerIdentifier += 1
        activePointerIdentifier = nextPointerIdentifier
        onPointerDown?(pointerInput(for: event, identifier: nextPointerIdentifier))
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let activePointerIdentifier else {
            super.mouseDragged(with: event)
            return
        }
        onPointerDragged?(pointerInput(for: event, identifier: activePointerIdentifier))
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if consumesNextPointerTap {
            consumesNextPointerTap = false
            activePointerIdentifier = nil
            return
        }
        guard let activePointerIdentifier else { return }
        onPointerUp?(pointerInput(for: event, identifier: activePointerIdentifier))
        self.activePointerIdentifier = nil
    }

    override func mouseExited(with event: NSEvent) {
        onPointerCancelled?(activePointerIdentifier)
        activePointerIdentifier = nil
        super.mouseExited(with: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        pointerTrackingArea = trackingArea
    }

    override func scrollWheel(with event: NSEvent) {
        onScrollWheel?(event)
        super.scrollWheel(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveBounds.contains(point) else { return nil }
        return super.hitTest(point)
    }

    private func pointerInput(for event: NSEvent, identifier: Int) -> IslandPointerInput {
        let location = convert(event.locationInWindow, from: nil)
        return IslandPointerInput(
            identifier: identifier,
            location: location,
            isButtonOrigin: isButton(at: location)
        )
    }

    private func isButton(at point: CGPoint) -> Bool {
        var candidate = super.hitTest(point)
        while let view = candidate {
            if view is NSButton || view.accessibilityRole() == .button {
                return true
            }
            candidate = view.superview
        }
        return false
    }
}
