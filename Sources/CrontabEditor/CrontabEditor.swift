import AppKit
import Foundation
import SwiftUI

enum L10n {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: .current, arguments: arguments)
    }
}

@main
struct CrontabEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum TimeFieldMode: String, CaseIterable, Identifiable {
    case every = "Every"
    case specific = "Specific"
    case interval = "Every N"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
}

enum Weekday: String, CaseIterable, Identifiable {
    case every = "Every Day"
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
    var shortTitle: String {
        switch self {
        case .every: L10n.t("Every Day.short")
        case .sunday: L10n.t("Sunday.short")
        case .monday: L10n.t("Monday.short")
        case .tuesday: L10n.t("Tuesday.short")
        case .wednesday: L10n.t("Wednesday.short")
        case .thursday: L10n.t("Thursday.short")
        case .friday: L10n.t("Friday.short")
        case .saturday: L10n.t("Saturday.short")
        }
    }

    var cronValue: String {
        switch self {
        case .every: "*"
        case .sunday: "0"
        case .monday: "1"
        case .tuesday: "2"
        case .wednesday: "3"
        case .thursday: "4"
        case .friday: "5"
        case .saturday: "6"
        }
    }

    static func fromCronValue(_ value: String) -> Weekday {
        allCases.first { $0.cronValue == value } ?? .every
    }
}

struct DailyTime: Identifiable, Equatable {
    var id = UUID()
    var hour: Int
    var minute: Int

    var label: String {
        "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
    }
}

enum JobBackend: String, CaseIterable, Identifiable {
    case crontab = "Crontab"
    case launchAgent = "LaunchAgent"
    case launchDaemon = "LaunchDaemon"

    var id: String { rawValue }
}

struct CronJob: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var label: String
    var backend: JobBackend
    var scriptPath: String
    var programArgumentsText: String
    var minuteMode: TimeFieldMode
    var specificMinute: Int
    var minuteInterval: Int
    var hourMode: TimeFieldMode
    var specificHour: Int
    var hourInterval: Int
    var scheduleEnabled: Bool
    var weekday: Weekday
    var selectedWeekdays: [Weekday]
    var fixedTimes: [DailyTime]
    var runAtLoad: Bool
    var loggingEnabled: Bool
    var standardOutPath: String
    var standardErrorPath: String
    var isEnabled: Bool
    var isManaged: Bool
    var originalCommand: String?

    static func blank() -> CronJob {
        let name = L10n.t("New Job")
        return CronJob(
            name: name,
            label: CronJob.label(for: name),
            backend: .crontab,
            scriptPath: "",
            programArgumentsText: "",
            minuteMode: .every,
            specificMinute: 0,
            minuteInterval: 15,
            hourMode: .every,
            specificHour: 2,
            hourInterval: 1,
            scheduleEnabled: true,
            weekday: .every,
            selectedWeekdays: [],
            fixedTimes: [],
            runAtLoad: false,
            loggingEnabled: false,
            standardOutPath: "",
            standardErrorPath: "",
            isEnabled: true,
            isManaged: true,
            originalCommand: nil
        )
    }

    var minuteExpression: String {
        switch minuteMode {
        case .every: "*"
        case .specific: "\(specificMinute)"
        case .interval: "*/\(minuteInterval)"
        }
    }

    var hourExpression: String {
        switch hourMode {
        case .every: "*"
        case .specific: "\(specificHour)"
        case .interval: "*/\(hourInterval)"
        }
    }

    var cronExpression: String {
        guard scheduleEnabled else { return L10n.t("No schedule") }
        return "\(minuteExpression) \(hourExpression) * * \(weekdayExpression)"
    }

    var weekdayExpression: String {
        let values = activeWeekdays.map(\.cronValue)
        return values.isEmpty ? "*" : values.joined(separator: ",")
    }

    var activeWeekdays: [Weekday] {
        selectedWeekdays.filter { $0 != .every }
    }

    var cronExpressions: [String] {
        guard scheduleEnabled else { return [] }
        if fixedTimes.isEmpty {
            return [cronExpression]
        }

        return fixedTimes.map { "\($0.minute) \($0.hour) * * \(weekdayExpression)" }
    }

    var command: String {
        let base = ([scriptPath] + programArguments).map(shellEscaped).joined(separator: " ")
        guard loggingEnabled else {
            return base
        }

        let outPath = standardOutPath.isEmpty ? defaultCronOutLogPath : standardOutPath
        let errPath = standardErrorPath.isEmpty ? defaultCronErrorLogPath : standardErrorPath
        return "\(base) >> \(shellEscaped(outPath)) 2>> \(shellEscaped(errPath))"
    }

    var programArguments: [String] {
        parseArguments(programArgumentsText)
    }

    var launchdProgramArguments: [String] {
        [scriptPath] + programArguments
    }

    var defaultCronOutLogPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
            .appendingPathComponent("\(label).out.log")
            .path
    }

    var defaultCronErrorLogPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
            .appendingPathComponent("\(label).err.log")
            .path
    }

    var cronLine: String {
        cronLines.joined(separator: "\n")
    }

    var cronLines: [String] {
        guard scheduleEnabled else { return [] }
        return cronExpressions.map { expression in
            let line = "\(expression) \(command)"
            return isEnabled ? line : "# \(line)"
        }
    }

    var launchAgentPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    var launchDaemonPath: URL {
        URL(fileURLWithPath: "/Library/LaunchDaemons")
            .appendingPathComponent("\(label).plist")
    }

    var title: String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? L10n.t("New Job") : value
    }

    var subtitle: String {
        "\(backend.rawValue) · \(cronExpressions.first ?? cronExpression) · \(isEnabled ? L10n.t("active") : L10n.t("inactive"))"
    }

    var scheduleDescription: String {
        guard scheduleEnabled else {
            return runAtLoad
                ? L10n.t("No schedule. The job starts when loaded and via Run now.")
                : L10n.t("No schedule. The job starts only via Run now.")
        }

        let minuteText = switch minuteMode {
        case .every: L10n.t("every minute")
        case .specific: L10n.f("minute %d", specificMinute)
        case .interval: L10n.f("every %d minutes", minuteInterval)
        }

        let hourText = switch hourMode {
        case .every: L10n.t("every hour")
        case .specific: L10n.f("at %02d:00", specificHour)
        case .interval: L10n.f("every %d hours", hourInterval)
        }

        let dayText = activeWeekdays.isEmpty ? L10n.t("Every Day") : activeWeekdays.map(\.title).joined(separator: ", ")
        let timeText = fixedTimes.isEmpty ? "\(hourText), \(minuteText)" : fixedTimes.map(\.label).joined(separator: ", ")

        return "\(dayText), \(timeText)."
    }

    private func shellEscaped(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func parseArguments(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var isEscaped = false

        for character in text {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }
            if character == "'" || character == "\"" {
                quote = character
                continue
            }
            if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
                continue
            }
            current.append(character)
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    static func label(for name: String) -> String {
        let slug = name
            .lowercased()
            .replacing(/[ä]/, with: "ae")
            .replacing(/[ö]/, with: "oe")
            .replacing(/[ü]/, with: "ue")
            .replacing(/[ß]/, with: "ss")
            .replacing(/[^a-z0-9]+/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return "local.crontabeditor.\(slug.isEmpty ? "job" : slug)"
    }
}

struct CrontabDocument {
    var jobs: [CronJob]
    var preservedLines: [String]
}

@MainActor
final class CrontabViewModel: ObservableObject {
    @Published var jobs: [CronJob] = []
    @Published var selectedJobID: CronJob.ID?
    @Published var statusMessage = L10n.t("Not loaded yet.")
    @Published var invalidJobIDs: Set<CronJob.ID> = []
    @Published var showExternalJobs = false

    private let manager = CrontabManager()
    private let launchAgentManager = LaunchAgentManager()
    private let launchDaemonManager = LaunchDaemonManager()
    private var preservedLines: [String] = []

    var selectedIndex: Int? {
        guard let selectedJobID else { return nil }
        return jobs.firstIndex { $0.id == selectedJobID }
    }

    var selectedJob: CronJob? {
        guard let selectedIndex else { return nil }
        return jobs[selectedIndex]
    }

    var canSave: Bool {
        jobs.filter(isEditable).allSatisfy { !$0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var managedJobs: [CronJob] {
        jobs.filter(\.isManaged)
    }

    var externalJobs: [CronJob] {
        jobs.filter { !$0.isManaged }
    }

    func isEditable(_ job: CronJob) -> Bool {
        job.isManaged || job.backend == .crontab
    }

    var visibleJobs: [CronJob] {
        showExternalJobs ? jobs : managedJobs
    }

    func load() {
        do {
            let document = try manager.load()
            let launchAgentJobs = try launchAgentManager.load()
            let launchDaemonJobs = try launchDaemonManager.load()
            jobs = document.jobs + launchAgentJobs + launchDaemonJobs
            preservedLines = document.preservedLines
            selectedJobID = jobs.first?.id
            statusMessage = jobs.isEmpty ? L10n.t("No cron jobs found.") : L10n.f("%d cron job(s) loaded.", jobs.count)
        } catch {
            statusMessage = L10n.f("Could not read crontab: %@", error.localizedDescription)
        }
    }

    func addJob() {
        let job = CronJob.blank()
        jobs.append(job)
        selectedJobID = job.id
        statusMessage = L10n.t("New job created.")
    }

    func deleteSelectedJob() {
        guard let selectedIndex else { return }
        guard isEditable(jobs[selectedIndex]) else {
            statusMessage = L10n.t("External LaunchAgent/LaunchDaemon jobs are display-only.")
            return
        }
        jobs.remove(at: selectedIndex)
        selectedJobID = jobs.indices.contains(selectedIndex) ? jobs[selectedIndex].id : jobs.last?.id
        statusMessage = L10n.t("Job removed. Save writes the change to the crontab.")
    }

    func save() {
        guard canSave else {
            invalidJobIDs = Set(jobs
                .filter(isEditable)
                .filter { $0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map(\.id))
            selectedJobID = invalidJobIDs.first ?? selectedJobID
            statusMessage = L10n.t("All jobs need a script path.")
            return
        }
        invalidJobIDs.removeAll()

        do {
            try manager.save(jobs: jobs.filter { $0.backend == .crontab }, preservedLines: preservedLines)
            try launchAgentManager.save(jobs: jobs.filter { $0.backend == .launchAgent && $0.isManaged })
            try launchDaemonManager.save(jobs: jobs.filter { $0.backend == .launchDaemon && $0.isManaged })
            statusMessage = L10n.t("Jobs saved.")
        } catch {
            statusMessage = L10n.f("Save failed: %@", error.localizedDescription)
        }
    }

    func runSelectedNow() {
        guard let selectedJob else { return }

        do {
            switch selectedJob.backend {
            case .crontab:
                try ScriptRunner.run(path: selectedJob.scriptPath, arguments: selectedJob.programArguments)
            case .launchAgent:
                try launchAgentManager.runNow(selectedJob)
            case .launchDaemon:
                try launchDaemonManager.runNow(selectedJob)
            }
            statusMessage = L10n.t("Job started.")
        } catch {
            statusMessage = L10n.f("Start failed: %@", error.localizedDescription)
        }
    }

    func chooseScriptForSelectedJob() {
        guard let selectedIndex else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = L10n.t("Choose Script")

        if panel.runModal() == .OK, let url = panel.url {
            jobs[selectedIndex].scriptPath = url.path
            jobs[selectedIndex].originalCommand = nil
            invalidJobIDs.remove(jobs[selectedIndex].id)
        }
    }

    func updateSelectedJob(_ update: (inout CronJob) -> Void) {
        guard let selectedIndex else { return }
        update(&jobs[selectedIndex])
    }

    func updateSelectedJobName(_ name: String) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].name = name
        jobs[selectedIndex].label = CronJob.label(for: name)
    }

    func setBackendForSelectedJob(_ backend: JobBackend) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].backend = backend
        if backend == .crontab {
            jobs[selectedIndex].runAtLoad = false
        }
    }

    func setWeekdaysForSelectedJob(_ weekdays: [Weekday]) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].selectedWeekdays = weekdays
    }

    func toggleWeekdayForSelectedJob(_ weekday: Weekday) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedWeekdays.contains(weekday) {
            jobs[selectedIndex].selectedWeekdays.removeAll { $0 == weekday }
        } else {
            jobs[selectedIndex].selectedWeekdays.append(weekday)
        }
    }

    func addFixedTimeForSelectedJob() {
        guard let selectedIndex else { return }
        jobs[selectedIndex].fixedTimes.append(DailyTime(hour: jobs[selectedIndex].specificHour, minute: jobs[selectedIndex].specificMinute))
    }

    func removeFixedTimeForSelectedJob(_ time: DailyTime) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].fixedTimes.removeAll { $0.id == time.id }
    }
}

struct CrontabManager {
    private let beginMarker = "# CrontabEditor BEGIN"
    private let endMarker = "# CrontabEditor END"
    private let jobMarkerPrefix = "# CrontabEditor JOB "

    func load() throws -> CrontabDocument {
        let crontab = try readCrontab()
        var jobs: [CronJob] = []
        var preservedLines: [String] = []
        var insideOldManagedBlock = false
        var nextManagedName: String?

        for line in crontab.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line == beginMarker {
                insideOldManagedBlock = true
                continue
            }
            if line == endMarker {
                insideOldManagedBlock = false
                continue
            }
            if line.hasPrefix(jobMarkerPrefix) {
                nextManagedName = String(line.dropFirst(jobMarkerPrefix.count))
                continue
            }
            if let job = parse(line: line) {
                if let managedName = nextManagedName {
                    var managedJob = job
                    managedJob.isManaged = true
                    managedJob.name = managedName
                    managedJob.label = CronJob.label(for: managedName)
                    jobs.append(managedJob)
                    nextManagedName = nil
                } else if insideOldManagedBlock {
                    var managedJob = job
                    managedJob.isManaged = true
                    jobs.append(managedJob)
                } else {
                    jobs.append(job)
                }
            } else if !insideOldManagedBlock {
                preservedLines.append(line)
            }
        }

        return CrontabDocument(jobs: jobs, preservedLines: trimmedTrailingEmptyLines(preservedLines))
    }

    func save(jobs: [CronJob], preservedLines: [String]) throws {
        let jobLines = jobs.flatMap { job in
            job.isManaged ? ["\(jobMarkerPrefix)\(job.name)"] + job.cronLines : job.cronLines
        }
        var lines = trimmedTrailingEmptyLines(preservedLines)

        if !lines.isEmpty && !jobLines.isEmpty {
            lines.append("")
        }

        lines.append(contentsOf: jobLines)
        let crontab = lines.joined(separator: "\n") + "\n"
        try install(crontab: crontab)
    }

    private func readCrontab() throws -> String {
        do {
            return try run("/usr/bin/crontab", arguments: ["-l"])
        } catch let error as CrontabError {
            if error.output.contains("no crontab for") {
                return ""
            }
            throw error
        }
    }

    private func install(crontab: String) throws {
        _ = try run("/usr/bin/crontab", arguments: ["-"], standardInput: crontab)
    }

    private func parse(line: String) -> CronJob? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let isEnabled = !trimmed.hasPrefix("#")
        let activeLine = isEnabled ? trimmed : trimmed.replacing(/^#\s*/, with: "")
        let parts = activeLine.split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 6, isCronTime(parts[0]), isCronTime(parts[1]) else {
            return nil
        }

        let command = parts[5]
        let commandParts = parseCommand(command)
        let scriptPath = commandParts.first ?? unquote(command)
        let parsedCommand = parseCronCommandParts(commandParts)
        var job = CronJob.blank()
        job.backend = .crontab
        job.isManaged = false
        job.scriptPath = scriptPath
        job.programArgumentsText = parsedCommand.arguments.map(shellEscaped).joined(separator: " ")
        job.loggingEnabled = parsedCommand.outLogPath != nil || parsedCommand.errorLogPath != nil
        job.standardOutPath = parsedCommand.outLogPath ?? ""
        job.standardErrorPath = parsedCommand.errorLogPath ?? ""
        job.name = URL(fileURLWithPath: scriptPath).lastPathComponent
        job.label = CronJob.label(for: job.name)
        job.isEnabled = isEnabled
        job.originalCommand = nil
        applyMinute(parts[0], to: &job)
        applyHour(parts[1], to: &job)
        job.selectedWeekdays = parseWeekdays(parts[4])
        return job
    }

    private func parseCronCommandParts(_ commandParts: [String]) -> (arguments: [String], outLogPath: String?, errorLogPath: String?) {
        var arguments: [String] = []
        var outLogPath: String?
        var errorLogPath: String?
        var index = 1

        while index < commandParts.count {
            let part = commandParts[index]

            if part == ">>", index + 1 < commandParts.count {
                outLogPath = commandParts[index + 1]
                index += 2
                continue
            }

            if part == "2>>", index + 1 < commandParts.count {
                errorLogPath = commandParts[index + 1]
                index += 2
                continue
            }

            arguments.append(part)
            index += 1
        }

        return (arguments, outLogPath, errorLogPath)
    }

    private func parseWeekdays(_ value: String) -> [Weekday] {
        if value == "*" {
            return []
        }

        return value
            .split(separator: ",")
            .map(String.init)
            .map(Weekday.fromCronValue)
            .filter { $0 != .every }
    }

    private func isCronTime(_ value: String) -> Bool {
        value == "*" || Int(value) != nil || (value.hasPrefix("*/") && Int(value.dropFirst(2)) != nil)
    }

    private func applyMinute(_ value: String, to job: inout CronJob) {
        if value == "*" {
            job.minuteMode = .every
        } else if value.hasPrefix("*/"), let interval = Int(value.dropFirst(2)) {
            job.minuteMode = .interval
            job.minuteInterval = min(max(interval, 1), 59)
        } else if let minute = Int(value) {
            job.minuteMode = .specific
            job.specificMinute = min(max(minute, 0), 59)
        }
    }

    private func applyHour(_ value: String, to job: inout CronJob) {
        if value == "*" {
            job.hourMode = .every
        } else if value.hasPrefix("*/"), let interval = Int(value.dropFirst(2)) {
            job.hourMode = .interval
            job.hourInterval = min(max(interval, 1), 23)
        } else if let hour = Int(value) {
            job.hourMode = .specific
            job.specificHour = min(max(hour, 0), 23)
        }
    }

    private func unquote(_ command: String) -> String {
        command
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            .replacingOccurrences(of: "'\\''", with: "'")
    }

    private func parseCommand(_ command: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var isEscaped = false

        for character in command {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }
            if character == "'" || character == "\"" {
                quote = character
                continue
            }
            if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
                continue
            }
            current.append(character)
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    private func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func trimmedTrailingEmptyLines(_ lines: [String]) -> [String] {
        var result = lines
        while result.last?.isEmpty == true {
            result.removeLast()
        }
        return result
    }

    private func run(_ executable: String, arguments: [String], standardInput: String? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        let input = Pipe()
        if standardInput != nil {
            process.standardInput = input
        }

        try process.run()

        if let standardInput {
            input.fileHandleForWriting.write(Data(standardInput.utf8))
            try input.fileHandleForWriting.close()
        }

        process.waitUntilExit()

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CrontabError(status: process.terminationStatus, output: stdout + stderr)
        }

        return stdout
    }
}

struct ScriptRunner {
    static func run(path: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
    }
}

struct LaunchAgentManager {
    private let prefix = "local.crontabeditor."

    func load() throws -> [CronJob] {
        let directory = launchAgentsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "plist" }
            .compactMap(loadJob)
    }

    func save(jobs: [CronJob]) throws {
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let existing = try load().filter(\.isManaged)
        let nextLabels = Set(jobs.map(\.label))
        for job in existing where !nextLabels.contains(job.label) {
            try? unload(job)
            try? FileManager.default.removeItem(at: job.launchAgentPath)
        }

        for job in jobs {
            if !job.isEnabled {
                if FileManager.default.fileExists(atPath: job.launchAgentPath.path) {
                    try? unload(job)
                    try? FileManager.default.removeItem(at: job.launchAgentPath)
                }
                continue
            }

            let plist = plistDictionary(for: job)
            let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            if let existingData = try? Data(contentsOf: job.launchAgentPath), existingData == plistData {
                continue
            }

            try write(data: plistData, to: job.launchAgentPath)
            try? unload(job)
            try load(job)
        }
    }

    func runNow(_ job: CronJob) throws {
        _ = try run("/bin/launchctl", arguments: ["kickstart", "-k", "\(guiDomain)/\(job.label)"])
    }

    private var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    private func loadJob(from url: URL) -> CronJob? {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let label = plist["Label"] as? String,
            let arguments = plist["ProgramArguments"] as? [String],
            let scriptPath = arguments.first
        else {
            return nil
        }

        var job = CronJob.blank()
        job.backend = .launchAgent
        job.label = label
        job.isManaged = label.hasPrefix(prefix)
        job.name = job.isManaged ? displayName(from: label) : label
        job.scriptPath = scriptPath
        job.programArgumentsText = arguments.dropFirst().map(shellEscaped).joined(separator: " ")
        job.isEnabled = true

        job.runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        job.standardOutPath = (plist["StandardOutPath"] as? String) ?? ""
        job.standardErrorPath = (plist["StandardErrorPath"] as? String) ?? ""
        job.loggingEnabled = !job.standardOutPath.isEmpty || !job.standardErrorPath.isEmpty
        job.scheduleEnabled = plist["StartInterval"] != nil || plist["StartCalendarInterval"] != nil

        if let interval = plist["StartInterval"] as? Int {
            applyStartInterval(interval, to: &job)
        } else if let calendar = plist["StartCalendarInterval"] as? [String: Int] {
            applyCalendar(calendar, to: &job)
        } else if let calendars = plist["StartCalendarInterval"] as? [[String: Int]] {
            applyCalendars(calendars, to: &job)
        }

        return job
    }

    private func plistDictionary(for job: CronJob) -> [String: Any] {
        var plist: [String: Any] = [
            "Label": job.label,
            "ProgramArguments": job.launchdProgramArguments,
            "RunAtLoad": job.runAtLoad
        ]

        if job.loggingEnabled {
            plist["StandardOutPath"] = job.standardOutPath.isEmpty ? logPath(for: job, suffix: "out") : job.standardOutPath
            plist["StandardErrorPath"] = job.standardErrorPath.isEmpty ? logPath(for: job, suffix: "err") : job.standardErrorPath
        }

        if job.scheduleEnabled {
            if let interval = startInterval(for: job) {
                plist["StartInterval"] = interval
            } else {
                plist["StartCalendarInterval"] = startCalendarIntervals(for: job)
            }
        }

        return plist
    }

    private func startInterval(for job: CronJob) -> Int? {
        if job.activeWeekdays.isEmpty, job.fixedTimes.isEmpty, job.hourMode == .every, job.minuteMode == .interval {
            return job.minuteInterval * 60
        }
        if job.activeWeekdays.isEmpty, job.fixedTimes.isEmpty, job.hourMode == .interval, job.minuteMode == .specific {
            return job.hourInterval * 60 * 60
        }
        if job.activeWeekdays.isEmpty, job.fixedTimes.isEmpty, job.hourMode == .every, job.minuteMode == .every {
            return 60
        }
        return nil
    }

    private func startCalendarIntervals(for job: CronJob) -> Any {
        let weekdays = job.activeWeekdays
        let times = job.fixedTimes

        if times.isEmpty {
            return startCalendarInterval(for: job, weekday: weekdays.first)
        }

        let intervals = (weekdays.isEmpty ? [nil] : weekdays.map(Optional.some)).flatMap { weekday in
            times.map { time in
                var calendar: [String: Int] = ["Hour": time.hour, "Minute": time.minute]
                if let weekday, let value = Int(weekday.cronValue) {
                    calendar["Weekday"] = value == 0 ? 7 : value
                }
                return calendar
            }
        }

        return intervals.count == 1 ? intervals[0] : intervals
    }

    private func startCalendarInterval(for job: CronJob, weekday selectedWeekday: Weekday?) -> [String: Int] {
        var calendar: [String: Int] = [:]

        if job.minuteMode == .specific {
            calendar["Minute"] = job.specificMinute
        }
        if job.hourMode == .specific {
            calendar["Hour"] = job.specificHour
        }
        if let selectedWeekday, let weekday = Int(selectedWeekday.cronValue) {
            calendar["Weekday"] = weekday == 0 ? 7 : weekday
        }

        if calendar.isEmpty {
            calendar["Minute"] = 0
        }

        return calendar
    }

    private func applyStartInterval(_ interval: Int, to job: inout CronJob) {
        if interval == 60 {
            job.minuteMode = .every
            job.hourMode = .every
        } else if interval % 3600 == 0 {
            job.hourMode = .interval
            job.hourInterval = min(max(interval / 3600, 1), 23)
            job.minuteMode = .specific
            job.specificMinute = 0
        } else if interval % 60 == 0 {
            job.hourMode = .every
            job.minuteMode = .interval
            job.minuteInterval = min(max(interval / 60, 1), 59)
        }
    }

    private func applyCalendar(_ calendar: [String: Int], to job: inout CronJob) {
        if let minute = calendar["Minute"] {
            job.minuteMode = .specific
            job.specificMinute = min(max(minute, 0), 59)
        } else {
            job.minuteMode = .every
        }

        if let hour = calendar["Hour"] {
            job.hourMode = .specific
            job.specificHour = min(max(hour, 0), 23)
        } else {
            job.hourMode = .every
        }

        if let launchdWeekday = calendar["Weekday"] {
            let cronWeekday = launchdWeekday == 7 ? "0" : "\(launchdWeekday)"
            job.selectedWeekdays = [Weekday.fromCronValue(cronWeekday)]
        }
    }

    private func applyCalendars(_ calendars: [[String: Int]], to job: inout CronJob) {
        let times = calendars.compactMap { calendar -> DailyTime? in
            guard let hour = calendar["Hour"], let minute = calendar["Minute"] else { return nil }
            return DailyTime(hour: min(max(hour, 0), 23), minute: min(max(minute, 0), 59))
        }
        if !times.isEmpty {
            job.fixedTimes = Array(Set(times.map(\.label))).sorted().compactMap { label in
                let parts = label.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { return nil }
                return DailyTime(hour: parts[0], minute: parts[1])
            }
        }

        let weekdays = calendars.compactMap { calendar -> Weekday? in
            guard let launchdWeekday = calendar["Weekday"] else { return nil }
            return Weekday.fromCronValue(launchdWeekday == 7 ? "0" : "\(launchdWeekday)")
        }
        job.selectedWeekdays = Array(Set(weekdays)).sorted { $0.cronValue < $1.cronValue }
    }

    private func write(data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private func load(_ job: CronJob) throws {
        _ = try run("/bin/launchctl", arguments: ["bootstrap", guiDomain, job.launchAgentPath.path])
    }

    private func unload(_ job: CronJob) throws {
        _ = try run("/bin/launchctl", arguments: ["bootout", guiDomain, job.launchAgentPath.path])
    }

    private var guiDomain: String {
        "gui/\(getuid())"
    }

    private func logPath(for job: CronJob, suffix: String) -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
            .appendingPathComponent("\(job.label).\(suffix).log")
            .path
    }

    private func displayName(from label: String) -> String {
        label
            .replacing(/^local\.crontabeditor\./, with: "")
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CrontabError(status: process.terminationStatus, output: stdout + stderr)
        }

        return stdout
    }
}

struct LaunchDaemonManager {
    private let prefix = "local.crontabeditor."

    func load() throws -> [CronJob] {
        let directory = URL(fileURLWithPath: "/Library/LaunchDaemons")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "plist" }
            .compactMap(loadJob)
    }

    func save(jobs: [CronJob]) throws {
        let existing = try load().filter(\.isManaged)
        let nextLabels = Set(jobs.map(\.label))
        var commands: [String] = [
            "set -e",
            "mkdir -p /Library/LaunchDaemons"
        ]
        var temporaryFiles: [URL] = []

        for job in existing where !nextLabels.contains(job.label) {
            commands.append(bootoutCommand(for: job))
            commands.append("rm -f \(shellQuoted(job.launchDaemonPath.path))")
        }

        for job in jobs {
            if !job.isEnabled {
                if FileManager.default.fileExists(atPath: job.launchDaemonPath.path) {
                    commands.append(bootoutCommand(for: job))
                    commands.append("rm -f \(shellQuoted(job.launchDaemonPath.path))")
                }
                continue
            }

            let plist = plistDictionary(for: job)
            let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            if let existingData = try? Data(contentsOf: job.launchDaemonPath), existingData == plistData {
                continue
            }

            let localURL = try writeTemporary(data: plistData, label: job.label)
            temporaryFiles.append(localURL)

            commands.append(bootoutCommand(for: job))
            commands.append("cp \(shellQuoted(localURL.path)) \(shellQuoted(job.launchDaemonPath.path))")
            commands.append("chown root:wheel \(shellQuoted(job.launchDaemonPath.path))")
            commands.append("chmod 644 \(shellQuoted(job.launchDaemonPath.path))")
            commands.append("/bin/launchctl bootstrap system \(shellQuoted(job.launchDaemonPath.path))")
        }

        defer {
            for url in temporaryFiles {
                try? FileManager.default.removeItem(at: url)
            }
        }

        guard commands.count > 2 else {
            return
        }

        try runScriptAsAdmin(commands.joined(separator: "\n"))
    }

    func runNow(_ job: CronJob) throws {
        try runScriptAsAdmin("/bin/launchctl kickstart -k system/\(shellQuoted(job.label))")
    }

    private func loadJob(from url: URL) -> CronJob? {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let label = plist["Label"] as? String,
            let arguments = plist["ProgramArguments"] as? [String],
            let scriptPath = arguments.first
        else {
            return nil
        }

        var job = CronJob.blank()
        job.backend = .launchDaemon
        job.label = label
        job.isManaged = label.hasPrefix(prefix)
        job.name = job.isManaged ? displayName(from: label) : label
        job.scriptPath = scriptPath
        job.programArgumentsText = arguments.dropFirst().map(shellEscaped).joined(separator: " ")
        job.isEnabled = true

        job.runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        job.standardOutPath = (plist["StandardOutPath"] as? String) ?? ""
        job.standardErrorPath = (plist["StandardErrorPath"] as? String) ?? ""
        job.loggingEnabled = !job.standardOutPath.isEmpty || !job.standardErrorPath.isEmpty
        job.scheduleEnabled = plist["StartInterval"] != nil || plist["StartCalendarInterval"] != nil

        if let interval = plist["StartInterval"] as? Int {
            applyStartInterval(interval, to: &job)
        } else if let calendar = plist["StartCalendarInterval"] as? [String: Int] {
            applyCalendar(calendar, to: &job)
        } else if let calendars = plist["StartCalendarInterval"] as? [[String: Int]] {
            applyCalendars(calendars, to: &job)
        }

        return job
    }

    private func plistDictionary(for job: CronJob) -> [String: Any] {
        var plist: [String: Any] = [
            "Label": job.label,
            "ProgramArguments": job.launchdProgramArguments,
            "RunAtLoad": job.runAtLoad
        ]

        if job.loggingEnabled {
            plist["StandardOutPath"] = job.standardOutPath.isEmpty ? "/var/log/\(job.label).out.log" : job.standardOutPath
            plist["StandardErrorPath"] = job.standardErrorPath.isEmpty ? "/var/log/\(job.label).err.log" : job.standardErrorPath
        }

        if job.scheduleEnabled {
            if let interval = startInterval(for: job) {
                plist["StartInterval"] = interval
            } else {
                plist["StartCalendarInterval"] = startCalendarIntervals(for: job)
            }
        }

        return plist
    }

    private func writeTemporary(data: Data, label: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(label).plist")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func bootoutCommand(for job: CronJob) -> String {
        "/bin/launchctl bootout system \(shellQuoted(job.launchDaemonPath.path)) 2>/dev/null || true"
    }

    private func startInterval(for job: CronJob) -> Int? {
        if job.activeWeekdays.isEmpty, job.fixedTimes.isEmpty, job.hourMode == .every, job.minuteMode == .interval {
            return job.minuteInterval * 60
        }
        if job.activeWeekdays.isEmpty, job.fixedTimes.isEmpty, job.hourMode == .interval, job.minuteMode == .specific {
            return job.hourInterval * 60 * 60
        }
        if job.activeWeekdays.isEmpty, job.fixedTimes.isEmpty, job.hourMode == .every, job.minuteMode == .every {
            return 60
        }
        return nil
    }

    private func startCalendarIntervals(for job: CronJob) -> Any {
        let weekdays = job.activeWeekdays
        let times = job.fixedTimes

        if times.isEmpty {
            let intervals = weekdays.isEmpty
                ? [startCalendarInterval(for: job, weekday: nil)]
                : weekdays.map { startCalendarInterval(for: job, weekday: $0) }
            return intervals.count == 1 ? intervals[0] : intervals
        }

        let intervals = (weekdays.isEmpty ? [nil] : weekdays.map(Optional.some)).flatMap { weekday in
            times.map { time in
                var calendar: [String: Int] = ["Hour": time.hour, "Minute": time.minute]
                if let weekday, let value = Int(weekday.cronValue) {
                    calendar["Weekday"] = value == 0 ? 7 : value
                }
                return calendar
            }
        }

        return intervals.count == 1 ? intervals[0] : intervals
    }

    private func startCalendarInterval(for job: CronJob, weekday selectedWeekday: Weekday?) -> [String: Int] {
        var calendar: [String: Int] = [:]
        if job.minuteMode == .specific {
            calendar["Minute"] = job.specificMinute
        }
        if job.hourMode == .specific {
            calendar["Hour"] = job.specificHour
        }
        if let selectedWeekday, let weekday = Int(selectedWeekday.cronValue) {
            calendar["Weekday"] = weekday == 0 ? 7 : weekday
        }
        if calendar.isEmpty {
            calendar["Minute"] = 0
        }
        return calendar
    }

    private func applyStartInterval(_ interval: Int, to job: inout CronJob) {
        if interval == 60 {
            job.minuteMode = .every
            job.hourMode = .every
        } else if interval % 3600 == 0 {
            job.hourMode = .interval
            job.hourInterval = min(max(interval / 3600, 1), 23)
            job.minuteMode = .specific
            job.specificMinute = 0
        } else if interval % 60 == 0 {
            job.hourMode = .every
            job.minuteMode = .interval
            job.minuteInterval = min(max(interval / 60, 1), 59)
        }
    }

    private func applyCalendar(_ calendar: [String: Int], to job: inout CronJob) {
        if let minute = calendar["Minute"] {
            job.minuteMode = .specific
            job.specificMinute = min(max(minute, 0), 59)
        } else {
            job.minuteMode = .every
        }

        if let hour = calendar["Hour"] {
            job.hourMode = .specific
            job.specificHour = min(max(hour, 0), 23)
        } else {
            job.hourMode = .every
        }

        if let launchdWeekday = calendar["Weekday"] {
            let cronWeekday = launchdWeekday == 7 ? "0" : "\(launchdWeekday)"
            job.selectedWeekdays = [Weekday.fromCronValue(cronWeekday)]
        }
    }

    private func applyCalendars(_ calendars: [[String: Int]], to job: inout CronJob) {
        let times = calendars.compactMap { calendar -> DailyTime? in
            guard let hour = calendar["Hour"], let minute = calendar["Minute"] else { return nil }
            return DailyTime(hour: min(max(hour, 0), 23), minute: min(max(minute, 0), 59))
        }
        if !times.isEmpty {
            job.fixedTimes = Array(Set(times.map(\.label))).sorted().compactMap { label in
                let parts = label.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { return nil }
                return DailyTime(hour: parts[0], minute: parts[1])
            }
        }

        let weekdays = calendars.compactMap { calendar -> Weekday? in
            guard let launchdWeekday = calendar["Weekday"] else { return nil }
            return Weekday.fromCronValue(launchdWeekday == 7 ? "0" : "\(launchdWeekday)")
        }
        job.selectedWeekdays = Array(Set(weekdays)).sorted { $0.cronValue < $1.cronValue }
    }

    private func runScriptAsAdmin(_ shellScript: String) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("crontab-editor-launchdaemon-\(UUID().uuidString).sh")
        try shellScript.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let script = "do shell script \(appleScriptQuoted("/bin/sh \(shellQuoted(url.path))")) with administrator privileges"
        _ = try run("/usr/bin/osascript", arguments: ["-e", script])
    }

    private func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CrontabError(status: process.terminationStatus, output: stdout + stderr)
        }

        return stdout
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func shellEscaped(_ value: String) -> String {
        shellQuoted(value)
    }

    private func appleScriptQuoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private func displayName(from label: String) -> String {
        label
            .replacing(/^local\.crontabeditor\./, with: "")
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

struct CrontabError: LocalizedError {
    let status: Int32
    let output: String

    var errorDescription: String? {
        output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "crontab exited with status \(status)"
            : output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = CrontabViewModel()
    @State private var isBackendHelpVisible = false
    @State private var isAdvancedExpanded = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Crontab Editor")
                    .font(.title2.bold())
                Text(L10n.t("Crontab, LaunchAgent, and LaunchDaemon"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(L10n.t("Jobs"))
                    .font(.title2.bold())
                Spacer()
                Text("\(viewModel.visibleJobs.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            List(selection: $viewModel.selectedJobID) {
                Section(L10n.t("From Crontab Editor")) {
                    ForEach(viewModel.managedJobs) { job in
                        JobRow(job: job)
                            .tag(job.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 10))
                    }
                }

                if viewModel.showExternalJobs {
                    Section(L10n.t("External")) {
                        ForEach(viewModel.externalJobs) { job in
                            JobRow(job: job)
                                .tag(job.id)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 10))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack(spacing: 8) {
                Button {
                    viewModel.addJob()
                } label: {
                    Label(L10n.t("Add"), systemImage: "plus")
                }
                Button {
                    viewModel.deleteSelectedJob()
                } label: {
                    Label(L10n.t("Delete"), systemImage: "trash")
                }
                .disabled(viewModel.selectedJobID == nil)
                Spacer()
                Toggle(L10n.t("External"), isOn: $viewModel.showExternalJobs)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(width: 300)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var editor: some View {
        if let index = viewModel.selectedIndex {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !viewModel.isEditable(viewModel.jobs[index]) {
                        externalJobNotice
                    }
                    jobBasicsSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    scriptSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    scheduleSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    statusSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    advancedSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    footer
                }
                .padding(24)
            }
        } else {
            VStack(spacing: 12) {
                Text(L10n.t("No job selected"))
                    .font(.title2.bold())
                Button(L10n.t("Add Job")) {
                    viewModel.addJob()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var externalJobNotice: some View {
        Text(L10n.t("External LaunchAgents and LaunchDaemons are not editable."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func jobBasicsSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Job")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("Name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Backup Job", text: Binding(
                            get: { viewModel.jobs[index].name },
                            set: { viewModel.updateSelectedJobName($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text(L10n.t("Type"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Button {
                                isBackendHelpVisible.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.t("Differences between Crontab, LaunchAgent, and LaunchDaemon"))
                            .popover(isPresented: $isBackendHelpVisible, arrowEdge: .top) {
                                BackendHelpView()
                            }
                        }

                        Picker(L10n.t("Type"), selection: Binding(
                            get: { viewModel.jobs[index].backend },
                            set: { viewModel.setBackendForSelectedJob($0) }
                        )) {
                            ForEach(JobBackend.allCases) { backend in
                                Text(backend.rawValue).tag(backend)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                }

                Text(L10n.f("LaunchD ID: %@", viewModel.jobs[index].label))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(viewModel.jobs[index].backend == .crontab
                    ? L10n.t("Saves the job in your user crontab.")
                    : viewModel.jobs[index].backend == .launchAgent
                        ? L10n.t("Saves the job as a LaunchAgent under ~/Library/LaunchAgents.")
                        : L10n.t("Saves the job as a LaunchDaemon under /Library/LaunchDaemons. macOS asks for admin rights."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scriptSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Script")) {
            let isInvalid = viewModel.invalidJobIDs.contains(viewModel.jobs[index].id)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    TextField("/Users/mathis/bin/backup.sh", text: binding(index, \.scriptPath))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 2)
                        }
                        .onChange(of: viewModel.jobs[index].scriptPath) {
                            viewModel.updateSelectedJob {
                                $0.originalCommand = nil
                                viewModel.invalidJobIDs.remove($0.id)
                            }
                        }
                    Button(L10n.t("Choose")) {
                        viewModel.chooseScriptForSelectedJob()
                    }
                }

                if isInvalid {
                    Text(L10n.t("Script path is missing. Choose a file or enter a path."))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func scheduleSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Schedule")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(L10n.t("Schedule enabled"), isOn: binding(index, \.scheduleEnabled))

                HStack(alignment: .center, spacing: 10) {
                    Picker(L10n.t("Days"), selection: Binding(
                        get: { weekdayPreset(for: viewModel.jobs[index]) },
                        set: { applyWeekdayPreset($0) }
                    )) {
                        Text(L10n.t("Daily")).tag("daily")
                        Text(L10n.t("Workdays")).tag("workdays")
                        Text(L10n.t("Weekend")).tag("weekend")
                        Text(L10n.t("Custom")).tag("custom")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 330)

                    HStack(spacing: 4) {
                        ForEach([Weekday.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]) { weekday in
                            Toggle(weekday.shortTitle, isOn: Binding(
                                get: { viewModel.jobs[index].selectedWeekdays.contains(weekday) },
                                set: { _ in viewModel.toggleWeekdayForSelectedJob(weekday) }
                            ))
                            .toggleStyle(.button)
                            .controlSize(.small)
                        }
                    }
                }
                .disabled(!viewModel.jobs[index].scheduleEnabled)

                HStack(alignment: .top, spacing: 14) {
                    compactTimeControl(
                        title: L10n.t("Hour"),
                        picker: Picker(L10n.t("Hour"), selection: binding(index, \.hourMode)) {
                            ForEach(TimeFieldMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        },
                        value: AnyView(hourValueControl(index: index))
                    )

                    compactTimeControl(
                        title: L10n.t("Minute"),
                        picker: Picker(L10n.t("Minute"), selection: binding(index, \.minuteMode)) {
                            ForEach(TimeFieldMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        },
                        value: AnyView(minuteValueControl(index: index))
                    )
                }
                .disabled(!viewModel.jobs[index].scheduleEnabled)

                HStack(spacing: 8) {
                    Button {
                        viewModel.addFixedTimeForSelectedJob()
                    } label: {
                        Label(L10n.t("Time"), systemImage: "plus")
                    }
                    .controlSize(.small)

                    if viewModel.jobs[index].fixedTimes.isEmpty {
                        Text(L10n.t("no fixed times"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.jobs[index].fixedTimes) { time in
                            Button {
                                viewModel.removeFixedTimeForSelectedJob(time)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(time.label)
                                        .monospacedDigit()
                                    Image(systemName: "xmark.circle.fill")
                                        .imageScale(.small)
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        }
                    }
                }
                .disabled(!viewModel.jobs[index].scheduleEnabled)

                Text(viewModel.jobs[index].scheduleDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func compactTimeControl<PickerContent: View>(title: String, picker: PickerContent, value: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                picker
                    .labelsHidden()
                    .frame(width: 132)
                value
                    .frame(minWidth: 118, alignment: .leading)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }

    private func weekdayPreset(for job: CronJob) -> String {
        let days = Set(job.selectedWeekdays)
        if days.isEmpty { return "daily" }
        if days == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) { return "workdays" }
        if days == Set([.saturday, .sunday]) { return "weekend" }
        return "custom"
    }

    private func applyWeekdayPreset(_ preset: String) {
        switch preset {
        case "daily":
            viewModel.setWeekdaysForSelectedJob([])
        case "workdays":
            viewModel.setWeekdaysForSelectedJob([.monday, .tuesday, .wednesday, .thursday, .friday])
        case "weekend":
            viewModel.setWeekdaysForSelectedJob([.saturday, .sunday])
        default:
            break
        }
    }

    @ViewBuilder
    private func hourValueControl(index: Int) -> some View {
        switch viewModel.jobs[index].hourMode {
        case .every:
            Text(L10n.t("every hour"))
                .foregroundStyle(.secondary)
        case .specific:
            Stepper(value: binding(index, \.specificHour), in: 0...23) {
                Text("\(String(format: "%02d", viewModel.jobs[index].specificHour)):00")
                    .monospacedDigit()
            }
            .frame(width: 150)
        case .interval:
            Stepper(value: binding(index, \.hourInterval), in: 1...23) {
                Text(L10n.f("every %d h", viewModel.jobs[index].hourInterval))
                    .monospacedDigit()
            }
            .frame(width: 150)
        }
    }

    @ViewBuilder
    private func minuteValueControl(index: Int) -> some View {
        switch viewModel.jobs[index].minuteMode {
        case .every:
            Text(L10n.t("every minute"))
                .foregroundStyle(.secondary)
        case .specific:
            Stepper(value: binding(index, \.specificMinute), in: 0...59) {
                Text(L10n.f("Minute %d", viewModel.jobs[index].specificMinute))
                    .monospacedDigit()
            }
            .frame(width: 150)
        case .interval:
            Stepper(value: binding(index, \.minuteInterval), in: 1...59) {
                Text(L10n.f("every %d min", viewModel.jobs[index].minuteInterval))
                    .monospacedDigit()
            }
            .frame(width: 170)
        }
    }

    private func statusSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Status")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(L10n.t("Job enabled"), isOn: binding(index, \.isEnabled))

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.jobs[index].backend == .crontab ? L10n.t("Cron line") : "LaunchAgent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(previewText(for: viewModel.jobs[index]))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func advancedSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Advanced")) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    isAdvancedExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isAdvancedExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(isAdvancedExpanded ? L10n.t("Hide options") : L10n.t("Show options"))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                if isAdvancedExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.t("Arguments"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("--flag value", text: binding(index, \.programArgumentsText))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Text(L10n.t("Optional. For LaunchD, these are saved as additional ProgramArguments."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(L10n.t("Start immediately when loaded"), isOn: binding(index, \.runAtLoad))
                            .disabled(viewModel.jobs[index].backend == .crontab)

                        if viewModel.jobs[index].backend == .crontab {
                            Text(L10n.t("RunAtLoad is only available for LaunchAgent and LaunchDaemon jobs."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(L10n.t("Enable logging"), isOn: binding(index, \.loggingEnabled))

                        if viewModel.jobs[index].loggingEnabled {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.t("Standard Output Log"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField(defaultOutLogPath(for: viewModel.jobs[index]), text: binding(index, \.standardOutPath))
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.t("Error Log"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField(defaultErrorLogPath(for: viewModel.jobs[index]), text: binding(index, \.standardErrorPath))
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Text(L10n.t("Empty fields automatically use the default paths for this backend."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    private var footer: some View {
        let selectedIsEditable = viewModel.selectedJob.map(viewModel.isEditable) == true

        return HStack {
            Text(viewModel.statusMessage)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.t("Reload")) {
                viewModel.load()
            }
            Button(L10n.t("Run now")) {
                viewModel.runSelectedNow()
            }
            .disabled(!selectedIsEditable)
            Button(L10n.t("Save")) {
                viewModel.save()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!selectedIsEditable)
        }
    }

    private func previewText(for job: CronJob) -> String {
        switch job.backend {
        case .crontab:
            job.cronLine
        case .launchAgent:
            job.launchAgentPath.path
        case .launchDaemon:
            job.launchDaemonPath.path
        }
    }

    private func defaultOutLogPath(for job: CronJob) -> String {
        switch job.backend {
        case .crontab:
            job.defaultCronOutLogPath
        case .launchAgent:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs")
                .appendingPathComponent("\(job.label).out.log")
                .path
        case .launchDaemon:
            "/var/log/\(job.label).out.log"
        }
    }

    private func defaultErrorLogPath(for job: CronJob) -> String {
        switch job.backend {
        case .crontab:
            job.defaultCronErrorLogPath
        case .launchAgent:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs")
                .appendingPathComponent("\(job.label).err.log")
                .path
        case .launchDaemon:
            "/var/log/\(job.label).err.log"
        }
    }

    private func binding<Value>(_ index: Int, _ keyPath: WritableKeyPath<CronJob, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.jobs[index][keyPath: keyPath] },
            set: { value in
                viewModel.jobs[index][keyPath: keyPath] = value
            }
        )
    }
}

struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct JobRow: View {
    let job: CronJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(job.backend.rawValue)
                Text("·")
                Text(job.cronExpressions.first ?? job.cronExpression)
                    .monospacedDigit()
                Text("·")
                Text(job.isEnabled ? L10n.t("active") : L10n.t("inactive"))
                if !job.isManaged {
                    Text("·")
                    Text(L10n.t("external"))
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.leading, 2)
    }
}

struct BackendHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("Execution Types"))
                .font(.headline)

            helpRow(
                title: "Crontab",
                text: L10n.t("Simple user cron job. Runs in the user context. On macOS it is less modern than launchd and depends on cron being active.")
            )

            helpRow(
                title: "LaunchAgent",
                text: L10n.t("Apple launchd job for your user. Runs in the background, but reliably only inside your user session, meaning while you are logged in.")
            )

            helpRow(
                title: "LaunchDaemon",
                text: L10n.t("System-wide launchd job. Runs even without a logged-in user and fits server or Mac mini background jobs. Requires admin rights.")
            )
        }
        .padding(16)
        .frame(width: 420)
    }

    private func helpRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
