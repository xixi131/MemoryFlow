import SwiftUI

enum PreferencesUpdateCommand {
    case check
    case retry
    case update
}

struct PreferencesView: View {
    @ObservedObject private var languageSettings: AppLanguageSettings
    @ObservedObject private var advancedFeaturesSettings: AdvancedFeaturesSettings
    @ObservedObject private var accountState: SettingsAccountState
    @ObservedObject private var updateCoordinator: UpdateCoordinator
    private let onLoginRequested: () -> Void
    private let onLogoutRequested: () -> Void
    private let onUpdateCommand: (PreferencesUpdateCommand) -> Void

    init(
        languageSettings: AppLanguageSettings,
        advancedFeaturesSettings: AdvancedFeaturesSettings,
        accountState: SettingsAccountState,
        updateCoordinator: UpdateCoordinator,
        onLoginRequested: @escaping () -> Void,
        onLogoutRequested: @escaping () -> Void,
        onUpdateCommand: @escaping (PreferencesUpdateCommand) -> Void
    ) {
        self.languageSettings = languageSettings
        self.advancedFeaturesSettings = advancedFeaturesSettings
        self.accountState = accountState
        self.updateCoordinator = updateCoordinator
        self.onLoginRequested = onLoginRequested
        self.onLogoutRequested = onLogoutRequested
        self.onUpdateCommand = onUpdateCommand
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsSection(title: copy(.language), systemImage: "globe") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(copy(.languageDescription))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LiquidGlassSegmentedPicker(
                            selection: languageBinding,
                            options: [
                                .init(value: .english, title: copy(.english)),
                                .init(value: .simplifiedChinese, title: copy(.simplifiedChinese))
                            ]
                        )
                    }
                }

                sectionDivider

                settingsSection(title: copy(.advancedFeatures), systemImage: "sparkles") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 20) {
                            Text(copy(.advancedFeaturesDescription))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 12)

                            Toggle(copy(.advancedFeatures), isOn: advancedFeaturesBinding)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        if advancedFeaturesSettings.isEnabled {
                            Divider()

                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 3) {
                                    if let user = accountState.user {
                                        Text(copy(.signedInAs))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(user.nickname?.isEmpty == false ? user.nickname! : user.email)
                                            .font(.body.weight(.medium))
                                        if user.nickname?.isEmpty == false {
                                            Text(user.email)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(copy(.account))
                                            .font(.body.weight(.medium))
                                        Text(copy(.notSignedIn))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer(minLength: 12)

                                if accountState.user != nil {
                                    Button(copy(.signOut), role: .destructive, action: onLogoutRequested)
                                        .glassActionStyle()
                                } else {
                                    Button(copy(.signIn), action: onLoginRequested)
                                        .glassActionStyle(prominent: true)
                                }
                            }
                        }
                    }
                }

                sectionDivider

                settingsSection(title: copy(.updates), systemImage: "arrow.triangle.2.circlepath") {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(updateStatus)
                                .font(.body.weight(.medium))
                            Text(copy(.updatesDescription))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Button(updateActionTitle) { performUpdateAction() }
                            .disabled(updateActionDisabled)
                            .glassActionStyle()
                    }
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 520, minHeight: 420)
    }

    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
                .padding(.leading, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 24)
            .padding(.leading, 24)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { languageSettings.language },
            set: { languageSettings.setLanguage($0) }
        )
    }

    private var advancedFeaturesBinding: Binding<Bool> {
        Binding(
            get: { advancedFeaturesSettings.isEnabled },
            set: { advancedFeaturesSettings.setEnabled($0) }
        )
    }

    private func copy(_ key: AppCopy.Key) -> String {
        AppCopy.text(key, language: languageSettings.language)
    }

    private var updateStatus: String {
        switch updateCoordinator.state {
        case .idle:
            return String(format: copy(.upToDate), installedVersion, installedBuild)
        case .checking: return copy(.checkingForUpdates)
        case .available(let release), .deferred(let release, _):
            return String(format: copy(.versionAvailable), release.version, release.build)
        case .failed(let failure): return recoveryMessage(failure)
        case .installed(let release, let relaunched):
            return String(format: copy(relaunched ? .installedAndRelaunched : .installed), release.version)
        default: return copy(.updateInProgress)
        }
    }

    private var updateActionTitle: String {
        switch updateCoordinator.state {
        case .available, .deferred:
            return copy(.update)
        case .failed:
            return copy(.retry)
        default:
            return copy(.checkForUpdates)
        }
    }

    private var updateActionDisabled: Bool {
        switch updateCoordinator.state {
        case .checking, .downloadRequested, .downloading, .verifying, .ready,
             .awaitingAuthorization, .installing:
            return true
        case .idle, .available, .deferred, .installed, .failed:
            return false
        }
    }

    private func performUpdateAction() {
        switch updateCoordinator.state {
        case .available, .deferred:
            onUpdateCommand(.update)
        case .failed:
            onUpdateCommand(.retry)
        default:
            onUpdateCommand(.check)
        }
    }

    private var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var installedBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private func recoveryMessage(_ failure: UpdateFailure) -> String {
        switch failure {
        case .offline: return copy(.updateOffline)
        case .httpStatus(let status): return String(format: copy(.updateHTTPError), status)
        case .invalidConfiguration, .invalidFeed: return copy(.updateFeedUnavailable)
        case .signatureRejected: return copy(.updateSignatureFailed)
        case .insufficientDisk: return copy(.updateInsufficientDisk)
        case .authorizationCancelled: return copy(.updateAuthorizationCancelled)
        case .transport, .engine: return copy(.updateFailed)
        }
    }
}

// MARK: - Liquid Glass controls

/// 胶囊形分段切换：可拖动的液态玻璃滑块，按住/拖动时放大溢出并显现玻璃质感，
/// 松手弹簧吸附到最近的选项。玻璃材质用官方 `.glassEffect` API；macOS 26 以下回退到原生 segmented picker。
struct LiquidGlassSegmentedPicker: View {
    struct Option {
        let value: AppLanguage
        let title: String
    }

    @Binding var selection: AppLanguage
    let options: [Option]
    var accent: Color = .accentColor

    private let width: CGFloat = 220
    private let height: CGFloat = 34

    @State private var dragX: CGFloat? = nil
    @GestureState private var pressing = false

    private var selectedIndex: Int {
        options.firstIndex { $0.value == selection } ?? 0
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            glassPicker
        } else {
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { Text($0.title).tag($0.value) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: width)
        }
    }

    @available(macOS 26.0, *)
    private var glassPicker: some View {
        let count = max(options.count, 1)
        let segWidth = width / CGFloat(count)
        let thumbX = dragX ?? CGFloat(selectedIndex) * segWidth

        // 整个控件统一接收手势：滑块中心跟随手指，点击/拖动都在此处理。
        let drag = DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                let center = min(max(value.location.x, segWidth / 2), width - segWidth / 2)
                dragX = center - segWidth / 2
            }
            .onEnded { value in
                let index = min(max(Int(value.location.x / segWidth), 0), options.count - 1)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                    selection = options[index].value
                    dragX = nil
                }
            }

        return ZStack(alignment: .leading) {
            // 轨道
            Capsule()
                .fill(Color.primary.opacity(0.10))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                .frame(width: width, height: height)

            // 滑块：官方液态玻璃，按住放大溢出 + 发光 + 弹簧
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular.tint(accent).interactive(), in: Capsule())
                .frame(width: segWidth, height: height)
                .scaleEffect(pressing ? 1.16 : 1.0)
                .shadow(color: pressing ? accent.opacity(0.55) : .clear,
                        radius: pressing ? 9 : 0)
                .offset(x: thumbX)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressing)
                .allowsHitTesting(false)

            // 文字浮在滑块之上（不拦截手势，统一交给容器）
            HStack(spacing: 0) {
                ForEach(options, id: \.value) { option in
                    Text(option.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(option.value == selection ? Color.white : Color.primary)
                        .frame(width: segWidth, height: height)
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .gesture(drag)
        .animation(.spring(response: 0.35, dampingFraction: 0.68), value: selection)
    }
}

private struct GlassActionButtonStyleModifier: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                content
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
            } else {
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content
        }
    }
}

extension View {
    /// Applies the image-1 Liquid Glass capsule button style on macOS 26+.
    func glassActionStyle(prominent: Bool = false) -> some View {
        modifier(GlassActionButtonStyleModifier(prominent: prominent))
    }
}
