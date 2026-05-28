import AppKit
import Foundation
import SwiftUI

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
    case every = "Jede"
    case specific = "Bestimmte"
    case interval = "Alle N"

    var id: String { rawValue }
}

enum Weekday: String, CaseIterable, Identifiable {
    case every = "Jeden Tag"
    case sunday = "Sonntag"
    case monday = "Montag"
    case tuesday = "Dienstag"
    case wednesday = "Mittwoch"
    case thursday = "Donnerstag"
    case friday = "Freitag"
    case saturday = "Samstag"

    var id: String { rawValue }

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
    var minuteMode: TimeFieldMode
    var specificMinute: Int
    var minuteInterval: Int
    var hourMode: TimeFieldMode
    var specificHour: Int
    var hourInterval: Int
    var weekday: Weekday
    var selectedWeekdays: [Weekday]
    var fixedTimes: [DailyTime]
    var runAtLoad: Bool
    var loggingEnabled: Bool
    var standardOutPath: String
    var standardErrorPath: String
    var isEnabled: Bool
    var originalCommand: String?

    static func blank() -> CronJob {
        let name = "Neuer Job"
        return CronJob(
            name: name,
            label: CronJob.label(for: name),
            backend: .crontab,
            scriptPath: "",
            minuteMode: .every,
            specificMinute: 0,
            minuteInterval: 15,
            hourMode: .every,
            specificHour: 2,
            hourInterval: 1,
            weekday: .every,
            selectedWeekdays: [],
            fixedTimes: [],
            runAtLoad: false,
            loggingEnabled: false,
            standardOutPath: "",
            standardErrorPath: "",
            isEnabled: true,
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
        "\(minuteExpression) \(hourExpression) * * \(weekdayExpression)"
    }

    var weekdayExpression: String {
        let values = activeWeekdays.map(\.cronValue)
        return values.isEmpty ? "*" : values.joined(separator: ",")
    }

    var activeWeekdays: [Weekday] {
        selectedWeekdays.filter { $0 != .every }
    }

    var cronExpressions: [String] {
        if fixedTimes.isEmpty {
            return [cronExpression]
        }

        return fixedTimes.map { "\($0.minute) \($0.hour) * * \(weekdayExpression)" }
    }

    var command: String {
        originalCommand ?? shellEscaped(scriptPath)
    }

    var cronLine: String {
        cronLines.joined(separator: "\n")
    }

    var cronLines: [String] {
        cronExpressions.map { expression in
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
        return value.isEmpty ? "Neuer Job" : value
    }

    var subtitle: String {
        "\(backend.rawValue) · \(cronExpressions.first ?? cronExpression) · \(isEnabled ? "aktiv" : "inaktiv")"
    }

    var scheduleDescription: String {
        let minuteText = switch minuteMode {
        case .every: "jede Minute"
        case .specific: "Minute \(specificMinute)"
        case .interval: "alle \(minuteInterval) Minuten"
        }

        let hourText = switch hourMode {
        case .every: "jede Stunde"
        case .specific: "um \(String(format: "%02d", specificHour)) Uhr"
        case .interval: "alle \(hourInterval) Stunden"
        }

        let dayText = activeWeekdays.isEmpty ? "Jeden Tag" : activeWeekdays.map(\.rawValue).joined(separator: ", ")
        let timeText = fixedTimes.isEmpty ? "\(hourText), \(minuteText)" : fixedTimes.map(\.label).joined(separator: ", ")

        return "\(dayText), \(timeText)."
    }

    private func shellEscaped(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
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
    @Published var statusMessage = "Noch nicht geladen."
    @Published var invalidJobIDs: Set<CronJob.ID> = []

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
        jobs.allSatisfy { !$0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func load() {
        do {
            let document = try manager.load()
            let launchAgentJobs = try launchAgentManager.load()
            let launchDaemonJobs = try launchDaemonManager.load()
            jobs = document.jobs + launchAgentJobs + launchDaemonJobs
            preservedLines = document.preservedLines
            selectedJobID = jobs.first?.id
            statusMessage = jobs.isEmpty ? "Keine Cronjobs gefunden." : "\(jobs.count) Cronjob(s) geladen."
        } catch {
            statusMessage = "Crontab konnte nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    func addJob() {
        let job = CronJob.blank()
        jobs.append(job)
        selectedJobID = job.id
        statusMessage = "Neuer Job angelegt."
    }

    func deleteSelectedJob() {
        guard let selectedIndex else { return }
        jobs.remove(at: selectedIndex)
        selectedJobID = jobs.indices.contains(selectedIndex) ? jobs[selectedIndex].id : jobs.last?.id
        statusMessage = "Job entfernt. Speichern schreibt die Änderung in die Crontab."
    }

    func save() {
        guard canSave else {
            invalidJobIDs = Set(jobs
                .filter { $0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map(\.id))
            selectedJobID = invalidJobIDs.first ?? selectedJobID
            statusMessage = "Alle Jobs brauchen einen Script-Pfad."
            return
        }
        invalidJobIDs.removeAll()

        do {
            try manager.save(jobs: jobs.filter { $0.backend == .crontab }, preservedLines: preservedLines)
            try launchAgentManager.save(jobs: jobs.filter { $0.backend == .launchAgent })
            try launchDaemonManager.save(jobs: jobs.filter { $0.backend == .launchDaemon })
            statusMessage = "Jobs gespeichert."
        } catch {
            statusMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func runSelectedNow() {
        guard let selectedJob else { return }

        do {
            switch selectedJob.backend {
            case .crontab:
                try ScriptRunner.run(path: selectedJob.scriptPath)
            case .launchAgent:
                try launchAgentManager.runNow(selectedJob)
            case .launchDaemon:
                try launchDaemonManager.runNow(selectedJob)
            }
            statusMessage = "Job gestartet."
        } catch {
            statusMessage = "Start fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func chooseScriptForSelectedJob() {
        guard let selectedIndex else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Script auswählen"

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

    func load() throws -> CrontabDocument {
        let crontab = try readCrontab()
        var jobs: [CronJob] = []
        var preservedLines: [String] = []
        var insideOldManagedBlock = false

        for line in crontab.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line == beginMarker {
                insideOldManagedBlock = true
                continue
            }
            if line == endMarker {
                insideOldManagedBlock = false
                continue
            }
            if let job = parse(line: line) {
                jobs.append(job)
            } else if !insideOldManagedBlock {
                preservedLines.append(line)
            }
        }

        return CrontabDocument(jobs: jobs, preservedLines: trimmedTrailingEmptyLines(preservedLines))
    }

    func save(jobs: [CronJob], preservedLines: [String]) throws {
        let jobLines = jobs.flatMap(\.cronLines)
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
        let scriptPath = unquote(command)
        var job = CronJob.blank()
        job.backend = .crontab
        job.scriptPath = scriptPath
        job.name = URL(fileURLWithPath: scriptPath).lastPathComponent
        job.label = CronJob.label(for: job.name)
        job.isEnabled = isEnabled
        job.originalCommand = command == job.command ? nil : command
        applyMinute(parts[0], to: &job)
        applyHour(parts[1], to: &job)
        job.selectedWeekdays = parseWeekdays(parts[4])
        return job
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
    static func run(path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = []
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
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "plist" }
            .compactMap(loadJob)
    }

    func save(jobs: [CronJob]) throws {
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let existing = try load()
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
        job.name = displayName(from: label)
        job.scriptPath = scriptPath
        job.isEnabled = true

        job.runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        job.standardOutPath = (plist["StandardOutPath"] as? String) ?? ""
        job.standardErrorPath = (plist["StandardErrorPath"] as? String) ?? ""
        job.loggingEnabled = !job.standardOutPath.isEmpty || !job.standardErrorPath.isEmpty

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
            "ProgramArguments": [job.scriptPath],
            "RunAtLoad": job.runAtLoad
        ]

        if job.loggingEnabled {
            plist["StandardOutPath"] = job.standardOutPath.isEmpty ? logPath(for: job, suffix: "out") : job.standardOutPath
            plist["StandardErrorPath"] = job.standardErrorPath.isEmpty ? logPath(for: job, suffix: "err") : job.standardErrorPath
        }

        if let interval = startInterval(for: job) {
            plist["StartInterval"] = interval
        } else {
            plist["StartCalendarInterval"] = startCalendarIntervals(for: job)
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
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "plist" }
            .compactMap(loadJob)
    }

    func save(jobs: [CronJob]) throws {
        let existing = try load()
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
        job.name = displayName(from: label)
        job.scriptPath = scriptPath
        job.isEnabled = true

        job.runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        job.standardOutPath = (plist["StandardOutPath"] as? String) ?? ""
        job.standardErrorPath = (plist["StandardErrorPath"] as? String) ?? ""
        job.loggingEnabled = !job.standardOutPath.isEmpty || !job.standardErrorPath.isEmpty

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
            "ProgramArguments": [job.scriptPath],
            "RunAtLoad": job.runAtLoad
        ]

        if job.loggingEnabled {
            plist["StandardOutPath"] = job.standardOutPath.isEmpty ? "/var/log/\(job.label).out.log" : job.standardOutPath
            plist["StandardErrorPath"] = job.standardErrorPath.isEmpty ? "/var/log/\(job.label).err.log" : job.standardErrorPath
        }

        if let interval = startInterval(for: job) {
            plist["StartInterval"] = interval
        } else {
            plist["StartCalendarInterval"] = startCalendarIntervals(for: job)
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
            HStack {
                Text("Cronjobs")
                    .font(.title2.bold())
                Spacer()
                Text("\(viewModel.jobs.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            List(selection: $viewModel.selectedJobID) {
                ForEach(viewModel.jobs) { job in
                    JobRow(job: job)
                        .tag(job.id)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 10))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack(spacing: 8) {
                Button {
                    viewModel.addJob()
                } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
                Button {
                    viewModel.deleteSelectedJob()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
                .disabled(viewModel.selectedJobID == nil)
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
                    header
                    jobBasicsSection(index: index)
                    scriptSection(index: index)
                    scheduleSection(index: index)
                    statusSection(index: index)
                    footer
                }
                .padding(24)
            }
        } else {
            VStack(spacing: 12) {
                Text("Kein Job ausgewählt")
                    .font(.title2.bold())
                Button("Job hinzufügen") {
                    viewModel.addJob()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Crontab Editor")
                .font(.largeTitle.bold())
            Text("Liest Crontab- und LaunchAgent-Jobs und speichert sie in das gewählte Backend.")
                .foregroundStyle(.secondary)
        }
    }

    private func jobBasicsSection(index: Int) -> some View {
        SectionBox(title: "Job") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
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
                            Text("Typ")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Button {
                                isBackendHelpVisible.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Unterschiede zwischen Crontab, LaunchAgent und LaunchDaemon")
                            .popover(isPresented: $isBackendHelpVisible, arrowEdge: .top) {
                                BackendHelpView()
                            }
                        }

                        Picker("Typ", selection: binding(index, \.backend)) {
                            ForEach(JobBackend.allCases) { backend in
                                Text(backend.rawValue).tag(backend)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                }

                Text("LaunchD-ID: \(viewModel.jobs[index].label)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(viewModel.jobs[index].backend == .crontab
                    ? "Speichert den Job in deiner User-Crontab."
                    : viewModel.jobs[index].backend == .launchAgent
                        ? "Speichert den Job als LaunchAgent unter ~/Library/LaunchAgents."
                        : "Speichert den Job als LaunchDaemon unter /Library/LaunchDaemons. macOS fragt nach Admin-Rechten.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scriptSection(index: Int) -> some View {
        SectionBox(title: "Script") {
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
                    Button("Auswählen") {
                        viewModel.chooseScriptForSelectedJob()
                    }
                }

                if isInvalid {
                    Text("Script-Pfad fehlt. Bitte Datei auswählen oder Pfad eintragen.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func scheduleSection(index: Int) -> some View {
        SectionBox(title: "Zeitplan") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Picker("Tage", selection: Binding(
                        get: { weekdayPreset(for: viewModel.jobs[index]) },
                        set: { applyWeekdayPreset($0) }
                    )) {
                        Text("Täglich").tag("daily")
                        Text("Werktage").tag("workdays")
                        Text("Wochenende").tag("weekend")
                        Text("Eigene").tag("custom")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 330)

                    HStack(spacing: 4) {
                        ForEach([Weekday.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]) { weekday in
                            Toggle(weekday.rawValue.prefix(2).description, isOn: Binding(
                                get: { viewModel.jobs[index].selectedWeekdays.contains(weekday) },
                                set: { _ in viewModel.toggleWeekdayForSelectedJob(weekday) }
                            ))
                            .toggleStyle(.button)
                            .controlSize(.small)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    compactTimeControl(
                        title: "Stunde",
                        picker: Picker("Stunde", selection: binding(index, \.hourMode)) {
                            ForEach(TimeFieldMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        },
                        value: AnyView(hourValueControl(index: index))
                    )

                    compactTimeControl(
                        title: "Minute",
                        picker: Picker("Minute", selection: binding(index, \.minuteMode)) {
                            ForEach(TimeFieldMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        },
                        value: AnyView(minuteValueControl(index: index))
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.addFixedTimeForSelectedJob()
                    } label: {
                        Label("Uhrzeit", systemImage: "plus")
                    }
                    .controlSize(.small)

                    if viewModel.jobs[index].fixedTimes.isEmpty {
                        Text("keine festen Uhrzeiten")
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
            Text("jede Stunde")
                .foregroundStyle(.secondary)
        case .specific:
            Stepper(value: binding(index, \.specificHour), in: 0...23) {
                Text("\(String(format: "%02d", viewModel.jobs[index].specificHour)):00")
                    .monospacedDigit()
            }
            .frame(width: 150)
        case .interval:
            Stepper(value: binding(index, \.hourInterval), in: 1...23) {
                Text("alle \(viewModel.jobs[index].hourInterval) h")
                    .monospacedDigit()
            }
            .frame(width: 150)
        }
    }

    @ViewBuilder
    private func minuteValueControl(index: Int) -> some View {
        switch viewModel.jobs[index].minuteMode {
        case .every:
            Text("jede Minute")
                .foregroundStyle(.secondary)
        case .specific:
            Stepper(value: binding(index, \.specificMinute), in: 0...59) {
                Text("Minute \(viewModel.jobs[index].specificMinute)")
                    .monospacedDigit()
            }
            .frame(width: 150)
        case .interval:
            Stepper(value: binding(index, \.minuteInterval), in: 1...59) {
                Text("alle \(viewModel.jobs[index].minuteInterval) min")
                    .monospacedDigit()
            }
            .frame(width: 170)
        }
    }

    private func statusSection(index: Int) -> some View {
        SectionBox(title: "Status") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Job aktiv", isOn: binding(index, \.isEnabled))
                DisclosureGroup("Advanced", isExpanded: $isAdvancedExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Beim Laden sofort starten", isOn: binding(index, \.runAtLoad))

                        Toggle("Logging aktivieren", isOn: binding(index, \.loggingEnabled))

                        if viewModel.jobs[index].loggingEnabled {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Standard Output Log")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField(defaultOutLogPath(for: viewModel.jobs[index]), text: binding(index, \.standardOutPath))
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Error Log")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField(defaultErrorLogPath(for: viewModel.jobs[index]), text: binding(index, \.standardErrorPath))
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Text("Leere Felder verwenden automatisch die Standardpfade für dieses Backend.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.jobs[index].backend == .crontab ? "Cron-Zeile" : "LaunchAgent")
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

    private var footer: some View {
        HStack {
            Text(viewModel.statusMessage)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Neu laden") {
                viewModel.load()
            }
            Button("Run now") {
                viewModel.runSelectedNow()
            }
            .disabled(viewModel.selectedJobID == nil)
            Button("Speichern") {
                viewModel.save()
            }
            .keyboardShortcut(.defaultAction)
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
            ""
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
            ""
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
                Text(job.isEnabled ? "aktiv" : "inaktiv")
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
            Text("Ausführungsarten")
                .font(.headline)

            helpRow(
                title: "Crontab",
                text: "Einfacher User-Cronjob. Läuft im User-Kontext. Auf macOS weniger modern als launchd und abhängig davon, dass cron aktiv arbeitet."
            )

            helpRow(
                title: "LaunchAgent",
                text: "Apple-LaunchD-Job für deinen Benutzer. Läuft im Hintergrund, aber nur zuverlässig innerhalb deiner User-Session, also wenn du eingeloggt bist."
            )

            helpRow(
                title: "LaunchDaemon",
                text: "Systemweiter LaunchD-Job. Läuft auch ohne eingeloggten Benutzer und ist passend für Server-/Mac-mini-Hintergrundjobs. Benötigt Admin-Rechte."
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
