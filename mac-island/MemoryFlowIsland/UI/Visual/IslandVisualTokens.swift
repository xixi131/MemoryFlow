import CoreGraphics
import Foundation

enum IslandVisualTokenSet: String, CaseIterable {
    case compact
    case activity
    case expandedMusic
    case expandedApp
}

struct IslandShellGeometryTokens: Equatable {
    let previewWidth: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let smoothness: CGFloat
    let earTension: CGFloat
    let earBlendHeight: CGFloat
    let showsStroke: Bool
}

struct IslandHoverBehaviorTokens: Equatable {
    let collapsedScale: CGFloat
}

struct IslandShadowBehaviorTokens: Equatable {
    let fadeDuration: TimeInterval
    let visibleInHoverCollapsed: Bool
    let visibleInExpanded: Bool
}

enum IslandVisualTokens {
    // Compact width branches documented in docs/mac-island-visual-token-map.md.
    static let compactPreviewWidth: CGFloat = 160
    static let compactSignedOutWidth: CGFloat = 180
    static let compactGreetingMinWidth: CGFloat = 220
    static let compactGreetingMaxWidth: CGFloat = 300
    static let compactTodoNoActivityWidth: CGFloat = 230

    static let compact = IslandShellGeometryTokens(
        previewWidth: compactPreviewWidth,
        height: 36,
        radius: 22,
        smoothness: 3.5,
        earTension: 0.4,
        earBlendHeight: 11,
        showsStroke: false
    )

    static let activity = IslandShellGeometryTokens(
        previewWidth: 240,
        height: 36,
        radius: 50,
        smoothness: 2.3,
        earTension: 0.3,
        earBlendHeight: 22,
        showsStroke: false
    )

    static let expandedMusic = IslandShellGeometryTokens(
        previewWidth: 460,
        height: 210,
        radius: 48,
        smoothness: 3.5,
        earTension: 0.7,
        earBlendHeight: 32,
        showsStroke: true
    )

    static let expandedApp = IslandShellGeometryTokens(
        previewWidth: 460,
        height: 320,
        radius: 48,
        smoothness: 3.5,
        earTension: 0.7,
        earBlendHeight: 32,
        showsStroke: true
    )

    static let hover = IslandHoverBehaviorTokens(
        collapsedScale: 1.06
    )

    static let shadow = IslandShadowBehaviorTokens(
        fadeDuration: 0.26,
        visibleInHoverCollapsed: true,
        visibleInExpanded: true
    )

    static func shell(for tokenSet: IslandVisualTokenSet) -> IslandShellGeometryTokens {
        switch tokenSet {
        case .compact:
            return compact
        case .activity:
            return activity
        case .expandedMusic:
            return expandedMusic
        case .expandedApp:
            return expandedApp
        }
    }
}
