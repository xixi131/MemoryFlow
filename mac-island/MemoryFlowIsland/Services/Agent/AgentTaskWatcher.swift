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
    var processedMemoryKeys: [String]

    static let empty = ToonFlowWatcherState(
        memoryCreateTime: 0,
        processedMemoryKeys: []
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
            self.state = state
            saveState()
            memoryEvents.forEach { onEvent?($0) }
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
        return ToonFlowWatcherState(
            memoryCreateTime: memoryCreateTime,
            processedMemoryKeys: handledMemoryKeys
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
              AND instr(m.isolationKey, ':') > 1
            ORDER BY m.createTime ASC, m.id ASC
            """,
            bind: { sqlite3_bind_int64($0, 1, cursor) }
        )
        var events: [ExternalAgentEvent] = []
        var seen = Set(state.processedMemoryKeys)
        for row in rows {
            guard let id = row.text(0),
                  let isolationKey = row.text(1),
                  let role = row.text(2) else { continue }
            let createTime = row.int64(3)
            let key = "\(createTime):\(id)"
            defer {
                state.memoryCreateTime = max(state.memoryCreateTime, createTime)
                seen.insert(key)
            }
            guard seen.contains(key) == false else { continue }
            guard let agentName = Self.agentName(for: isolationKey) else { continue }
            guard role == "assistant:decision" || (notifySubtasks && isSubtaskRole(role)) else { continue }

            let projectName = row.text(4).flatMap { $0.isEmpty ? nil : $0 } ?? "ToonFlow"
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

    private func isSubtaskRole(_ role: String) -> Bool {
        role == "assistant:supervision" ||
            role.hasPrefix("assistant:execution:")
    }

    private var notifySubtasks: Bool {
        UserDefaults.standard.bool(forKey: "com.memoryflow.island.toonflow.notifySubtasks")
    }

    static func agentName(for isolationKey: String) -> String? {
        let parts = isolationKey.split(separator: ":", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        switch parts[1] {
        case "scriptAgent":
            return "剧本 Agent"
        case "productionAgent":
            return "生产 Agent"
        default:
            let identifier = String(parts[1])
            guard identifier.hasSuffix("Agent") else { return nil }
            return "\(identifier)"
        }
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
    private var pendingClaudeWaits: [String: DispatchWorkItem] = [:]
    private var hasEstablishedBaseline = false
    private var isPolling = false
    private let claudeWaitConfirmationDelay: TimeInterval = 1.5

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
        pendingClaudeWaits.values.forEach { $0.cancel() }
        pendingClaudeWaits.removeAll()
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
                processLogLine(Data(line), from: file)
            }
            if hasTrailingNewline {
                cursor.partialLine = Data()
            } else if let trailingLine = lines.last,
                      Self.isCompleteJSONLine(Data(trailingLine)) {
                // Codex can end a terminal or user-input event without writing
                // one more newline. A complete JSON object is safe to handle
                // immediately and must not wait for the user's next prompt.
                processLogLine(Data(trailingLine), from: file)
                cursor.partialLine = Data()
            } else {
                cursor.partialLine = Data(lines.last ?? Data())
            }
            cursors[file] = cursor
        } catch {
            NSLog("[%@CompletionWatcher] log read failed: %@", provider.source.islandTitle, String(describing: error))
        }
    }

    private func processLogLine(_ line: Data, from file: URL) {
        if let event = Self.completionEvent(from: line, source: provider.source)
            ?? Self.waitingForUserEvent(from: line, source: provider.source) {
            onEvent?(event)
        }

        guard provider == .claudeCode else { return }
        Self.claudeResolvedToolUseIDs(from: line).forEach { toolUseID in
            cancelPendingClaudeWait(toolUseID, file: file)
        }
        Self.claudeToolUses(from: line).filter(\.mayRequireUserApproval).forEach { toolUse in
            scheduleClaudeWaitConfirmation(toolUse, file: file)
        }
    }

    private func scheduleClaudeWaitConfirmation(_ toolUse: ClaudeToolUse, file: URL) {
        let key = claudeWaitKey(toolUse.id, file: file)
        pendingClaudeWaits[key]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingClaudeWaits.removeValue(forKey: key) != nil else { return }
            self.onEvent?(
                ExternalAgentEvent(
                    source: .claudeCode,
                    title: "Claude Code 正在等待你的操作",
                    detail: "等待批准 (toolUse.name)"
                )
            )
        }
        pendingClaudeWaits[key] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + claudeWaitConfirmationDelay, execute: workItem)
    }

    private func cancelPendingClaudeWait(_ toolUseID: String, file: URL) {
        let key = claudeWaitKey(toolUseID, file: file)
        pendingClaudeWaits.removeValue(forKey: key)?.cancel()
    }

    private func claudeWaitKey(_ toolUseID: String, file: URL) -> String {
        "\(file.path)#\(toolUseID)"
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

    static func waitingForUserEvent(
        from line: Data,
        source: ExternalAgentEvent.Source
    ) -> ExternalAgentEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            return nil
        }

        let isWaitingForUser: Bool
        switch source {
        case .codex:
            let payload = object["payload"] as? [String: Any]
            isWaitingForUser = object["type"] as? String == "response_item"
                && payload?["type"] as? String == "function_call"
                && payload?["name"] as? String == "request_user_input"
        case .claudeCode:
            let message = object["message"] as? [String: Any]
            let content = message?["content"] as? [[String: Any]]
            isWaitingForUser = object["type"] as? String == "assistant"
                && object["isSidechain"] as? Bool != true
                && message?["stop_reason"] as? String == "tool_use"
                && content?.contains(where: {
                    $0["type"] as? String == "tool_use"
                        && $0["name"] as? String == "AskUserQuestion"
                }) == true
        case .toonFlow:
            isWaitingForUser = false
        }

        guard isWaitingForUser else { return nil }
        return ExternalAgentEvent(
            source: source,
            title: "\(source.islandTitle) 正在等待你的操作",
            detail: "等待你的选择或输入"
        )
    }

    private struct ClaudeToolUse {
        let id: String
        let name: String
        let command: String?

        var mayRequireUserApproval: Bool {
            guard name == "Bash", let command else { return false }
            let pattern = #"(?:^|[;&|]\s*)(?:sudo\s+)?(?:rm|mv|chmod|chown|dd|mkfs)\b|\bgit\s+(?:push|reset|clean|checkout|restore)\b"#
            return command.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func claudeToolUses(from line: Data) -> [ClaudeToolUse] {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "assistant",
              object["isSidechain"] as? Bool != true,
              let message = object["message"] as? [String: Any],
              message["stop_reason"] as? String == "tool_use",
              let content = message["content"] as? [[String: Any]] else {
            return []
        }
        return content.compactMap { item in
            guard item["type"] as? String == "tool_use",
                  let id = item["id"] as? String,
                  let name = item["name"] as? String else {
                return nil
            }
            let command = (item["input"] as? [String: Any])?["command"] as? String
            return ClaudeToolUse(id: id, name: name, command: command)
        }
    }

    static func claudeToolUseIDs(from line: Data) -> [String] {
        claudeToolUses(from: line).map(\.id)
    }

    static func claudePermissionSensitiveToolUseIDs(from line: Data) -> [String] {
        claudeToolUses(from: line)
            .filter(\.mayRequireUserApproval)
            .map(\.id)
    }

    static func claudeResolvedToolUseIDs(from line: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "user",
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }
        return content.compactMap { item in
            guard item["type"] as? String == "tool_result" else { return nil }
            return item["tool_use_id"] as? String
        }
    }

    static func isCompleteJSONLine(_ line: Data) -> Bool {
        (try? JSONSerialization.jsonObject(with: line)) != nil
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
