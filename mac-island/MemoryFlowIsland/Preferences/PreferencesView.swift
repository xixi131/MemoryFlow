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

                        Picker(copy(.language), selection: languageBinding) {
                            Text(copy(.english)).tag(AppLanguage.english)
                            Text(copy(.simplifiedChinese)).tag(AppLanguage.simplifiedChinese)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
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
                                } else {
                                    Button(copy(.signIn), action: onLoginRequested)
                                        .buttonStyle(.borderedProminent)
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
