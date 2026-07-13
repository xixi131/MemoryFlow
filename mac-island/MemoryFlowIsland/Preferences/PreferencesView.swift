import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var languageSettings: AppLanguageSettings
    @ObservedObject private var advancedFeaturesSettings: AdvancedFeaturesSettings
    @ObservedObject private var accountState: SettingsAccountState
    @ObservedObject private var updateCoordinator: UpdateCoordinator
    private let onLoginRequested: () -> Void
    private let onLogoutRequested: () -> Void

    init(
        languageSettings: AppLanguageSettings,
        advancedFeaturesSettings: AdvancedFeaturesSettings,
        accountState: SettingsAccountState,
        updateCoordinator: UpdateCoordinator,
        onLoginRequested: @escaping () -> Void,
        onLogoutRequested: @escaping () -> Void
    ) {
        self.languageSettings = languageSettings
        self.advancedFeaturesSettings = advancedFeaturesSettings
        self.accountState = accountState
        self.updateCoordinator = updateCoordinator
        self.onLoginRequested = onLoginRequested
        self.onLogoutRequested = onLogoutRequested
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(copy(.settingsWindowTitle))
                .font(.title2.weight(.semibold))

            GroupBox(copy(.language)) {
                VStack(alignment: .leading, spacing: 12) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            GroupBox(copy(.advancedFeatures)) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy(.advancedFeaturesDescription))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle(copy(.advancedFeatures), isOn: advancedFeaturesBinding)

                    if advancedFeaturesSettings.isEnabled {
                        Divider()
                        if let user = accountState.user {
                            Text(copy(.signedInAs))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(user.nickname?.isEmpty == false ? user.nickname! : user.email)
                                .font(.headline)
                            if user.nickname?.isEmpty == false {
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Button(copy(.signOut), role: .destructive, action: onLogoutRequested)
                        } else {
                            Text(copy(.notSignedIn))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(copy(.signIn), action: onLoginRequested)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            GroupBox("Updates") {
                HStack {
                    Text(updateStatus)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check for Updates") { _ = updateCoordinator.checkForUpdates() }
                        .disabled(updateCoordinator.state == .checking)
                }.padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 300, alignment: .topLeading)
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
        case .idle: return "Up to date"
        case .checking: return "Checking..."
        case .available(let release): return "Version \(release.version) available"
        case .failed: return "Check failed. Try again."
        default: return "Update in progress"
        }
    }
}
