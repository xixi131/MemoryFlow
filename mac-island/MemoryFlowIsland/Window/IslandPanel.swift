import AppKit

enum IslandShellSizePreset {
    case compactPlaceholder
    case expandedPlaceholder

    var frameSize: NSSize {
        switch self {
        case .compactPlaceholder:
            return NSSize(width: 360, height: 96)
        case .expandedPlaceholder:
            return NSSize(width: 460, height: 320)
        }
    }
}

final class IslandPanel: NSPanel {
    private(set) var shellSizePreset: IslandShellSizePreset

    init(shellSizePreset: IslandShellSizePreset = .compactPlaceholder) {
        self.shellSizePreset = shellSizePreset
        super.init(
            contentRect: NSRect(origin: .zero, size: shellSizePreset.frameSize),
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
    }
}
