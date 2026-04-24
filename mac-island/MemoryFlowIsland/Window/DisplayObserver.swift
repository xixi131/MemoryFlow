import AppKit

final class DisplayObserver {
    enum ChangeSignal {
        case screenParametersChanged
        case workspaceDidWake
    }

    private struct ObservationRegistration {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    private var observationRegistrations: [ObservationRegistration] = []
    private let center: NotificationCenter
    private let workspaceCenter: NotificationCenter

    init(
        center: NotificationCenter = .default,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        self.center = center
        self.workspaceCenter = workspaceCenter
    }

    func startObserving(onChange: @escaping (ChangeSignal) -> Void) {
        stopObserving()
        observationRegistrations = [
            registerObserver(
                center: center,
                name: NSApplication.didChangeScreenParametersNotification,
                signal: .screenParametersChanged,
                onChange: onChange
            ),
            registerObserver(
                center: workspaceCenter,
                name: NSWorkspace.didWakeNotification,
                signal: .workspaceDidWake,
                onChange: onChange
            )
        ]
    }

    func stopObserving() {
        observationRegistrations.forEach { registration in
            registration.center.removeObserver(registration.token)
        }
        observationRegistrations.removeAll()
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

    private func registerObserver(
        center: NotificationCenter,
        name: NSNotification.Name,
        signal: ChangeSignal,
        onChange: @escaping (ChangeSignal) -> Void
    ) -> ObservationRegistration {
        let token = center.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            onChange(signal)
        }

        return ObservationRegistration(center: center, token: token)
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
