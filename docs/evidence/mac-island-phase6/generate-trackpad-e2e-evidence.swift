import Foundation

@main
struct GenerateIslandPhase6TrackpadEvidence {
    static func main() throws {
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evidence/mac-island-phase6/trackpad-e2e-fallback.json")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        let rows = try IslandTrackpadMotionE2EProbe.run()
        let document = TrackpadEvidenceDocument(
            verificationMode: "Swift fallback probe; no physical GUI trackpad capture was available in this environment.",
            hostPath: "IslandInteractionHostingView.scrollWheel -> IslandWindowController.handleScrollWheel -> IslandTrackpadWheelAdapter -> reducer -> IslandMotionEngine; the host supplies the matching motion-driver transition ID.",
            realDeviceCaptureStatus: "Pending manual capture on a Mac trackpad. The fallback does not claim physical gesture delivery or hover-focus observation.",
            constants: .init(threshold: 70, resetMilliseconds: 160, cooldownMilliseconds: 320),
            rows: rows
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: output)
    }
}

private struct TrackpadEvidenceDocument: Codable {
    struct Constants: Codable { let threshold: Int; let resetMilliseconds: Int; let cooldownMilliseconds: Int }
    let verificationMode: String
    let hostPath: String
    let realDeviceCaptureStatus: String
    let constants: Constants
    let rows: [IslandTrackpadMotionE2ERow]
}
