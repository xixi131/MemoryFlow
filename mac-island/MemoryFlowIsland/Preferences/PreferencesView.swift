import SwiftUI

struct PreferencesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MemoryFlow Preferences")
                .font(.title2.weight(.semibold))

            Text("Preferences controls will be added in later Phase 1 tasks.")
                .font(.body)
                .foregroundStyle(.secondary)

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 10) {
                    preferenceRow(
                        title: "Island visibility",
                        description: "Placeholder for startup and manual show or hide settings."
                    )
                    preferenceRow(
                        title: "Reminders",
                        description: "Placeholder for reminder timing and native alert preferences."
                    )
                    preferenceRow(
                        title: "Music takeover",
                        description: "Placeholder for playback takeover preferences and provider status."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320, alignment: .topLeading)
    }

    private func preferenceRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
