#if canImport(CoreVideo) && canImport(QuartzCore)
import CoreVideo
import Dispatch
import QuartzCore

/// CVDisplayLink is available on macOS 13 and schedules samples per display refresh.
/// It never blocks the main thread; only the state mutation is dispatched to it.
final class IslandAnimationDisplayLink {
    private var displayLink: CVDisplayLink?
    private var tick: (() -> Void)?

    deinit {
        stop()
    }

    func start(tick: @escaping () -> Void) {
        stop()
        self.tick = tick

        var candidate: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&candidate) == kCVReturnSuccess,
              let candidate else {
            return
        }

        let result = CVDisplayLinkSetOutputCallback(candidate, islandAnimationDisplayLinkCallback, Unmanaged.passUnretained(self).toOpaque())
        guard result == kCVReturnSuccess else { return }
        displayLink = candidate
        CVDisplayLinkStart(candidate)
    }

    func stop() {
        if let displayLink, CVDisplayLinkIsRunning(displayLink) {
            CVDisplayLinkStop(displayLink)
        }
        displayLink = nil
        tick = nil
    }

    fileprivate func fire() {
        let tick = tick
        DispatchQueue.main.async {
            tick?()
        }
    }
}

private let islandAnimationDisplayLinkCallback: CVDisplayLinkOutputCallback = {
    _, _, _, _, _, context in
    guard let context else { return kCVReturnError }
    let displayLink = Unmanaged<IslandAnimationDisplayLink>.fromOpaque(context).takeUnretainedValue()
    displayLink.fire()
    return kCVReturnSuccess
}
#endif
