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
    // 左下/右下角的圆角半径。数值越大，底部两角越“鼓”、越接近大圆弧；数值越小，底部转角越收。
    let radius: CGFloat
    // 左下/右下角和液态连接共用的连续曲率指数。数值越大越接近 Apple 风格的超椭圆顺滑过渡；数值越小越接近普通圆角。
    let smoothness: CGFloat
    // 液态连接横向外扩强度。数值越大，左右连接角向外延伸越宽；数值越小，连接更贴近岛体侧边。
    let earTension: CGFloat
    // 液态连接向下融合高度。数值越大，连接角向下吃进岛体越深、更像展开态的大融合；数值越小，更接近普通 Mac 刘海。
    let earBlendHeight: CGFloat
    let showsStroke: Bool
}

struct IslandHoverBehaviorTokens: Equatable {
    let collapsedWidthScale: CGFloat
    let collapsedHeight: CGFloat
}

struct IslandExpandedContentLayoutTokens: Equatable {
    let horizontalInset: CGFloat
    let bottomInset: CGFloat
    let cornerInset: CGFloat

    func innerCornerRadius(outerCornerRadius: CGFloat) -> CGFloat {
        max(outerCornerRadius - cornerInset, 0)
    }
}

struct IslandActivityContentChoreographyTokens: Equatable {
    let delay: TimeInterval
    let duration: TimeInterval
    let initialBlurRadius: CGFloat
}

struct IslandActivityCollapseContentChoreographyTokens: Equatable {
    let exitDuration: TimeInterval
    let exitBlurRadius: CGFloat
    let compactContentDelay: TimeInterval
}

struct IslandMusicArtworkPresentation: Equatable {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let smoothness: CGFloat

    static func interpolated(
        from source: IslandMusicArtworkPresentation,
        to target: IslandMusicArtworkPresentation,
        progress: CGFloat
    ) -> IslandMusicArtworkPresentation {
        let t = min(max(progress, 0), 1)
        func lerp(_ start: CGFloat, _ end: CGFloat) -> CGFloat { start + ((end - start) * t) }
        return IslandMusicArtworkPresentation(
            width: lerp(source.width, target.width),
            height: lerp(source.height, target.height),
            radius: lerp(source.radius, target.radius),
            smoothness: lerp(source.smoothness, target.smoothness)
        )
    }
}

struct IslandShadowBufferTokens: Equatable {
    let horizontal: CGFloat
    let bottom: CGFloat

    func scaled(by visualScale: CGFloat) -> IslandShadowOutsets {
        IslandShadowOutsets(
            horizontal: horizontal * visualScale,
            bottom: bottom * visualScale
        )
    }
}

struct IslandShadowAppearanceTokens: Equatable {
    let opacity: Double
    let radius: CGFloat
    let offsetY: CGFloat

    func scaled(by visualScale: CGFloat) -> IslandShadowAppearanceTokens {
        IslandShadowAppearanceTokens(
            opacity: opacity,
            radius: radius * visualScale,
            offsetY: offsetY * visualScale
        )
    }

    func interpolated(to target: IslandShadowAppearanceTokens, progress: CGFloat) -> IslandShadowAppearanceTokens {
        let t = min(max(progress, 0), 1)
        func lerp(_ start: CGFloat, _ end: CGFloat) -> CGFloat { start + ((end - start) * t) }
        return IslandShadowAppearanceTokens(
            opacity: Double(lerp(CGFloat(opacity), CGFloat(target.opacity))),
            radius: lerp(radius, target.radius),
            offsetY: lerp(offsetY, target.offsetY)
        )
    }
}

struct IslandShadowBehaviorTokens: Equatable {
    let visibleInHoverCollapsed: Bool
    let visibleInExpanded: Bool
    let hoverBuffer: IslandShadowBufferTokens
    let expandedBuffer: IslandShadowBufferTokens
    let hoverAppearance: IslandShadowAppearanceTokens
    let expandedAppearance: IslandShadowAppearanceTokens

    func outsets(for state: IslandVisualState, visualScale: CGFloat) -> IslandShadowOutsets {
        switch state {
        case .hoverCollapsed, .activityHoverCollapsed:
            return hoverBuffer.scaled(by: visualScale)
        case .expandedMusic, .expandedApp:
            return expandedBuffer.scaled(by: visualScale)
        case .compactCollapsed, .activityCollapsed:
            return .zero
        }
    }

    func appearance(for state: IslandVisualState, visualScale: CGFloat) -> IslandShadowAppearanceTokens {
        switch state {
        case .hoverCollapsed, .activityHoverCollapsed:
            return hoverAppearance.scaled(by: visualScale)
        case .expandedMusic, .expandedApp:
            return expandedAppearance.scaled(by: visualScale)
        case .compactCollapsed, .activityCollapsed:
            return IslandShadowAppearanceTokens(opacity: 0, radius: 0, offsetY: 0)
        }
    }
}

enum IslandVisualTokens {
    // Compact width branches documented in docs/mac-island-visual-token-map.md.
    static let compactPreviewWidth: CGFloat = 200
    static let compactSignedOutWidth: CGFloat = 180
    static let compactGreetingMinWidth: CGFloat = 220
    static let compactGreetingMaxWidth: CGFloat = 300
    // Kept in the Visual module because the production target compiles its
    // content layer independently from the motion-plan support sources.
    static let activityContentEnter = IslandActivityContentChoreographyTokens(
        delay: 0.10,
        duration: 0.26,
        initialBlurRadius: 4
    )
    static let activityCollapseContent = IslandActivityCollapseContentChoreographyTokens(
        exitDuration: 0.15,
        exitBlurRadius: 5,
        compactContentDelay: 0.4675
    )
    static let expandedAppContentEnter = IslandActivityContentChoreographyTokens(
        delay: 0.15,
        duration: 0.26,
        initialBlurRadius: 4
    )
    static let expandedMusicContentEnter = IslandActivityContentChoreographyTokens(
        delay: 0.15,
        duration: 0.26,
        initialBlurRadius: 4
    )
    // Keep the music cover as one matched presentation while the shell expands.
    // Artwork is intentionally taller than wide in both layouts to preserve the
    // source artwork's aspect-fill crop rather than stretching it.
    static let activityMusicArtwork = IslandMusicArtworkPresentation(
        width: 20,
        height: 20,
        radius: 6.4,
        smoothness: 1.92
    )
    static let expandedMusicArtwork = IslandMusicArtworkPresentation(
        width: 72,
        height: 80,
        radius: 16,
        smoothness: 1.85
    )
    static let expandedContentExit = IslandActivityCollapseContentChoreographyTokens(
        exitDuration: 0.15,
        exitBlurRadius: 5,
        compactContentDelay: 0
    )
    // The inner surface follows: outer corner radius = inner corner radius + edge inset.
    static let expandedContentLayout = IslandExpandedContentLayoutTokens(
        horizontalInset: 24,
        bottomInset: 24,
        cornerInset: 10
    )

    // 普通收起态：对应最接近 Mac 刘海的状态。
    // 如果觉得液态连接太小，优先把 earBlendHeight 从 11 往 13-16 调；
    // 如果觉得连接不够向外“融”，再把 earTension 从 0.4 往 0.45-0.55 调。
    // 如果觉得左下/右下角太小，把 radius 从 22 往 24-28 调；想更丝滑，把 smoothness 从 3.5 往 3.8-4.4 调。
    static let compact = IslandShellGeometryTokens(
        previewWidth: compactPreviewWidth,
        height: 36,
        radius: 50,
        smoothness: 3.3,
        earTension: 0.4,
        earBlendHeight: 11,
        showsStroke: false
    )

    // 活动态：例如播放音乐、复习、待办提醒等收起但有内容的状态。
    // 这里通常要比普通态连接更大：earBlendHeight 控制下探深度，earTension 控制横向外扩。
    // 如果活动态还是显小，可先把 earBlendHeight 从 22 往 24-28 调，再把 earTension 从 0.3 往 0.35-0.45 调。
    // 底部角如果不够圆润，把 radius 从 50 往 54-60 调；如果转角曲率不够顺，把 smoothness 从 2.3 往 2.6-3.2 调。
    static let activity = IslandShellGeometryTokens(
        previewWidth: 240,
        height: 36,
        radius: 40,
        smoothness: 2.8,
        earTension: 0.4,
        earBlendHeight: 14,
        showsStroke: false
    )

    // 音乐展开态：大面板状态，液态连接应明显大于收起态。
    // 如果展开后顶部连接还像“折过去”，优先把 earBlendHeight 从 32 往 36-44 调；
    // 如果两侧外扩不够，再把 earTension 从 0.7 往 0.75-0.9 调。
    // 左下/右下角太小就把 radius 从 48 往 54-64 调；想让大角更像超椭圆，把 smoothness 从 3.5 往 3.8-4.5 调。
    static let expandedMusic = IslandShellGeometryTokens(
        previewWidth: 460,
        height: 210,
        radius: 80,
        smoothness: 3.5,
        earTension: 0.7,
        earBlendHeight: 50,
        showsStroke: false
    )

    // 应用展开态：高度更大的完整面板，通常与音乐展开态保持同一组角度和连接手感。
    // 如果只想让大应用面板更柔，可以单独调这里的 radius/smoothness；
    // 如果要保持音乐展开和应用展开一致，就同步修改 expandedMusic 与 expandedApp。
    static let expandedApp = IslandShellGeometryTokens(
        previewWidth: 460,
        height: 320,
        radius: 80,
        smoothness: 3.5,
        earTension: 0.6,
        earBlendHeight: 60,
        showsStroke: false
    )

    static let hover = IslandHoverBehaviorTokens(
        // Hover remains intentionally smaller than the activity shell. Keep width
        // proportional to each compact content branch while growing the full
        // shell in both axes.
        collapsedWidthScale: 1.04,
        collapsedHeight: 38
    )

    static let shadow = IslandShadowBehaviorTokens(
        visibleInHoverCollapsed: true,
        visibleInExpanded: true,
        hoverBuffer: IslandShadowBufferTokens(
            horizontal: 48,
            bottom: 64
        ),
        expandedBuffer: IslandShadowBufferTokens(
            horizontal: 64,
            bottom: 136
        ),
        hoverAppearance: IslandShadowAppearanceTokens(
            opacity: 0.13,
            radius: 22,
            offsetY: 6
        ),
        expandedAppearance: IslandShadowAppearanceTokens(
            opacity: 0.22,
            radius: 34,
            offsetY: 10
        )
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
