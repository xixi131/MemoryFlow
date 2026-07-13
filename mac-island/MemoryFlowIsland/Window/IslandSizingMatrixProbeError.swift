import Foundation

enum IslandSizingMatrixProbeError: Error, CustomStringConvertible {
    case invalidAnimatedAnchor
    case invalidResponsiveLayout

    var description: String {
        switch self {
        case .invalidAnimatedAnchor:
            return "An animated sizing sample detached from its top-center anchor or escaped its interactive panel bounds."
        case .invalidResponsiveLayout:
            return "A responsive content sizing sample exceeded its display width, lost its top-center anchor, or failed to interpolate between content demands."
        }
    }
}
