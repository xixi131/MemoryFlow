import AppKit

final class IslandHoverMonitor {
    private let pollInterval: TimeInterval
    private let mouseLocationProvider: () -> NSPoint
    private var timer: Timer?
    private var hotspotFrameProvider: (() -> CGRect?)?
    private var onHoverStart: (() -> Void)?
    private var onHoverEnd: (() -> Void)?
    private var isPointerInsideHotspot = false

    init(
        pollInterval: TimeInterval = 1.0 / 30.0,
        mouseLocationProvider: @escaping () -> NSPoint = { NSEvent.mouseLocation }
    ) {
        self.pollInterval = pollInterval
        self.mouseLocationProvider = mouseLocationProvider
    }

    func startMonitoring(
        hotspotFrameProvider: @escaping () -> CGRect?,
        onHoverStart: @escaping () -> Void,
        onHoverEnd: @escaping () -> Void
    ) {
        stopMonitoring()
        self.hotspotFrameProvider = hotspotFrameProvider
        self.onHoverStart = onHoverStart
        self.onHoverEnd = onHoverEnd
        isPointerInsideHotspot = currentHoverState()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.evaluatePointerLocation()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        hotspotFrameProvider = nil
        onHoverStart = nil
        onHoverEnd = nil
        isPointerInsideHotspot = false
    }

    private func evaluatePointerLocation() {
        let isPointerInsideHotspotNow = currentHoverState()
        defer { isPointerInsideHotspot = isPointerInsideHotspotNow }

        switch (isPointerInsideHotspot, isPointerInsideHotspotNow) {
        case (false, true):
            onHoverStart?()
        case (true, false):
            onHoverEnd?()
        default:
            break
        }
    }

    private func currentHoverState() -> Bool {
        guard let hotspotFrame = hotspotFrameProvider?() else { return false }
        return hotspotFrame.contains(mouseLocationProvider())
    }
}
