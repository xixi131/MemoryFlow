import Foundation

enum IslandSizingMatrixProbeError: Error, CustomStringConvertible {
    case invalidAnimatedAnchor

    var description: String {
        switch self {
        case .invalidAnimatedAnchor:
            return "An animated sizing sample detached from its top-center anchor or escaped its interactive panel bounds."
        }
    }
}
