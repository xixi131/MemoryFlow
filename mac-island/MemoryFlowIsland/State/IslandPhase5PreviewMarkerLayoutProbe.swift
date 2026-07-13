import AppKit
import CoreGraphics
import Foundation

enum IslandPhase5PreviewMarkerLayoutProbe {
    static func rows() -> [IslandPhase5PreviewMarkerLayoutProbeRow] {
        let screenMetrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            notchFrame: CGRect(x: 651, y: 950, width: 210, height: 32),
            backingScaleFactor: 2,
            displayIdentity: ScreenMetrics.DisplayIdentity(displayID: 1)
        )
        let layoutEngine = NotchLayoutEngine()
        let attachmentMetrics = layoutEngine.topAttachmentMetrics(for: screenMetrics)
        let scenarioIDs = [
            "logged-out-compact",
            "logged-in-review-compact",
            "logged-in-todo-compact",
            "greeting-compact",
            "review-activity",
            "todo-activity",
            "music-activity",
            "reminder-due",
            "gesture-lock"
        ]

        return scenarioIDs.compactMap { scenarioID in
            let state = state(for: scenarioID)
            let derivedState = IslandDerivedState.derive(from: state)
            let layoutInput = IslandPreviewLayoutInput(
                visualState: derivedState.visualState,
                widthConstraints: derivedState.widthConstraints,
                previewMarker: derivedState.previewMarker,
                previewContent: derivedState.previewContent
            )
            let sizingResult = IslandWindowSizingEngine.resolve(
                state: layoutInput.visualState,
                attachmentMetrics: attachmentMetrics,
                widthConstraints: layoutInput.widthConstraints
            )

            return IslandPhase5PreviewMarkerLayoutProbeRow(
                scenarioID: scenarioID,
                markerGlyph: derivedState.previewMarker.glyph,
                markerTone: derivedState.previewMarker.tone.rawValue,
                visualState: derivedState.visualState.rawValue,
                contentWidthBranch: derivedState.contentWidthBranch.rawValue,
                contentExtensionWidth: scalar(
                    derivedState.contentWidthRequirement.requiredExtensionWidth
                ),
                layoutInputContentExtensionWidth: scalar(
                    layoutInput.widthConstraints.contentWidthRequirement.requiredExtensionWidth
                ),
                sizingContentExtensionWidth: scalar(
                    sizingResult.diagnostics.contentWidthRequirement.requiredExtensionWidth
                ),
                markerContentExtensionWidth: scalar(
                    derivedState.previewMarker.contentWidthRequirement.requiredExtensionWidth
                ),
                visibleFrameWidth: scalar(sizingResult.visibleFrame.width),
                visibleFrameCenterX: scalar(sizingResult.visibleFrame.midX),
                notchCenterX: scalar(attachmentMetrics.centerX),
                visibleFrameMaxY: scalar(sizingResult.visibleFrame.maxY),
                displayMaxY: scalar(screenMetrics.frame.maxY)
            )
        }
    }

    private static func state(for scenarioID: String) -> IslandDomainState {
        if scenarioID == "gesture-lock" {
            var state = IslandDomainState.loggedInReviewActivityPlain
            state.gestureState = .cooldown
            return state
        }

        if scenarioID == "greeting-compact" {
            var state = IslandDomainState.loggedInReviewCompact
            state.isGreetingActive = true
            state.greetingText = "Good evening"
            return state
        }

        return IslandMockScenario.scenario(id: scenarioID)?.initialState
            ?? .loggedInReviewCompact
    }

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }
}
