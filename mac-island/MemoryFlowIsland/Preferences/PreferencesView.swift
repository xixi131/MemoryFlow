import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var languageSettings: AppLanguageSettings
    @ObservedObject private var accountState: SettingsAccountState
    private let onLoginRequested: () -> Void
    private let onLogoutRequested: () -> Void

    init(
        languageSettings: AppLanguageSettings,
        accountState: SettingsAccountState,
        onLoginRequested: @escaping () -> Void,
        onLogoutRequested: @escaping () -> Void
    ) {
        self.languageSettings = languageSettings
        self.accountState = accountState
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

            GroupBox(copy(.account)) {
                VStack(alignment: .leading, spacing: 10) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
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

    private func copy(_ key: AppCopy.Key) -> String {
        AppCopy.text(key, language: languageSettings.language)
    }
}
