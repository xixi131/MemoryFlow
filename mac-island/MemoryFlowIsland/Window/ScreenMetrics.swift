import AppKit
import CoreGraphics

struct ScreenMetrics: Equatable {
    struct DisplayIdentity: Hashable, Equatable {
        let displayID: CGDirectDisplayID
    }

    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaInsets: NSEdgeInsets
    let backingScaleFactor: CGFloat
    let displayIdentity: DisplayIdentity

    init?(screen: NSScreen) {
        guard
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }

        self.frame = screen.frame
        self.visibleFrame = screen.visibleFrame
        if #available(macOS 12.0, *) {
            self.safeAreaInsets = screen.safeAreaInsets
        } else {
            self.safeAreaInsets = NSEdgeInsetsZero
        }
        self.backingScaleFactor = screen.backingScaleFactor
        self.displayIdentity = DisplayIdentity(displayID: CGDirectDisplayID(screenNumber.uint32Value))
    }

    static func == (lhs: ScreenMetrics, rhs: ScreenMetrics) -> Bool {
        lhs.frame == rhs.frame &&
            lhs.visibleFrame == rhs.visibleFrame &&
            lhs.safeAreaInsets.top == rhs.safeAreaInsets.top &&
            lhs.safeAreaInsets.left == rhs.safeAreaInsets.left &&
            lhs.safeAreaInsets.bottom == rhs.safeAreaInsets.bottom &&
            lhs.safeAreaInsets.right == rhs.safeAreaInsets.right &&
            lhs.backingScaleFactor == rhs.backingScaleFactor &&
            lhs.displayIdentity == rhs.displayIdentity
    }
}
