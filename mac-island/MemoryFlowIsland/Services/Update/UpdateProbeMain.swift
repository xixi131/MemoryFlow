#if UPDATE_PROBE
import Foundation

@main
enum UpdateProbeMain {
    static func main() async throws {
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        print(try await UpdateCoordinatorProbe.run(fixtures: fixtures))
    }
}
#endif
