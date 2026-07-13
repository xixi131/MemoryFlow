import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sceneCoordinator: SceneCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let fixturePath = ProcessInfo.processInfo.environment["MEMORYFLOW_UPDATE_PROBE_FIXTURES"] {
            Task { @MainActor in
                do {
                    print(try await UpdateCoordinatorProbe.run(fixtures: URL(fileURLWithPath: fixturePath)))
                    NSApp.terminate(nil)
                } catch {
                    fputs("update-coordinator-probe: FAIL; \(error)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
            return
        }
        if ProcessInfo.processInfo.environment["MEMORYFLOW_SETTINGS_MENU_PROBE"] == "1" {
            do {
                print(try SettingsAndMenuProbe.run())
                NSApp.terminate(nil)
            } catch {
                fputs("settings-menu-probe: FAIL; \(error)\n", stderr)
                exit(EXIT_FAILURE)
            }
            return
        }
        sceneCoordinator = SceneCoordinator()
        sceneCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sceneCoordinator?.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            sceneCoordinator?.handleIncomingURL(url)
        }
    }
}
