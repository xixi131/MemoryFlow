import AppKit

enum IslandShellSizePreset {
    case compactPlaceholder
    case expandedPlaceholder

    var visibleShellSize: NSSize {
        switch self {
        case .compactPlaceholder:
            return NSSize(width: 180, height: 36)
        case .expandedPlaceholder:
            return NSSize(width: 460, height: 320)
        }
    }

    var panelFrameSize: NSSize {
        return NSSize(
            width: visibleShellSize.width + (IslandPanel.shellHorizontalShadowMargin * 2),
            height: visibleShellSize.height + IslandPanel.shellBottomShadowMargin
        )
    }
}

final class IslandPanel: NSPanel {
    static let shellHorizontalShadowMargin: CGFloat = 0
    static let shellBottomShadowMargin: CGFloat = 0

    private(set) var shellSizePreset: IslandShellSizePreset
    private var requestedVisibleShellSizeOverride: NSSize?
    private var currentShadowOutsets: IslandShadowOutsets = .zero
    private var renderedVisibleShellSize: NSSize?
    private(set) var currentHitTestFrame: CGRect = .zero

    var isClickThroughEnabled: Bool {
        ignoresMouseEvents
    }

    var visibleShellSize: NSSize {
        renderedVisibleShellSize ?? requestedShellSize
    }

    var requestedShellSize: NSSize {
        requestedVisibleShellSizeOverride ?? shellSizePreset.visibleShellSize
    }

    var hoverHotspotFrame: CGRect {
        CGRect(
            x: frame.minX + currentShadowOutsets.horizontal,
            y: frame.minY + currentShadowOutsets.bottom,
            width: visibleShellSize.width,
            height: visibleShellSize.height
        )
    }

    init(shellSizePreset: IslandShellSizePreset = .compactPlaceholder) {
        self.shellSizePreset = shellSizePreset
        super.init(
            contentRect: NSRect(origin: .zero, size: shellSizePreset.panelFrameSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    func setShellSizePreset(_ shellSizePreset: IslandShellSizePreset) {
        self.shellSizePreset = shellSizePreset
        requestedVisibleShellSizeOverride = nil
        currentShadowOutsets = .zero
        renderedVisibleShellSize = nil
    }

    func setRequestedShellLayout(visibleShellSize: NSSize, shadowOutsets: IslandShadowOutsets) {
        requestedVisibleShellSizeOverride = visibleShellSize
        currentShadowOutsets = shadowOutsets
        renderedVisibleShellSize = nil
    }

    func setClickThroughEnabled(_ isEnabled: Bool) {
        guard ignoresMouseEvents != isEnabled else { return }
        ignoresMouseEvents = isEnabled
    }

    func activateInteractiveHoverMode() {
        setClickThroughEnabled(false)
    }

    func panelFrame(forVisibleShellFrame visibleShellFrame: CGRect) -> CGRect {
        renderedVisibleShellSize = visibleShellFrame.size

        return CGRect(
            x: visibleShellFrame.minX - currentShadowOutsets.horizontal,
            y: visibleShellFrame.minY - currentShadowOutsets.bottom,
            width: visibleShellFrame.width + (currentShadowOutsets.horizontal * 2),
            height: visibleShellFrame.height + currentShadowOutsets.bottom
        )
    }

    func applySizingResult(_ sizingResult: IslandWindowSizingResult) -> CGRect {
        setRequestedShellLayout(
            visibleShellSize: sizingResult.visibleSize,
            shadowOutsets: sizingResult.shadowOutsets
        )
        currentHitTestFrame = sizingResult.hitTestFrame
        return panelFrame(forVisibleShellFrame: sizingResult.visibleFrame)
    }

    private func configureAppearance() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        isMovable = false
        isMovableByWindowBackground = false
        isExcludedFromWindowsMenu = true
        ignoresMouseEvents = false
    }
}
