import AppKit
import Combine
import OSLog

struct MenuBarPresentationState: Equatable {
    var language: AppLanguage = .english
    var isIslandVisible = true
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var menuBarState = MenuBarPresentationState()
    private let callbackLogger = Logger(subsystem: "com.memoryflow.island", category: "LoginCallback")
    private var sceneCoordinator: SceneCoordinator?
    private var pendingIncomingURLs: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        BundleIdentityMigration.run()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["MEMORYFLOW_TODO_LIVE_SYNC_PROBE"] == "1" {
            Task { @MainActor in
                do {
                    print(try await TodoLiveSyncProbe.run())
                    NSApp.terminate(nil)
                } catch {
                    fputs("todo-live-sync-probe: FAIL; \(error)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
            return
        }
        if ProcessInfo.processInfo.environment["MEMORYFLOW_TODO_DETAIL_PROBE"] == "1" {
            do {
                print(try TodoDetailProbe.run())
                NSApp.terminate(nil)
            } catch {
                fputs("todo-detail-probe: FAIL; \(error)\n", stderr)
                exit(EXIT_FAILURE)
            }
            return
        }
        if ProcessInfo.processInfo.environment["MEMORYFLOW_TODO_DATA_FIDELITY_PROBE"] == "1" {
            Task { @MainActor in
                do {
                    let liveSync = try await TodoLiveSyncProbe.run()
                    print("todo-live-sync-probe: PASS; tasks=\(liveSync.taskIDs.count); paths=\(liveSync.paths.joined(separator: ",")); recovered=\(liveSync.recovered)")
                    print(try TodoDataFidelityProbe.run())
                    NSApp.terminate(nil)
                } catch {
                    fputs("todo-data-fidelity-probe: FAIL; \(error)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
            return
        }
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
        sceneCoordinator = SceneCoordinator { [weak self] state in
            self?.menuBarState = state
        }
        sceneCoordinator?.start()
        if #available(macOS 26.0, *) {
            perform(#selector(configureNativeMenuBarExtra), with: nil, afterDelay: 1)
        }
        let pendingURLs = pendingIncomingURLs
        pendingIncomingURLs.removeAll()
        pendingURLs.forEach { sceneCoordinator?.handleIncomingURL($0) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        sceneCoordinator?.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            routeIncomingURL(url, source: "application-open")
        }
    }

    func toggleIslandFromMenuBar() {
        sceneCoordinator?.toggleIslandFromMenuBar()
    }

    func showSettingsFromMenuBar() {
        sceneCoordinator?.showSettingsFromMenuBar()
    }

    func logoutFromMenuBar() {
        sceneCoordinator?.logoutFromMenuBar()
    }

    func quitFromMenuBar() {
        sceneCoordinator?.quitFromMenuBar()
    }

    @objc
    private func configureNativeMenuBarExtra() {
        guard
            let items = NSStatusBar.system.value(forKey: "_statusItems") as? NSPointerArray,
            let item = items.allObjects.last as? NSStatusItem
        else {
            return
        }

        let selector = NSSelectorFromString("_setDropPriority:")
        if item.responds(to: selector), let implementation = item.method(for: selector) {
            typealias SetDropPriority = @convention(c) (AnyObject, Selector, Float) -> Void
            unsafeBitCast(implementation, to: SetDropPriority.self)(item, selector, 1_000)
        }
        item.isVisible = true
    }

    @objc
    private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlText = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlText) else {
            callbackLogger.error("Rejected malformed URL Apple event")
            return
        }
        routeIncomingURL(url, source: "apple-event")
    }

    private func routeIncomingURL(_ url: URL, source: String) {
        callbackLogger.info("Received login callback via \(source, privacy: .public)")
        if let sceneCoordinator {
            sceneCoordinator.handleIncomingURL(url)
        } else {
            pendingIncomingURLs.append(url)
        }
    }
}

private enum BundleIdentityMigration {
    private static let oldBundleID = "com.memoryflow.island"
    private static let marker = "bundleIdentityMigrationV1Completed"
    private static let migratedKeys = [
        "com.memoryflow.island.settings.language",
        "com.memoryflow.island.settings.advancedFeaturesEnabled",
        "SUEnableAutomaticChecks",
        "SUSendProfileInfo"
    ]

    static func run() {
        let current = UserDefaults.standard
        guard current.bool(forKey: marker) == false else { return }

        let oldDomain = current.persistentDomain(forName: oldBundleID) ?? [:]
        for key in migratedKeys where current.object(forKey: key) == nil {
            if let value = oldDomain[key] {
                current.set(value, forKey: key)
            }
        }

        current.set(true, forKey: marker)
    }
}
