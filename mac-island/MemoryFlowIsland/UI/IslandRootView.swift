import SwiftUI

struct IslandRootView: View {
    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.92))

            Text("MEMORYFLOW_ISLAND_PLACEHOLDER")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .padding(IslandPanel.shellShadowMargin)
        .background(Color.clear)
    }
}
