import AppKit

struct NotchLayoutEngine {
    var topMargin: CGFloat = 10

    func islandOrigin(screenFrame: CGRect, islandSize: CGSize) -> CGPoint {
        let x = screenFrame.midX - (islandSize.width / 2)
        let y = screenFrame.maxY - islandSize.height - topMargin
        return CGPoint(x: x, y: y)
    }

    func islandFrame(screenFrame: CGRect, islandSize: CGSize) -> CGRect {
        CGRect(origin: islandOrigin(screenFrame: screenFrame, islandSize: islandSize), size: islandSize)
    }
}
