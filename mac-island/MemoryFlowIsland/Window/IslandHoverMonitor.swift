import AppKit

final class IslandHoverMonitor {
    private let pollInterval: TimeInterval
    private let exitTolerance: CGFloat
    private let requiredStableSamples: Int
    private let mouseLocationProvider: () -> NSPoint
    private var timer: Timer?
    private var hotspotFrameProvider: (() -> CGRect?)?
    private var onHoverStart: (() -> Void)?
    private var onHoverEnd: (() -> Void)?
    private var isPointerInsideHotspot = false
    private var candidateHoverState: Bool?
    private var candidateSampleCount = 0

    init(
        pollInterval: TimeInterval = 1.0 / 60.0,
        exitTolerance: CGFloat = 8,
        requiredStableSamples: Int = 1,
        mouseLocationProvider: @escaping () -> NSPoint = { NSEvent.mouseLocation }
    ) {
        self.pollInterval = pollInterval
        self.exitTolerance = exitTolerance
        self.requiredStableSamples = max(requiredStableSamples, 1)
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
        candidateHoverState = nil
        candidateSampleCount = 0

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.evaluatePointerLocation()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func reconcileHoverState(expectedInside: Bool) {
        guard timer != nil else { return }
        isPointerInsideHotspot = expectedInside
        candidateHoverState = nil
        candidateSampleCount = 0
        evaluatePointerLocation(requiredSamples: 1)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        hotspotFrameProvider = nil
        onHoverStart = nil
        onHoverEnd = nil
        isPointerInsideHotspot = false
        candidateHoverState = nil
        candidateSampleCount = 0
    }

    private func evaluatePointerLocation(requiredSamples: Int? = nil) {
        let isPointerInsideHotspotNow = currentHoverState()
        guard isPointerInsideHotspotNow != isPointerInsideHotspot else {
            candidateHoverState = nil
            candidateSampleCount = 0
            return
        }

        if candidateHoverState == isPointerInsideHotspotNow {
            candidateSampleCount += 1
        } else {
            candidateHoverState = isPointerInsideHotspotNow
            candidateSampleCount = 1
        }
        guard candidateSampleCount >= (requiredSamples ?? requiredStableSamples) else { return }

        candidateHoverState = nil
        candidateSampleCount = 0
        let previousState = isPointerInsideHotspot
        isPointerInsideHotspot = isPointerInsideHotspotNow

        switch (previousState, isPointerInsideHotspotNow) {
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
        let effectiveFrame = isPointerInsideHotspot
            ? hotspotFrame.insetBy(dx: -exitTolerance, dy: -exitTolerance)
            : hotspotFrame
        return effectiveFrame.contains(mouseLocationProvider())
    }
}
