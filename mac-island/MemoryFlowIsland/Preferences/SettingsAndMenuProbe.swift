import AppKit
import Foundation

enum SettingsAndMenuProbeError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

@MainActor
enum SettingsAndMenuProbe {
    static func run() throws -> String {
        let suiteName = "com.memoryflow.island.probe.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SettingsAndMenuProbeError.failed("Could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunch = AdvancedFeaturesSettings(store: UserDefaultsAdvancedFeaturesStore(defaults: defaults))
        guard firstLaunch.isEnabled == false else {
            throw SettingsAndMenuProbeError.failed("Advanced Features did not default to disabled")
        }
        var changeNotifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: AdvancedFeaturesSettings.didChangeNotification,
            object: firstLaunch,
            queue: nil
        ) { _ in changeNotifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        firstLaunch.setEnabled(true)
        firstLaunch.setEnabled(true)
        guard changeNotifications == 1 else {
            throw SettingsAndMenuProbeError.failed("Advanced Features emitted duplicate lifecycle changes")
        }
        let relaunched = AdvancedFeaturesSettings(store: UserDefaultsAdvancedFeaturesStore(defaults: defaults))
        guard relaunched.isEnabled else {
            throw SettingsAndMenuProbeError.failed("Advanced Features did not persist across relaunch")
        }

        let disabledPolicy = AdvancedCapabilityPolicy(advancedFeaturesEnabled: false)
        let enabledPolicy = AdvancedCapabilityPolicy(advancedFeaturesEnabled: true)
        guard disabledPolicy.allowsAuthentication == false,
              disabledPolicy.allowsProtectedStudyData == false,
              disabledPolicy.allowsMusic,
              disabledPolicy.allowsUpdates,
              enabledPolicy.allowsAuthentication,
              enabledPolicy.allowsProtectedStudyData,
              enabledPolicy.allowsMusic,
              enabledPolicy.allowsUpdates else {
            throw SettingsAndMenuProbeError.failed("Basic and Advanced capability boundaries are incorrect")
        }

        try validateLoginRequiredPresentation()
        try validateUpdatePromptPresentation()

        let user = AuthenticatedUser(
            id: 7,
            email: "probe@memoryflow.test",
            nickname: "Probe",
            avatarUrl: nil,
            profession: nil,
            age: nil
        )
        guard PreferencesAccountPresentation.resolve(advancedFeaturesEnabled: false, user: nil) == .hidden,
              PreferencesAccountPresentation.resolve(advancedFeaturesEnabled: true, user: nil) == .loggedOut,
              PreferencesAccountPresentation.resolve(advancedFeaturesEnabled: true, user: user) == .loggedIn(email: user.email)
        else {
            throw SettingsAndMenuProbeError.failed("Settings account presentation states are incomplete")
        }

        let menu = StatusMenuBuilder().buildMenu(
            target: ProbeTarget(),
            isIslandVisible: true,
            language: .english,
            phase5Scenarios: [],
            showHideAction: #selector(ProbeTarget.action(_:)),
            phase5ScenarioAction: #selector(ProbeTarget.action(_:)),
            preferencesAction: #selector(ProbeTarget.action(_:)),
            logoutAction: #selector(ProbeTarget.action(_:)),
            quitAction: #selector(ProbeTarget.action(_:))
        )
        let titles = menu.items.map(\.title)
        guard titles.contains("Phase 5 Interactions") == false,
              titles.contains(AppCopy.text(.settings, language: .english)),
              titles.contains(AppCopy.text(.signOut, language: .english)),
              titles.contains(AppCopy.text(.quit, language: .english))
        else {
            throw SettingsAndMenuProbeError.failed("Status menu removal changed an unrelated command: \(titles)")
        }

        return "settings-menu-probe: PASS; default=disabled; persisted=enabled; lifecycle-notifications=deduplicated; basic=music+updates; advanced=auth+review+todo+reminders; login-required=square+notch-safe+spring+reverse+reduce-motion; update-prompt=pure+square+notch-safe+capsules+colors+focus+outside-safe+music-return+reduce-motion; states=hidden,logged-out,logged-in; interactions=absent; menu=preserved"
    }

    private static func validateLoginRequiredPresentation() throws {
        let opened = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .loginRequiredRequested
        )
        let repeated = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .loginRequiredRequested
        )
        let closed = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .outsideCollapse
        )
        let loggedInIgnored = IslandPresentationReducer.reduce(
            current: .loggedInReviewCompact,
            intent: .loginRequiredRequested
        )
        let musicIgnored = IslandPresentationReducer.reduce(
            current: .expandedMusic,
            intent: .loginRequiredRequested
        )
        let musicTakeover = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .musicSnapshotUpdated(.mockPlaybackStart)
        )
        let musicReturn = IslandPresentationReducer.reduce(
            current: musicTakeover.state,
            intent: .musicStopped
        )
        guard opened.derivedState.visualState == .loginRequired,
              opened.derivedState.previewContent.kind == .loginRequired,
              opened.derivedState.previewContent.title == "需要登录",
              opened.derivedState.previewContent.title.count == 4,
              repeated.reason == .noChange,
              closed.derivedState.visualState == .compactCollapsed,
              loggedInIgnored.reason == .intentIgnored,
              musicIgnored.reason == .intentIgnored,
              musicTakeover.derivedState.visualState != .loginRequired,
              musicReturn.derivedState.visualState == .loginRequired,
              IslandTransitionKind.resolve(previous: IslandDerivedState.derive(from: .loggedOutCompact), next: opened.derivedState, reason: opened.reason) == .compactToExpanded,
              IslandTransitionKind.resolve(previous: opened.derivedState, next: closed.derivedState, reason: closed.reason) == .expandedToCompact,
              IslandMotionTokens.profile(for: .compactToExpanded).shellKeyframes.duration > 0,
              IslandMotionTokens.reduceMotionDuration < IslandMotionTokens.profile(for: .compactToExpanded).shellKeyframes.duration else {
            throw SettingsAndMenuProbeError.failed("Login Required reducer or motion contract failed")
        }

        for availableWidth in [1440.0, 360.0] {
            let attachment = TopAttachmentMetrics(
                kind: .notch,
                topBandFrame: CGRect(x: 0, y: 876, width: availableWidth, height: 36),
                notchFrame: CGRect(x: (availableWidth - 180) / 2, y: 876, width: 180, height: 36),
                menuBarHeight: 36,
                safeTopInset: 36,
                pixelScale: 2,
                availableTopWidth: availableWidth,
                centerX: availableWidth / 2
            )
            let result = IslandWindowSizingEngine.resolve(
                state: .loginRequired,
                attachmentMetrics: attachment,
                widthConstraints: IslandLoginRequiredLayout.constraints(for: attachment)
            )
            guard result.visibleFrame.width == result.visibleFrame.height,
                  result.visibleFrame.midX == attachment.centerX,
                  result.visibleFrame.maxY == attachment.topBandFrame.maxY,
                  attachment.expandedContentTopInset >= attachment.notchFrame!.height else {
                throw SettingsAndMenuProbeError.failed("Login Required square or notch anchor failed at width \(availableWidth): frame=\(result.visibleFrame), center=\(attachment.centerX), top=\(attachment.topBandFrame.maxY)")
            }
        }
    }

    private static func validateUpdatePromptPresentation() throws {
        let prompt = IslandUpdatePrompt(version: "1.0.1", build: "101")
        let login = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .loginRequiredRequested
        )
        let opened = IslandPresentationReducer.reduce(
            current: login.state,
            intent: .updatePromptAvailable(prompt)
        )
        let repeated = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .updatePromptAvailable(prompt)
        )
        let outside = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .outsideCollapse
        )
        let later = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .updatePromptLaterRequested
        )
        let music = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .musicSnapshotUpdated(.mockPlaybackStart)
        )
        let musicReturn = IslandPresentationReducer.reduce(
            current: music.state,
            intent: .musicStopped
        )
        let promptOverMusic = IslandPresentationReducer.reduce(
            current: .expandedMusic,
            intent: .updatePromptAvailable(prompt)
        )
        let laterToMusic = IslandPresentationReducer.reduce(
            current: promptOverMusic.state,
            intent: .updatePromptLaterRequested
        )

        guard opened.derivedState.visualState == .updatePrompt,
              opened.derivedState.previewContent.kind == .updatePrompt,
              opened.derivedState.previewContent.title == "MemoryFlow 1.0.1",
              repeated.reason == .noChange,
              outside.reason == .intentIgnored,
              outside.derivedState.visualState == .updatePrompt,
              later.derivedState.visualState == .loginRequired,
              music.derivedState.visualState == .activityCollapsed,
              musicReturn.derivedState.visualState == .updatePrompt,
              laterToMusic.derivedState.visualState == .expandedMusic,
              IslandUpdatePromptLayout.updateColorHex == "#0A84FF",
              IslandUpdatePromptLayout.laterColorHex == "#636366",
              IslandUpdatePromptLayout.actionWidth >= 82,
              IslandUpdatePromptLayout.actionHeight >= 34,
              IslandUpdatePromptLayout.actionSpacing > 0,
              IslandTransitionKind.resolve(
                previous: IslandDerivedState.derive(from: .loggedOutCompact),
                next: opened.derivedState,
                reason: opened.reason
              ) == .compactToExpanded,
              IslandMotionTokens.reduceMotionDuration < IslandMotionTokens.profile(for: .compactToExpanded).shellKeyframes.duration else {
            throw SettingsAndMenuProbeError.failed("Update prompt reducer, action, color, or motion contract failed")
        }

        for availableWidth in [1440.0, 360.0] {
            let attachment = TopAttachmentMetrics(
                kind: .notch,
                topBandFrame: CGRect(x: 0, y: 876, width: availableWidth, height: 36),
                notchFrame: CGRect(x: (availableWidth - 180) / 2, y: 876, width: 180, height: 36),
                menuBarHeight: 36,
                safeTopInset: 36,
                pixelScale: 2,
                availableTopWidth: availableWidth,
                centerX: availableWidth / 2
            )
            let result = IslandWindowSizingEngine.resolve(
                state: .updatePrompt,
                attachmentMetrics: attachment,
                widthConstraints: IslandLoginRequiredLayout.constraints(for: attachment)
            )
            let actionsWidth = IslandUpdatePromptLayout.actionWidth * 2 + IslandUpdatePromptLayout.actionSpacing
            guard result.visibleFrame.width == result.visibleFrame.height,
                  result.visibleFrame.midX == attachment.centerX,
                  result.visibleFrame.maxY == attachment.topBandFrame.maxY,
                  attachment.expandedContentTopInset >= attachment.notchFrame!.height,
                  actionsWidth < result.visibleFrame.width else {
                throw SettingsAndMenuProbeError.failed("Update prompt square, notch, or hit regions failed at width \(availableWidth)")
            }
        }
    }
}

private final class ProbeTarget: NSObject {
    @objc func action(_ sender: Any?) {}
}
