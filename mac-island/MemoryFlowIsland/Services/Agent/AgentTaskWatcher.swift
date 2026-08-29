import AppKit
import CoreImage
import Foundation
import SQLite3

/// A provider-neutral event delivered to the island. Future local agents only
/// need another watcher that emits this value; island presentation stays shared.
struct ExternalAgentEvent: Equatable {
    enum Source: String, Codable, Equatable {
        case toonFlow
        case claudeCode
        case codex

        var islandTitle: String {
            switch self {
            case .toonFlow: return "ToonFlow"
            case .claudeCode: return "Claude Code"
            case .codex: return "ChatGPT"
            }
        }

        var fallbackSymbolName: String {
            switch self {
            case .toonFlow: return "sparkles"
            case .claudeCode: return "sparkle"
            case .codex: return "circle.hexagongrid.fill"
            }
        }

        var applicationPaths: [String] {
            switch self {
            case .toonFlow: return ["/Applications/ToonFlow.app"]
            case .claudeCode: return ["/Applications/Claude.app"]
            case .codex: return ["/Applications/ChatGPT.app"]
            }
        }

        var runningApplication: NSRunningApplication? {
            NSWorkspace.shared.runningApplications.first {
                $0.localizedName?.caseInsensitiveCompare(islandTitle) == .orderedSame
            }
        }

        var applicationIcon: NSImage? {
            if self == .codex, let chatGPTLogo = Self.chatGPTLogo {
                return chatGPTLogo
            }
            if let runningApplication {
                return runningApplication.icon
            }
            guard let applicationPath = applicationPaths.first(where: {
                FileManager.default.fileExists(atPath: $0)
            }) else {
                return nil
            }
            return NSWorkspace.shared.icon(forFile: applicationPath)
        }

        // ChatGPT ships a full macOS app icon with a white rounded-square
        // background. Invert then convert luminance to alpha to retain only
        // its knot mark as a white, transparent-background island logo.
        private static let chatGPTLogo: NSImage? = {
            let url = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/icon-chatgpt.png")
            guard let source = CIImage(contentsOf: url) else { return nil }
            let inverted = source.applyingFilter("CIColorInvert")
            let transparentLogo = inverted.applyingFilter("CILuminanceToAlpha")
            let context = CIContext(options: nil)
            guard let image = context.createCGImage(transparentLogo, from: transparentLogo.extent) else {
                return nil
            }
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }()
    }

    let source: Source
    let title: String
    let detail: String
}

protocol ExternalAgentWatching: AnyObject {
    var onEvent: ((ExternalAgentEvent) -> Void)? { get set }
    func start()
    func stop()
}

private struct ToonFlowWatcherState: Codable {
    var memoryCreateTime: Int64
    var taskStartTime: Int64
    var processedMemoryKeys: [String]
    var processedTaskKeys: [String]

    static let empty = ToonFlowWatcherState(
        memoryCreateTime: 0,
        taskStartTime: 0,
        processedMemoryKeys: [],
        processedTaskKeys: []
    )
}

/// Polls ToonFlow's local SQLite database strictly read-only. The watcher never
/// opens ToonFlow, touches its package, or writes to its database.
final class ToonFlowDatabaseWatcher: ExternalAgentWatching {
    var onEvent: ((ExternalAgentEvent) -> Void)?

    private let databaseURL: URL
    private let stateURL: URL
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var state: ToonFlowWatcherState?
    private var isPolling = false

    init(
        databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/toonflow/data/db2.sqlite"),
        stateURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".toonflow-watcher-state.json"),
        pollInterval: TimeInterval = 2
    ) {
        self.databaseURL = databaseURL
        self.stateURL = stateURL
        self.pollInterval = pollInterval
    }

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard isPolling == false, FileManager.default.fileExists(atPath: databaseURL.path) else { return }
        isPolling = true
        defer { isPolling = false }

        do {
            let connection = try ReadOnlySQLiteConnection(url: databaseURL)
            defer { connection.close() }

            if state == nil {
                if let savedState = loadState() {
                    state = savedState
                } else {
                    state = try initialState(using: connection)
                }
                saveState()
                return
            }
            guard var state else { return }

            let memoryEvents = try readMemoryEvents(using: connection, state: &state)
            let taskEvents = try readTaskEvents(using: connection, state: &state)
            self.state = state
            saveState()
            (memoryEvents + taskEvents).forEach { onEvent?($0) }
        } catch {
            // ToonFlow can briefly hold a write transaction. The next 2s pass retries.
            NSLog("[ToonFlowWatcher] read-only poll failed: %@", String(describing: error))
        }
    }

    private func initialState(using connection: ReadOnlySQLiteConnection) throws -> ToonFlowWatcherState {
        let memoryCreateTime = try connection.int64("SELECT COALESCE(MAX(createTime), 0) FROM memories")
        let handledMemoryKeys = try connection.rows(
            "SELECT id, createTime FROM memories WHERE createTime = ?",
            bind: { sqlite3_bind_int64($0, 1, memoryCreateTime) }
        ).compactMap { row -> String? in
            guard let id = row.text(0) else { return nil }
            return "\(row.int64(1)):\(id)"
        }
        let handledTaskKeys = try connection.rows(
            "SELECT id, startTime, state FROM o_tasks"
        ).compactMap { row -> String? in
            guard isTerminalTaskState(row.text(2)) else { return nil }
            return "\(row.int64(1)):\(row.int64(0))"
        }
        return ToonFlowWatcherState(
            memoryCreateTime: memoryCreateTime,
            taskStartTime: try connection.int64("SELECT COALESCE(MAX(startTime), 0) FROM o_tasks"),
            processedMemoryKeys: handledMemoryKeys,
            processedTaskKeys: handledTaskKeys
        )
    }

    private func readMemoryEvents(
        using connection: ReadOnlySQLiteConnection,
        state: inout ToonFlowWatcherState
    ) throws -> [ExternalAgentEvent] {
        let cursor = state.memoryCreateTime
        let rows = try connection.rows(
            """
            SELECT m.id, m.isolationKey, m.role, m.createTime, COALESCE(p.name, '')
            FROM memories m
            LEFT JOIN o_project p ON CAST(p.id AS TEXT) = substr(m.isolationKey, 1, instr(m.isolationKey, ':') - 1)
            WHERE m.createTime >= ?
              AND (m.isolationKey LIKE '%:scriptAgent' OR m.isolationKey LIKE '%:productionAgent')
            ORDER BY m.createTime ASC, m.id ASC
            """,
            bind: { sqlite3_bind_int64($0, 1, cursor) }
        )
        var events: [ExternalAgentEvent] = []
        var seen = Set(state.processedMemoryKeys)
        for row in rows {
            guard let id = row.text(0), let role = row.text(2) else { continue }
            let createTime = row.int64(3)
            let key = "\(createTime):\(id)"
            defer {
                state.memoryCreateTime = max(state.memoryCreateTime, createTime)
                seen.insert(key)
            }
            guard seen.contains(key) == false else { continue }
            guard role == "assistant:decision" || (notifySubtasks && isSubtaskRole(role)) else { continue }

            let projectName = row.text(4).flatMap { $0.isEmpty ? nil : $0 } ?? "ToonFlow"
            let agentName = row.text(1)?.hasSuffix(":productionAgent") == true ? "生产 Agent" : "剧本 Agent"
            let suffix = role == "assistant:decision" ? "已完成" : "子任务已完成"
            events.append(
                ExternalAgentEvent(
                    source: .toonFlow,
                    title: "《\(projectName)》\(agentName)\(suffix)",
                    detail: role
                )
            )
        }
        state.processedMemoryKeys = Array(seen.suffix(500))
        return events
    }

    private func readTaskEvents(
        using connection: ReadOnlySQLiteConnection,
        state: inout ToonFlowWatcherState
    ) throws -> [ExternalAgentEvent] {
        let rows = try connection.rows(
            """
            SELECT t.id, t.projectId, t.taskClass, t.state, t.describe, t.reason, t.startTime, COALESCE(p.name, '')
            FROM o_tasks t
            LEFT JOIN o_project p ON p.id = t.projectId
            ORDER BY t.startTime ASC, t.id ASC
            """,
            bind: nil
        )
        var events: [ExternalAgentEvent] = []
        var seen = Set(state.processedTaskKeys)
        for row in rows {
            let id = row.int64(0)
            let startTime = row.int64(6)
            let key = "\(startTime):\(id)"
            state.taskStartTime = max(state.taskStartTime, startTime)
            guard seen.contains(key) == false, let rawState = row.text(3) else { continue }
            let normalized = rawState.lowercased()
            let isFailure = isFailureTaskState(normalized)
            let isSuccess = isSuccessfulTaskState(normalized)
            guard isFailure || isSuccess else { continue }
            seen.insert(key)

            let projectName = row.text(7).flatMap { $0.isEmpty ? nil : $0 } ?? "ToonFlow"
            let taskClass = row.text(2).flatMap { $0.isEmpty ? nil : $0 } ?? "图片/视频/资产"
            let describe = row.text(4).flatMap { $0.isEmpty ? nil : $0 }
            let reason = row.text(5).flatMap { $0.isEmpty ? nil : $0 }
            let outcome = isFailure ? "任务失败" : "任务已完成"
            events.append(
                ExternalAgentEvent(
                    source: .toonFlow,
                    title: "《\(projectName)》\(taskClass)\(outcome)",
                    detail: isFailure ? (reason ?? "ToonFlow 未提供失败原因") : (describe ?? taskClass)
                )
            )
        }
        state.processedTaskKeys = Array(seen)
        return events
    }

    private func isSubtaskRole(_ role: String) -> Bool {
        role == "assistant:supervision" ||
            role.hasPrefix("assistant:execution:")
    }

    private var notifySubtasks: Bool {
        UserDefaults.standard.bool(forKey: "com.memoryflow.island.toonflow.notifySubtasks")
    }

    private func isTerminalTaskState(_ state: String?) -> Bool {
        guard let state else { return false }
        let normalized = state.lowercased()
        return isSuccessfulTaskState(normalized) || isFailureTaskState(normalized)
    }

    private func isSuccessfulTaskState(_ state: String) -> Bool {
        state.contains("success") || state.contains("complete") || state == "done" || state.contains("finish")
    }

    private func isFailureTaskState(_ state: String) -> Bool {
        state.contains("fail") || state.contains("error")
    }

    private func loadState() -> ToonFlowWatcherState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(ToonFlowWatcherState.self, from: data)
    }

    private func saveState() {
        guard let state, let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }
}

private final class ReadOnlySQLiteConnection {
    private var database: OpaquePointer?

    init(url: URL) throws {
        var database: OpaquePointer?
        let uri = "file:\(url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path)?mode=ro"
        guard sqlite3_open_v2(uri, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            sqlite3_close(database)
            throw SQLiteReadError.open(message)
        }
        self.database = database
    }

    func close() {
        if let database { sqlite3_close(database) }
        database = nil
    }

    func int64(_ sql: String) throws -> Int64 {
        let rows = try rows(sql)
        return rows.first?.int64(0) ?? 0
    }

    func rows(
        _ sql: String,
        bind: ((OpaquePointer?) -> Void)? = nil
    ) throws -> [SQLiteRow] {
        guard let database else { throw SQLiteReadError.closed }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteReadError.query(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        bind?(statement)
        var rows: [SQLiteRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let count = Int(sqlite3_column_count(statement))
            rows.append(SQLiteRow(statement: statement, count: count))
        }
        return rows
    }
}

private struct SQLiteRow {
    private let values: [SQLiteValue]

    init(statement: OpaquePointer?, count: Int) {
        values = (0..<count).map { index in
            guard sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL else { return .null }
            if let text = sqlite3_column_text(statement, Int32(index)) {
                return .text(String(cString: text))
            }
            return .int64(sqlite3_column_int64(statement, Int32(index)))
        }
    }

    func text(_ index: Int) -> String? {
        guard case let .text(value) = values[index] else { return nil }
        return value
    }

    func int64(_ index: Int) -> Int64 {
        switch values[index] {
        case let .int64(value): return value
        case let .text(value): return Int64(value) ?? 0
        case .null: return 0
        }
    }
}

private enum SQLiteValue {
    case text(String)
    case int64(Int64)
    case null
}

private enum SQLiteReadError: Error {
    case open(String)
    case query(String)
    case closed
}

/// Watches the append-only local transcripts used by command-line agents. The
/// first scan records each current file length, preventing old completions from
/// becoming notifications when MemoryFlow Island launches.
final class AgentCompletionLogWatcher: ExternalAgentWatching {
    var onEvent: ((ExternalAgentEvent) -> Void)?

    private enum Provider {
        case claudeCode
        case codex

        var source: ExternalAgentEvent.Source {
            switch self {
            case .claudeCode: return .claudeCode
            case .codex: return .codex
            }
        }

        var rootURL: URL {
            let home = FileManager.default.homeDirectoryForCurrentUser
            switch self {
            case .claudeCode:
                return home.appendingPathComponent(".claude/projects")
            case .codex:
                return home.appendingPathComponent(".codex/sessions")
            }
        }

    }

    private struct FileCursor {
        var offset: UInt64
        var partialLine = Data()
    }

    private let provider: Provider
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var cursors: [URL: FileCursor] = [:]
    private var hasEstablishedBaseline = false
    private var isPolling = false

    private init(provider: Provider, pollInterval: TimeInterval = 2) {
        self.provider = provider
        self.pollInterval = pollInterval
    }

    static func claudeCode() -> AgentCompletionLogWatcher {
        AgentCompletionLogWatcher(provider: .claudeCode)
    }

    static func codex() -> AgentCompletionLogWatcher {
        AgentCompletionLogWatcher(provider: .codex)
    }

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cursors.removeAll()
        hasEstablishedBaseline = false
    }

    private func poll() {
        guard isPolling == false else { return }
        isPolling = true
        defer { isPolling = false }

        let files = completionLogFiles()
        if hasEstablishedBaseline == false {
            cursors = Dictionary(uniqueKeysWithValues: files.compactMap { file in
                guard let size = fileSize(for: file) else { return nil }
                return (file, FileCursor(offset: size))
            })
            hasEstablishedBaseline = true
            return
        }

        let activeFiles = Set(files)
        cursors = cursors.filter { activeFiles.contains($0.key) }
        for file in files {
            readNewLines(from: file)
        }
    }

    private func completionLogFiles() -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: provider.rootURL.path) else { return [] }

        switch provider {
        case .claudeCode:
            guard let projectURLs = try? fileManager.contentsOfDirectory(
                at: provider.rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return projectURLs.flatMap { projectURL -> [URL] in
                guard (try? projectURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                      let files = try? fileManager.contentsOfDirectory(
                        at: projectURL,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                      ) else {
                    return []
                }
                return files.filter { $0.pathExtension == "jsonl" }
            }
        case .codex:
            let calendar = Calendar.current
            return [Date(), calendar.date(byAdding: .day, value: -1, to: Date())]
                .compactMap { $0 }
                .flatMap { date in
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    let dayURL = provider.rootURL
                        .appendingPathComponent(String(format: "%04d", components.year ?? 0))
                        .appendingPathComponent(String(format: "%02d", components.month ?? 0))
                        .appendingPathComponent(String(format: "%02d", components.day ?? 0))
                    return (try? fileManager.contentsOfDirectory(
                        at: dayURL,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    ))?.filter { $0.lastPathComponent.hasPrefix("rollout-") && $0.pathExtension == "jsonl" } ?? []
                }
        }
    }

    private func readNewLines(from file: URL) {
        guard let size = fileSize(for: file) else { return }
        var cursor = cursors[file] ?? FileCursor(offset: size)
        guard size > cursor.offset else {
            if size < cursor.offset {
                // Rotated or truncated logs are treated as a fresh baseline.
                cursor = FileCursor(offset: size)
            }
            cursors[file] = cursor
            return
        }

        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            try handle.seek(toOffset: cursor.offset)
            let appended = try handle.readToEnd() ?? Data()
            cursor.offset = size
            let combined = cursor.partialLine + appended
            let lines = combined.split(separator: 0x0A, omittingEmptySubsequences: false)
            let hasTrailingNewline = combined.last == 0x0A
            let completeLineCount = hasTrailingNewline ? lines.count : max(0, lines.count - 1)
            for line in lines.prefix(completeLineCount) {
                guard let event = parseCompletionEvent(line: Data(line)) else { continue }
                onEvent?(event)
            }
            if hasTrailingNewline {
                cursor.partialLine = Data()
            } else if let trailingLine = lines.last,
                      let event = parseCompletionEvent(line: Data(trailingLine)) {
                // Codex can end a completed turn without writing one more newline.
                // A complete JSON object is safe to emit immediately and must not
                // wait for the user's next prompt to flush the buffer.
                onEvent?(event)
                cursor.partialLine = Data()
            } else {
                cursor.partialLine = Data(lines.last ?? Data())
            }
            cursors[file] = cursor
        } catch {
            NSLog("[%@CompletionWatcher] log read failed: %@", provider.source.islandTitle, String(describing: error))
        }
    }

    private func parseCompletionEvent(line: Data) -> ExternalAgentEvent? {
        Self.completionEvent(from: line, source: provider.source)
    }

    static func completionEvent(
        from line: Data,
        source: ExternalAgentEvent.Source
    ) -> ExternalAgentEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
        let isComplete: Bool
        switch source {
        case .claudeCode:
            let message = object["message"] as? [String: Any]
            isComplete = object["type"] as? String == "assistant"
                && message?["stop_reason"] as? String == "end_turn"
                && object["isSidechain"] as? Bool != true
        case .codex:
            let payload = object["payload"] as? [String: Any]
            isComplete = object["type"] as? String == "event_msg"
                && payload?["type"] as? String == "task_complete"
        case .toonFlow:
            return nil
        }
        guard isComplete else { return nil }
        return ExternalAgentEvent(
            source: source,
            title: "\(source.islandTitle) Agent 已完成",
            detail: "任务已完成"
        )
    }

    private func fileSize(for file: URL) -> UInt64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let number = attributes[.size] as? NSNumber else {
            return nil
        }
        return number.uint64Value
    }
}

enum ExternalAgentApplicationActivator {
    static func activate(_ source: ExternalAgentEvent.Source) {
        if let running = source.runningApplication {
            running.activate(options: [.activateAllWindows])
            return
        }
        guard let applicationPath = source.applicationPaths.first(where: {
            FileManager.default.fileExists(atPath: $0)
        }) else { return }
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: applicationPath),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
    }
}
