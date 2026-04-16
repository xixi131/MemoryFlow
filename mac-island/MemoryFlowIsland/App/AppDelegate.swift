import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sceneCoordinator: SceneCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        sceneCoordinator = SceneCoordinator()
        sceneCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sceneCoordinator?.stop()
    }
}
