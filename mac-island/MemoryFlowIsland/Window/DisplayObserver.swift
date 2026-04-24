import AppKit

final class DisplayObserver {
    enum ChangeSignal {
        case screenParametersChanged
    }

    private var observer: NSObjectProtocol?
    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    func startObserving(onChange: @escaping (ChangeSignal) -> Void) {
        stopObserving()
        observer = center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            onChange(.screenParametersChanged)
        }
    }

    func stopObserving() {
        guard let observer else { return }
        center.removeObserver(observer)
        self.observer = nil
    }

    func preferredScreenMetrics(
        for window: NSWindow? = nil,
        preferredDisplayIdentity: ScreenMetrics.DisplayIdentity? = nil
    ) -> ScreenMetrics? {
        let availableMetrics = NSScreen.screens.compactMap(ScreenMetrics.init(screen:))
        let fallbackMetrics = currentScreen(for: window).flatMap(ScreenMetrics.init(screen:))
        return resolvePreferredScreenMetrics(
            availableMetrics: availableMetrics,
            preferredDisplayIdentity: preferredDisplayIdentity,
            fallbackMetrics: fallbackMetrics
        )
    }

    private func currentScreen(for window: NSWindow?) -> NSScreen? {
        window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    func resolvePreferredScreenMetrics(
        availableMetrics: [ScreenMetrics],
        preferredDisplayIdentity: ScreenMetrics.DisplayIdentity?,
        fallbackMetrics: ScreenMetrics?
    ) -> ScreenMetrics? {
        if let preferredDisplayIdentity,
           let matchedMetrics = availableMetrics.first(where: { $0.displayIdentity == preferredDisplayIdentity }) {
            return matchedMetrics
        }

        return fallbackMetrics ?? availableMetrics.first
    }
}
