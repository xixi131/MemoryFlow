import AppKit
import CoreGraphics

struct ScreenMetrics: Equatable {
    struct DisplayIdentity: Hashable, Equatable {
        let displayID: CGDirectDisplayID
    }

    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaInsets: NSEdgeInsets
    let notchFrame: CGRect?
    let backingScaleFactor: CGFloat
    let displayIdentity: DisplayIdentity

    init(
        frame: CGRect,
        visibleFrame: CGRect,
        safeAreaInsets: NSEdgeInsets,
        notchFrame: CGRect? = nil,
        backingScaleFactor: CGFloat,
        displayIdentity: DisplayIdentity
    ) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaInsets = safeAreaInsets
        self.notchFrame = notchFrame
        self.backingScaleFactor = backingScaleFactor
        self.displayIdentity = displayIdentity
    }

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
            self.notchFrame = ScreenMetrics.notchFrame(
                screenFrame: screen.frame,
                safeAreaInsets: screen.safeAreaInsets,
                auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: screen.auxiliaryTopRightArea
            )
        } else {
            self.safeAreaInsets = NSEdgeInsetsZero
            self.notchFrame = nil
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
            lhs.notchFrame == rhs.notchFrame &&
            lhs.backingScaleFactor == rhs.backingScaleFactor &&
            lhs.displayIdentity == rhs.displayIdentity
    }

    @available(macOS 12.0, *)
    private static func notchFrame(
        screenFrame: CGRect,
        safeAreaInsets: NSEdgeInsets,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?
    ) -> CGRect? {
        guard let auxiliaryTopLeftArea, let auxiliaryTopRightArea else {
            return nil
        }

        let notchWidth = auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX
        let notchHeight = max(safeAreaInsets.top, auxiliaryTopLeftArea.height, auxiliaryTopRightArea.height)

        guard notchWidth > 0, notchHeight > 0 else {
            return nil
        }

        return CGRect(
            x: auxiliaryTopLeftArea.maxX,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }
}
