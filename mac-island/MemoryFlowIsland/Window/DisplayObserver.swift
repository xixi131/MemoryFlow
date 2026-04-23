import AppKit

final class DisplayObserver {
    private var observer: NSObjectProtocol?
    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    func startObserving(onChange: @escaping () -> Void) {
        stopObserving()
        observer = center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            onChange()
        }
    }

    func stopObserving() {
        guard let observer else { return }
        center.removeObserver(observer)
        self.observer = nil
    }

    func currentScreenMetrics(for window: NSWindow? = nil) -> ScreenMetrics? {
        guard let screen = currentScreen(for: window) else { return nil }
        return ScreenMetrics(screen: screen)
    }

    private func currentScreen(for window: NSWindow?) -> NSScreen? {
        window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }
}
