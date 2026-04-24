import AppKit

enum IslandShellSizePreset {
    case compactPlaceholder
    case expandedPlaceholder

    var visibleShellSize: NSSize {
        switch self {
        case .compactPlaceholder:
            return NSSize(width: 360, height: 96)
        case .expandedPlaceholder:
            return NSSize(width: 460, height: 320)
        }
    }

    var panelFrameSize: NSSize {
        let inset = IslandPanel.shellShadowMargin * 2
        return NSSize(
            width: visibleShellSize.width + inset,
            height: visibleShellSize.height + inset
        )
    }
}

final class IslandPanel: NSPanel {
    static let shellShadowMargin: CGFloat = 12

    private(set) var shellSizePreset: IslandShellSizePreset

    var isClickThroughEnabled: Bool {
        ignoresMouseEvents
    }

    var visibleShellSize: NSSize {
        shellSizePreset.visibleShellSize
    }

    var hoverHotspotFrame: CGRect {
        CGRect(
            x: frame.minX + Self.shellShadowMargin,
            y: frame.minY + Self.shellShadowMargin,
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
    }

    func setClickThroughEnabled(_ isEnabled: Bool) {
        guard ignoresMouseEvents != isEnabled else { return }
        ignoresMouseEvents = isEnabled
    }

    func activateInteractiveHoverMode() {
        setClickThroughEnabled(false)
    }

    func panelFrame(forVisibleShellFrame visibleShellFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleShellFrame.minX - Self.shellShadowMargin,
            y: visibleShellFrame.minY - Self.shellShadowMargin,
            width: visibleShellFrame.width + (Self.shellShadowMargin * 2),
            height: visibleShellFrame.height + (Self.shellShadowMargin * 2)
        )
    }

    private func configureAppearance() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        isMovable = false
        isMovableByWindowBackground = false
        isExcludedFromWindowsMenu = true
        ignoresMouseEvents = false
    }
}
