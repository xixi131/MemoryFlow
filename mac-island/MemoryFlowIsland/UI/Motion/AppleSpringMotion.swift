import SwiftUI

enum AppleSpringMotion {
    static let animation = Animation.spring(
        response: 0.35,
        dampingFraction: 0.70,
        blendDuration: 0
    )
}

private struct AppleSpringModifier<Value: Equatable>: ViewModifier {
    let value: Value

    func body(content: Content) -> some View {
        content.animation(AppleSpringMotion.animation, value: value)
    }
}

extension View {
    /// Attach once to the outer island shell so its descendants share one physical transform.
    /// SwiftUI retargets the same spring transaction when `value` changes in flight, carrying
    /// the current velocity into the new destination instead of restarting from rest.
    func applyAppleSpring<Value: Equatable>(value: Value) -> some View {
        modifier(AppleSpringModifier(value: value))
    }
}
