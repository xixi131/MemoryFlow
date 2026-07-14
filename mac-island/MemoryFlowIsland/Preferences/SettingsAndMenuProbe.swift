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

        try validateBundledUpdateConfiguration()

        try validateLoginRequiredPresentation()
        try validateUpdatePromptPresentation()
        try validateUpdateDownloadPresentation()

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

        return "settings-menu-probe: PASS; default=disabled; persisted=enabled; lifecycle-notifications=deduplicated; basic=music+updates; advanced=auth+review+todo+reminders; login-required=compact-expanded+notch-safe+spring+reverse+reduce-motion; update-prompt=login-shape+modal+capsules+colors+focus+outside-safe+music-underlay; update-download=pure+priority+left-blue-spinner+right-stable-percent+empty-notch+reduce-motion+restore; states=hidden,logged-out,logged-in; interactions=absent; menu=preserved"
    }

    private static func validateBundledUpdateConfiguration() throws {
        guard let feedText = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let feedURL = URL(string: feedText),
              feedURL.scheme == "https",
              feedURL.host == "github.com",
              feedURL.path == "/xixi131/MemoryFlow/releases/latest/download/appcast.xml",
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: publicKey)?.count == 32 else {
            throw SettingsAndMenuProbeError.failed("Bundled Sparkle feed URL or EdDSA public key is not production-ready")
        }
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
                widthConstraints: IslandLoginRequiredLayout.loginConstraints(for: attachment)
            )
            let hoverBodyWidth = attachment.notchAlignedBodyWidth(for: .hoverCollapsed)
                ?? (IslandVisualTokens.compactPreviewWidth * attachment.horizontalVisualScale)
            let hoverResult = IslandWindowSizingEngine.resolve(
                state: .hoverCollapsed,
                attachmentMetrics: attachment,
                widthConstraints: IslandWidthConstraints(
                    baseBodyWidth: hoverBodyWidth,
                    maximumVisibleWidth: attachment.availableTopWidth,
                    contentWidthRequirement: .none
                )
            )
            let expectedHeight = IslandVisualTokens.compact.height * attachment.visualScale * 2
            guard result.visibleFrame.width == hoverResult.visibleFrame.width,
                  result.visibleFrame.height == expectedHeight,
                  result.visibleFrame.midX == attachment.centerX,
                  result.visibleFrame.maxY == attachment.topBandFrame.maxY,
                  attachment.expandedContentTopInset >= attachment.notchFrame!.height else {
                throw SettingsAndMenuProbeError.failed("Login Required width preservation or notch anchor failed at width \(availableWidth): hover=\(hoverResult.visibleFrame), login=\(result.visibleFrame), center=\(attachment.centerX), top=\(attachment.topBandFrame.maxY)")
            }
        }
    }

    private static func validateUpdatePromptPresentation() throws {
        let prompt = IslandUpdatePrompt(version: "1.0.1", build: "101")
        let updateShadowOutsets = IslandVisualTokens.shadow.outsets(for: .updatePrompt, visualScale: 1)
        let loginShadowOutsets = IslandVisualTokens.shadow.outsets(for: .loginRequired, visualScale: 1)
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
        let tapped = IslandPresentationReducer.reduce(
            current: opened.state,
            intent: .tap
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
        let laterAfterMusic = IslandPresentationReducer.reduce(
            current: music.state,
            intent: .updatePromptLaterRequested
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
              tapped.reason == .intentIgnored,
              tapped.derivedState.visualState == .updatePrompt,
              later.derivedState.visualState == .compactCollapsed,
              later.state.presentationState == .collapsed,
              later.state.isLoginRequiredPresented == false,
              music.derivedState.visualState == .updatePrompt,
              musicReturn.derivedState.visualState == .updatePrompt,
              laterAfterMusic.derivedState.visualState == .activityCollapsed,
              laterToMusic.derivedState.visualState == .activityCollapsed,
              IslandTransitionKind.resolve(
                previous: opened.derivedState,
                next: later.derivedState,
                reason: later.reason
              ) == .expandedToCompact,
              IslandTransitionKind.resolve(
                previous: promptOverMusic.derivedState,
                next: laterToMusic.derivedState,
                reason: laterToMusic.reason
              ) == .expandedToActivity,
              IslandVisualState.updatePrompt.tokenSet == .compactExpanded,
              IslandUpdatePromptLayout.updateColorHex == "#0A84FF",
              IslandUpdatePromptLayout.laterColorHex == "#636366",
              IslandUpdatePromptLayout.actionWidth == 66,
              IslandUpdatePromptLayout.actionHeight == 22,
              IslandUpdatePromptLayout.actionFontSize == 12,
              IslandUpdatePromptLayout.actionSpacing == 8,
              updateShadowOutsets.horizontal == loginShadowOutsets.horizontal,
              updateShadowOutsets.bottom == loginShadowOutsets.bottom,
              IslandVisualTokens.shadow.appearance(for: .updatePrompt, visualScale: 1)
                == IslandVisualTokens.shadow.appearance(for: .loginRequired, visualScale: 1),
              String(
                  format: AppCopy.text(.versionAvailable, language: .simplifiedChinese),
                  prompt.version,
                  prompt.build
              ).contains(prompt.build),
              AppCopy.text(.update, language: .simplifiedChinese) == "更新",
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
                widthConstraints: IslandLoginRequiredLayout.loginConstraints(for: attachment)
            )
            let loginResult = IslandWindowSizingEngine.resolve(
                state: .loginRequired,
                attachmentMetrics: attachment,
                widthConstraints: IslandLoginRequiredLayout.loginConstraints(for: attachment)
            )
            let actionsWidth = IslandUpdatePromptLayout.actionWidth * 2 + IslandUpdatePromptLayout.actionSpacing
            guard result.visibleFrame == loginResult.visibleFrame,
                  result.visibleFrame.midX == attachment.centerX,
                  result.visibleFrame.maxY == attachment.topBandFrame.maxY,
                  attachment.expandedContentTopInset >= attachment.notchFrame!.height,
                  actionsWidth < result.visibleFrame.width else {
                throw SettingsAndMenuProbeError.failed("Update prompt login-shape reuse, notch, or hit regions failed at width \(availableWidth)")
            }
        }
    }

    private static func validateUpdateDownloadPresentation() throws {
        let prompt = IslandUpdatePrompt(version: "1.0.1", build: "101")
        let login = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .loginRequiredRequested
        )
        let prompted = IslandPresentationReducer.reduce(
            current: login.state,
            intent: .updatePromptAvailable(prompt)
        )
        let requested = IslandPresentationReducer.reduce(
            current: prompted.state,
            intent: .updatePromptUpdateRequested
        )
        let started = IslandPresentationReducer.reduce(
            current: requested.state,
            intent: .updateDownloadStarted(.indeterminate)
        )
        let progress = UpdateDownloadProgress(receivedBytes: 42, totalBytes: 100)
        let progressed = IslandPresentationReducer.reduce(
            current: started.state,
            intent: .updateDownloadProgressed(progress)
        )
        let repeated = IslandPresentationReducer.reduce(
            current: progressed.state,
            intent: .updateDownloadProgressed(progress)
        )
        let ended = IslandPresentationReducer.reduce(
            current: progressed.state,
            intent: .updateDownloadEnded
        )

        let promptedMusic = IslandPresentationReducer.reduce(
            current: .expandedMusic,
            intent: .updatePromptAvailable(prompt)
        )
        let requestedMusic = IslandPresentationReducer.reduce(
            current: promptedMusic.state,
            intent: .updatePromptUpdateRequested
        )
        let downloadingMusic = IslandPresentationReducer.reduce(
            current: requestedMusic.state,
            intent: .updateDownloadStarted(progress)
        )
        let restoredMusic = IslandPresentationReducer.reduce(
            current: downloadingMusic.state,
            intent: .updateDownloadEnded
        )

        guard requested.derivedState.visualState == .compactCollapsed,
              started.derivedState.visualState == .activityCollapsed,
              started.derivedState.previewContent.kind == .updateDownloadActivity,
              started.derivedState.previewContent.badge == "--%",
              progressed.derivedState.previewContent.badge == "42%",
              repeated.reason == .noChange,
              ended.derivedState.visualState == .compactCollapsed,
              downloadingMusic.derivedState.visualState == .activityCollapsed,
              restoredMusic.derivedState.visualState == .activityCollapsed,
              IslandUpdateDownloadLayout.indicatorColorHex == "#0A84FF",
              IslandUpdateDownloadLayout.indicatorSize >= 20,
              IslandUpdateDownloadLayout.percentageWidth >= 40,
              IslandUpdateDownloadLayout.percentageFontSize == 10,
              IslandUpdateDownloadLayout.rotationDuration == 1.5,
              IslandMotionTokens.reduceMotionDuration < IslandMotionTokens.profile(for: .expandedToActivity).shellKeyframes.duration else {
            throw SettingsAndMenuProbeError.failed("Update download priority, content, progress, motion, or restoration failed")
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
                state: .activityCollapsed,
                attachmentMetrics: attachment,
                widthConstraints: progressed.derivedState.widthConstraints
            )
            let frames = IslandActivityNotchClearContentFrames.resolve(
                visibleSize: result.visibleFrame.size,
                contentWidthRequirement: progressed.derivedState.contentWidthRequirement
            )
            guard frames.leadingContentFrame.maxX < frames.trailingContentFrame.minX,
                  frames.leadingContentFrame.width >= IslandUpdateDownloadLayout.indicatorSize,
                  frames.trailingContentFrame.width >= IslandActivityContentWidthProfile.contentSlotWidth,
                  result.visibleFrame.midX == attachment.centerX else {
                throw SettingsAndMenuProbeError.failed("Update download notch or activity layout failed at width \(availableWidth)")
            }
        }
    }
}

private final class ProbeTarget: NSObject {
    @objc func action(_ sender: Any?) {}
}
