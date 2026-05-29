import AppKit
import Foundation
import SwiftUI

enum L10n {
    private static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "CrontabEditor_CrontabEditor", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        return .main
    }()

    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
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

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button(L10n.t("Crontab Editor Help")) {
                    if let url = URL(string: "https://github.com/morja/CrontabEditor#readme") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
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

enum ScheduleKind: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case interval = "Interval"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
}

enum IntervalUnit: String, CaseIterable, Identifiable {
    case seconds = "Seconds"
    case minutes = "Minutes"
    case hours = "Hours"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
}

enum ShellInterpreter: String, CaseIterable, Identifiable {
    case sh = "/bin/sh"
    case bash = "/bin/bash"
    case zsh = "/bin/zsh"
    case custom = "custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sh: "sh"
        case .bash: "bash"
        case .zsh: "zsh"
        case .custom: L10n.t("Custom")
        }
    }
}

struct CronJob: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var label: String
    var backend: JobBackend
    var scriptPath: String
    var programArgumentsText: String
    var useInterpreter: Bool
    var interpreterPath: String
    var interpreterArgumentsText: String
    var scheduleKind: ScheduleKind
    var intervalValue: Int
    var intervalUnit: IntervalUnit
    var minuteMode: TimeFieldMode
    var specificMinute: Int
    var minuteInterval: Int
    var hourMode: TimeFieldMode
    var specificHour: Int
    var hourInterval: Int
    var scheduleEnabled: Bool
    var weekday: Weekday
    var selectedWeekdays: [Weekday]
    var selectedMonthDays: [Int]
    var selectedMonths: [Int]
    var fixedTimes: [DailyTime]
    var runAtLoad: Bool
    var watchPathsText: String
    var queueDirectoriesText: String
    var startOnMount: Bool
    var keepAlive: Bool
    var workingDirectory: String
    var environmentVariablesText: String
    var throttleIntervalEnabled: Bool
    var throttleInterval: Int
    var loggingEnabled: Bool
    var standardOutPath: String
    var standardErrorPath: String
    var isEnabled: Bool
    var isInstalled: Bool
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
            useInterpreter: false,
            interpreterPath: ShellInterpreter.zsh.rawValue,
            interpreterArgumentsText: "",
            scheduleKind: .calendar,
            intervalValue: 15,
            intervalUnit: .minutes,
            minuteMode: .every,
            specificMinute: 0,
            minuteInterval: 15,
            hourMode: .every,
            specificHour: 2,
            hourInterval: 1,
            scheduleEnabled: true,
            weekday: .every,
            selectedWeekdays: [],
            selectedMonthDays: [],
            selectedMonths: [],
            fixedTimes: [],
            runAtLoad: false,
            watchPathsText: "",
            queueDirectoriesText: "",
            startOnMount: false,
            keepAlive: false,
            workingDirectory: "",
            environmentVariablesText: "",
            throttleIntervalEnabled: false,
            throttleInterval: 10,
            loggingEnabled: false,
            standardOutPath: "",
            standardErrorPath: "",
            isEnabled: true,
            isInstalled: false,
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
        return "\(minuteExpression) \(hourExpression) \(monthDayExpression) \(monthExpression) \(weekdayExpression)"
    }

    var weekdayExpression: String {
        let values = activeWeekdays.map(\.cronValue)
        return values.isEmpty ? "*" : values.joined(separator: ",")
    }

    var monthDayExpression: String {
        selectedMonthDays.isEmpty ? "*" : selectedMonthDays.sorted().map(String.init).joined(separator: ",")
    }

    var monthExpression: String {
        selectedMonths.isEmpty ? "*" : selectedMonths.sorted().map(String.init).joined(separator: ",")
    }

    var activeWeekdays: [Weekday] {
        selectedWeekdays.filter { $0 != .every }
    }

    var startIntervalSeconds: Int {
        let value = max(intervalValue, 1)
        switch intervalUnit {
        case .seconds: return value
        case .minutes: return value * 60
        case .hours: return value * 60 * 60
        }
    }

    var cronExpressions: [String] {
        guard scheduleEnabled else { return [] }
        guard scheduleKind == .calendar else { return [] }
        if fixedTimes.isEmpty {
            return [cronExpression]
        }

        return fixedTimes.map { "\($0.minute) \($0.hour) \(monthDayExpression) \(monthExpression) \(weekdayExpression)" }
    }

    var command: String {
        let base = launchdProgramArguments.map(shellEscaped).joined(separator: " ")
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

    var interpreterArguments: [String] {
        parseArguments(interpreterArgumentsText)
    }

    var executablePath: String {
        useInterpreter ? interpreterPath : scriptPath
    }

    var launchdProgramArguments: [String] {
        if useInterpreter {
            return [interpreterPath] + interpreterArguments + [scriptPath] + programArguments
        }

        return [scriptPath] + programArguments
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
        "\(backend.rawValue) · \(cronExpressions.first ?? cronExpression) · \(statusTitle)"
    }

    var statusTitle: String {
        guard isInstalled else { return L10n.t("new") }
        return isEnabled ? L10n.t("active") : L10n.t("inactive")
    }

    var scheduleDescription: String {
        guard scheduleEnabled else {
            return runAtLoad
                ? L10n.t("No schedule. The job starts when loaded and via Run now.")
                : L10n.t("No schedule. The job starts only via Run now.")
        }

        if scheduleKind == .interval {
            return L10n.f("Every %d %@.", intervalValue, intervalUnit.title.lowercased())
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
        let monthDayText = selectedMonthDays.isEmpty ? "" : L10n.f(" on day(s) %@", selectedMonthDays.sorted().map(String.init).joined(separator: ", "))
        let monthText = selectedMonths.isEmpty ? "" : L10n.f(" in month(s) %@", selectedMonths.sorted().map(String.init).joined(separator: ", "))
        let timeText = fixedTimes.isEmpty ? "\(hourText), \(minuteText)" : fixedTimes.map(\.label).joined(separator: ", ")

        return "\(dayText)\(monthDayText)\(monthText), \(timeText)."
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

fileprivate func applyProgramArguments(_ arguments: [String], to job: inout CronJob) {
    guard let first = arguments.first else { return }

    if isKnownInterpreter(first), let scriptIndex = arguments.dropFirst().firstIndex(where: { !$0.hasPrefix("-") }) {
        job.useInterpreter = true
        job.interpreterPath = first
        job.interpreterArgumentsText = arguments[1..<scriptIndex].map(quoteArgument).joined(separator: " ")
        job.scriptPath = arguments[scriptIndex]
        job.programArgumentsText = arguments.dropFirst(scriptIndex + 1).map(quoteArgument).joined(separator: " ")
    } else {
        job.useInterpreter = false
        job.scriptPath = first
        job.programArgumentsText = arguments.dropFirst().map(quoteArgument).joined(separator: " ")
    }
}

fileprivate func quoteArgument(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

fileprivate func isKnownInterpreter(_ value: String) -> Bool {
    if (ShellInterpreter.allCases
        .filter { $0 != .custom }
        .map(\.rawValue)
        .contains(value)) {
        return true
    }

    return ["sh", "bash", "zsh", "fish"].contains(URL(fileURLWithPath: value).lastPathComponent)
}

fileprivate func lines(from text: String) -> [String] {
    text
        .split(whereSeparator: \.isNewline)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

fileprivate func keyValueLines(from text: String) -> [String: String] {
    Dictionary(uniqueKeysWithValues: lines(from: text).compactMap { line in
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    })
}

@MainActor
final class CrontabViewModel: ObservableObject {
    @Published var jobs: [CronJob] = []
    @Published var selectedJobID: CronJob.ID?
    @Published var statusMessage = L10n.t("Not loaded yet.")
    @Published var invalidJobIDs: Set<CronJob.ID> = []
    @Published var showExternalJobs = false
    @Published var hasUnsavedChanges = false

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
        jobs.filter(isEditable).allSatisfy {
            !$0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (!$0.useInterpreter || !$0.interpreterPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
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
        let previousSelectedID = selectedJobID
        let previousSelectionKey = selectedJob.map(selectionKey)

        do {
            let document = try manager.load()
            let launchAgentJobs = try launchAgentManager.load()
            let launchDaemonJobs = try launchDaemonManager.load()
            jobs = document.jobs + launchAgentJobs + launchDaemonJobs
            preservedLines = document.preservedLines
            if let previousSelectedID,
               visibleJobs.contains(where: { $0.id == previousSelectedID }) {
                selectedJobID = previousSelectedID
            } else if let previousSelectionKey,
                      let matchingJob = visibleJobs.first(where: { selectionKey(for: $0) == previousSelectionKey }) {
                selectedJobID = matchingJob.id
            } else {
                selectedJobID = defaultSelectedJobID
            }
            hasUnsavedChanges = false
            statusMessage = jobs.isEmpty ? L10n.t("No cron jobs found.") : L10n.f("%d cron job(s) loaded.", jobs.count)
        } catch {
            statusMessage = L10n.f("Could not read crontab: %@", error.localizedDescription)
        }
    }

    private var defaultSelectedJobID: CronJob.ID? {
        managedJobs.first?.id ?? (showExternalJobs ? externalJobs.first?.id : nil)
    }

    private func selectionKey(for job: CronJob) -> String {
        if job.backend == .crontab {
            return "crontab|\(job.isManaged)|\(job.name)|\(job.originalCommand ?? job.cronLine)"
        }

        return "\(job.backend.rawValue)|\(job.label)"
    }

    func addJob() {
        let job = CronJob.blank()
        jobs.append(job)
        selectedJobID = job.id
        hasUnsavedChanges = true
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
        hasUnsavedChanges = true
        statusMessage = L10n.t("Job removed. Save writes the change to the crontab.")
    }

    @discardableResult
    func save() -> Bool {
        let previousSelectedID = selectedJobID

        guard canSave else {
            invalidJobIDs = Set(jobs
                .filter(isEditable)
                .filter {
                    $0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || ($0.useInterpreter && $0.interpreterPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .map(\.id))
            selectedJobID = invalidJobIDs.first ?? selectedJobID
            statusMessage = L10n.t("All jobs need a script path and selected interpreter path.")
            return false
        }
        invalidJobIDs.removeAll()

        do {
            let backupURL = try manager.save(jobs: jobs.filter { $0.backend == .crontab }, preservedLines: preservedLines)
            try launchAgentManager.save(jobs: jobs.filter { $0.backend == .launchAgent && $0.isManaged })
            try launchDaemonManager.save(jobs: jobs.filter { $0.backend == .launchDaemon && $0.isManaged })
            markEditableJobsInstalled()
            restoreSelection(previousSelectedID)
            hasUnsavedChanges = false
            statusMessage = L10n.f("Jobs saved. Backup: %@", backupURL.lastPathComponent)
            return true
        } catch {
            statusMessage = L10n.f("Save failed: %@", error.localizedDescription)
            return false
        }
    }

    private func markEditableJobsInstalled() {
        for index in jobs.indices where isEditable(jobs[index]) {
            jobs[index].isInstalled = true
        }
    }

    private func restoreSelection(_ jobID: CronJob.ID?) {
        guard let jobID, visibleJobs.contains(where: { $0.id == jobID }) else { return }
        selectedJobID = jobID
    }

    func runSelectedNow() {
        guard let selectedJob else { return }

        do {
            switch selectedJob.backend {
            case .crontab:
                try ScriptRunner.run(path: selectedJob.executablePath, arguments: Array(selectedJob.launchdProgramArguments.dropFirst()))
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
            hasUnsavedChanges = true
        }
    }

    func updateSelectedJob(_ update: (inout CronJob) -> Void) {
        guard let selectedIndex else { return }
        update(&jobs[selectedIndex])
        hasUnsavedChanges = true
    }

    func updateSelectedJobName(_ name: String) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].name = name
        jobs[selectedIndex].label = CronJob.label(for: name)
        hasUnsavedChanges = true
    }

    func setBackendForSelectedJob(_ backend: JobBackend) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].backend = backend
        if backend == .crontab {
            jobs[selectedIndex].runAtLoad = false
            jobs[selectedIndex].scheduleKind = .calendar
        }
        hasUnsavedChanges = true
    }

    func setWeekdaysForSelectedJob(_ weekdays: [Weekday]) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].selectedWeekdays = weekdays
        hasUnsavedChanges = true
    }

    func toggleMonthDayForSelectedJob(_ day: Int) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedMonthDays.contains(day) {
            jobs[selectedIndex].selectedMonthDays.removeAll { $0 == day }
        } else {
            jobs[selectedIndex].selectedMonthDays.append(day)
        }
        hasUnsavedChanges = true
    }

    func toggleMonthForSelectedJob(_ month: Int) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedMonths.contains(month) {
            jobs[selectedIndex].selectedMonths.removeAll { $0 == month }
        } else {
            jobs[selectedIndex].selectedMonths.append(month)
        }
        hasUnsavedChanges = true
    }

    func toggleWeekdayForSelectedJob(_ weekday: Weekday) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedWeekdays.contains(weekday) {
            jobs[selectedIndex].selectedWeekdays.removeAll { $0 == weekday }
        } else {
            jobs[selectedIndex].selectedWeekdays.append(weekday)
        }
        hasUnsavedChanges = true
    }

    func addFixedTimeForSelectedJob() {
        guard let selectedIndex else { return }
        jobs[selectedIndex].fixedTimes.append(DailyTime(hour: jobs[selectedIndex].specificHour, minute: jobs[selectedIndex].specificMinute))
        hasUnsavedChanges = true
    }

    func removeFixedTimeForSelectedJob(_ time: DailyTime) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].fixedTimes.removeAll { $0.id == time.id }
        hasUnsavedChanges = true
    }

    func markDirty() {
        hasUnsavedChanges = true
    }
}

struct CrontabManager {
    private let beginMarker = "# CrontabEditor BEGIN"
    private let endMarker = "# CrontabEditor END"
    private let jobMarkerPrefix = "# CrontabEditor JOB "

    static var backupDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrontabEditor", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    func load() throws -> CrontabDocument {
        parse(crontab: try readCrontab())
    }

    func parse(crontab: String) -> CrontabDocument {
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
                    managedJob.isInstalled = true
                    managedJob.name = managedName
                    managedJob.label = CronJob.label(for: managedName)
                    jobs.append(managedJob)
                    nextManagedName = nil
                } else if insideOldManagedBlock {
                    var managedJob = job
                    managedJob.isManaged = true
                    managedJob.isInstalled = true
                    jobs.append(managedJob)
                } else {
                    var externalJob = job
                    externalJob.isInstalled = true
                    jobs.append(externalJob)
                }
            } else if !insideOldManagedBlock {
                preservedLines.append(line)
            }
        }

        return CrontabDocument(jobs: jobs, preservedLines: trimmedTrailingEmptyLines(preservedLines))
    }

    @discardableResult
    func save(jobs: [CronJob], preservedLines: [String]) throws -> URL {
        let currentCrontab = try readCrontab()
        let backupURL = try backup(crontab: currentCrontab)
        try install(crontab: render(jobs: jobs, preservedLines: preservedLines))
        return backupURL
    }

    func render(jobs: [CronJob], preservedLines: [String]) -> String {
        let jobLines = jobs.flatMap { job in
            job.isManaged ? ["\(jobMarkerPrefix)\(job.name)"] + job.cronLines : job.cronLines
        }
        var lines = trimmedTrailingEmptyLines(preservedLines)

        if !lines.isEmpty && !jobLines.isEmpty {
            lines.append("")
        }

        lines.append(contentsOf: jobLines)
        return lines.joined(separator: "\n") + "\n"
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

    private func backup(crontab: String) throws -> URL {
        let directory = Self.backupDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let url = directory.appendingPathComponent("crontab-\(formatter.string(from: Date()))-\(UUID().uuidString).backup")
        try crontab.write(to: url, atomically: true, encoding: .utf8)
        try pruneBackups(in: directory, keeping: 10)
        return url
    }

    private func pruneBackups(in directory: URL, keeping limit: Int) throws {
        let backups = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("crontab-") && $0.pathExtension == "backup" }
        .sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }

        for backup in backups.dropFirst(limit) {
            try FileManager.default.removeItem(at: backup)
        }
    }

    private func parse(line: String) -> CronJob? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let isEnabled = !trimmed.hasPrefix("#")
        let activeLine = isEnabled ? trimmed : trimmed.replacing(/^#\s*/, with: "")
        let parts = activeLine.split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 6,
              isCronTime(parts[0]),
              isCronTime(parts[1]),
              isSupportedNumberList(parts[2], range: 1...31),
              isSupportedNumberList(parts[3], range: 1...12),
              isSupportedWeekday(parts[4]) else {
            return nil
        }

        let command = parts[5]
        let commandParts = parseCommand(command)
        guard isSupportedCronCommandParts(commandParts) else {
            return nil
        }

        let parsedCommand = parseCronCommandParts(commandParts)
        var job = CronJob.blank()
        job.backend = .crontab
        job.isManaged = false
        job.isInstalled = true
        applyProgramArguments(parsedCommand.arguments, to: &job)
        job.loggingEnabled = parsedCommand.outLogPath != nil || parsedCommand.errorLogPath != nil
        job.standardOutPath = parsedCommand.outLogPath ?? ""
        job.standardErrorPath = parsedCommand.errorLogPath ?? ""
        job.name = URL(fileURLWithPath: job.scriptPath).lastPathComponent
        job.label = CronJob.label(for: job.name)
        job.isEnabled = isEnabled
        job.originalCommand = nil
        applyMinute(parts[0], to: &job)
        applyHour(parts[1], to: &job)
        job.selectedMonthDays = parseNumberList(parts[2])
        job.selectedMonths = parseNumberList(parts[3])
        job.selectedWeekdays = parseWeekdays(parts[4])
        return job
    }

    private func parseCronCommandParts(_ commandParts: [String]) -> (arguments: [String], outLogPath: String?, errorLogPath: String?) {
        var arguments: [String] = []
        var outLogPath: String?
        var errorLogPath: String?
        var index = 0

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

    private func applyProgramArguments(_ arguments: [String], to job: inout CronJob) {
        guard let first = arguments.first else { return }

        if isKnownInterpreter(first), let scriptIndex = arguments.dropFirst().firstIndex(where: { !$0.hasPrefix("-") }) {
            job.useInterpreter = true
            job.interpreterPath = first
            job.interpreterArgumentsText = arguments[1..<scriptIndex].map(shellEscaped).joined(separator: " ")
            job.scriptPath = arguments[scriptIndex]
            job.programArgumentsText = arguments.dropFirst(scriptIndex + 1).map(shellEscaped).joined(separator: " ")
        } else {
            job.useInterpreter = false
            job.scriptPath = first
            job.programArgumentsText = arguments.dropFirst().map(shellEscaped).joined(separator: " ")
        }
    }

    private func isKnownInterpreter(_ value: String) -> Bool {
        if (ShellInterpreter.allCases
            .filter { $0 != .custom }
            .map(\.rawValue)
            .contains(value)) {
            return true
        }

        return ["sh", "bash", "zsh", "fish"].contains(URL(fileURLWithPath: value).lastPathComponent)
    }

    private func isSupportedCronCommandParts(_ commandParts: [String]) -> Bool {
        guard let executable = commandParts.first,
              !executable.isEmpty,
              !isShellControlToken(executable),
              !executable.contains("="),
              !executable.hasPrefix(">"),
              !executable.hasPrefix("2>"),
              !executable.hasPrefix("&>") else {
            return false
        }

        var index = 1
        while index < commandParts.count {
            let part = commandParts[index]

            if part == ">>" || part == "2>>" {
                guard index + 1 < commandParts.count else { return false }
                index += 2
                continue
            }

            if isShellControlToken(part) || part.hasPrefix(">") || part.hasPrefix("2>") || part.hasPrefix("&>") {
                return false
            }

            index += 1
        }

        return true
    }

    private func isShellControlToken(_ value: String) -> Bool {
        ["&&", "||", ";", "|", "<", "<<", "<<<", "&"].contains(value)
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

    private func isSupportedWeekday(_ value: String) -> Bool {
        value == "*" || value.split(separator: ",").allSatisfy { weekday in
            Int(weekday).map { 0...6 ~= $0 } == true
        }
    }

    private func isSupportedNumberList(_ value: String, range: ClosedRange<Int>) -> Bool {
        value == "*" || value.split(separator: ",").allSatisfy { part in
            Int(part).map { range ~= $0 } == true
        }
    }

    private func parseNumberList(_ value: String) -> [Int] {
        guard value != "*" else { return [] }
        return value.split(separator: ",").compactMap { Int($0) }.sorted()
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
            !arguments.isEmpty
        else {
            return nil
        }

        var job = CronJob.blank()
        job.backend = .launchAgent
        job.label = label
        job.isManaged = label.hasPrefix(prefix)
        job.name = job.isManaged ? displayName(from: label) : label
        applyProgramArguments(arguments, to: &job)
        job.isEnabled = true
        job.isInstalled = true

        job.runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        job.standardOutPath = (plist["StandardOutPath"] as? String) ?? ""
        job.standardErrorPath = (plist["StandardErrorPath"] as? String) ?? ""
        job.loggingEnabled = !job.standardOutPath.isEmpty || !job.standardErrorPath.isEmpty
        job.scheduleEnabled = plist["StartInterval"] != nil || plist["StartCalendarInterval"] != nil
        job.watchPathsText = ((plist["WatchPaths"] as? [String]) ?? []).joined(separator: "\n")
        job.queueDirectoriesText = ((plist["QueueDirectories"] as? [String]) ?? []).joined(separator: "\n")
        job.startOnMount = (plist["StartOnMount"] as? Bool) ?? false
        job.keepAlive = (plist["KeepAlive"] as? Bool) ?? false
        job.workingDirectory = (plist["WorkingDirectory"] as? String) ?? ""
        if let environment = plist["EnvironmentVariables"] as? [String: String] {
            job.environmentVariablesText = environment.keys.sorted().map { "\($0)=\(environment[$0] ?? "")" }.joined(separator: "\n")
        }
        if let throttleInterval = plist["ThrottleInterval"] as? Int {
            job.throttleIntervalEnabled = true
            job.throttleInterval = max(throttleInterval, 1)
        }

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

        if !job.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            plist["WorkingDirectory"] = job.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let environment = keyValueLines(from: job.environmentVariablesText)
        if !environment.isEmpty {
            plist["EnvironmentVariables"] = environment
        }
        let watchPaths = lines(from: job.watchPathsText)
        if !watchPaths.isEmpty {
            plist["WatchPaths"] = watchPaths
        }
        let queueDirectories = lines(from: job.queueDirectoriesText)
        if !queueDirectories.isEmpty {
            plist["QueueDirectories"] = queueDirectories
        }
        if job.startOnMount {
            plist["StartOnMount"] = true
        }
        if job.keepAlive {
            plist["KeepAlive"] = true
        }
        if job.throttleIntervalEnabled {
            plist["ThrottleInterval"] = max(job.throttleInterval, 1)
        }

        if job.scheduleEnabled {
            if job.scheduleKind == .interval {
                plist["StartInterval"] = job.startIntervalSeconds
            } else {
                plist["StartCalendarInterval"] = startCalendarIntervals(for: job)
            }
        }

        return plist
    }

    private func startInterval(for job: CronJob) -> Int? {
        guard job.selectedMonthDays.isEmpty, job.selectedMonths.isEmpty else { return nil }
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
        let times = job.fixedTimes

        if times.isEmpty {
            let intervals = calendarDimensions(for: job).map { dimension in
                startCalendarInterval(for: job, weekday: dimension.weekday, monthDay: dimension.monthDay, month: dimension.month)
            }
            return intervals.count == 1 ? intervals[0] : intervals
        }

        let intervals = calendarDimensions(for: job).flatMap { dimension in
            times.map { time in
                var calendar: [String: Int] = ["Hour": time.hour, "Minute": time.minute]
                if let weekday = dimension.weekday, let value = Int(weekday.cronValue) {
                    calendar["Weekday"] = value == 0 ? 7 : value
                }
                if let monthDay = dimension.monthDay {
                    calendar["Day"] = monthDay
                }
                if let month = dimension.month {
                    calendar["Month"] = month
                }
                return calendar
            }
        }

        return intervals.count == 1 ? intervals[0] : intervals
    }

    private func calendarDimensions(for job: CronJob) -> [(weekday: Weekday?, monthDay: Int?, month: Int?)] {
        let weekdays = job.activeWeekdays.isEmpty ? [Weekday?.none] : job.activeWeekdays.map(Optional.some)
        let monthDays = job.selectedMonthDays.isEmpty ? [Int?.none] : job.selectedMonthDays.sorted().map(Optional.some)
        let months = job.selectedMonths.isEmpty ? [Int?.none] : job.selectedMonths.sorted().map(Optional.some)

        return weekdays.flatMap { weekday in
            monthDays.flatMap { monthDay in
                months.map { month in
                    (weekday: weekday, monthDay: monthDay, month: month)
                }
            }
        }
    }

    private func startCalendarInterval(for job: CronJob, weekday selectedWeekday: Weekday?, monthDay: Int?, month: Int?) -> [String: Int] {
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
        if let monthDay {
            calendar["Day"] = monthDay
        }
        if let month {
            calendar["Month"] = month
        }

        if calendar.isEmpty {
            calendar["Minute"] = 0
        }

        return calendar
    }

    private func applyStartInterval(_ interval: Int, to job: inout CronJob) {
        job.scheduleKind = .interval
        if interval % 3600 == 0 {
            job.intervalUnit = .hours
            job.intervalValue = max(interval / 3600, 1)
        } else if interval % 60 == 0 {
            job.intervalUnit = .minutes
            job.intervalValue = max(interval / 60, 1)
        } else {
            job.intervalUnit = .seconds
            job.intervalValue = max(interval, 1)
        }

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
        job.scheduleKind = .calendar
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
        if let day = calendar["Day"] {
            job.selectedMonthDays = [min(max(day, 1), 31)]
        }
        if let month = calendar["Month"] {
            job.selectedMonths = [min(max(month, 1), 12)]
        }
    }

    private func applyCalendars(_ calendars: [[String: Int]], to job: inout CronJob) {
        job.scheduleKind = .calendar
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
        job.selectedMonthDays = Array(Set(calendars.compactMap { $0["Day"] }.map { min(max($0, 1), 31) })).sorted()
        job.selectedMonths = Array(Set(calendars.compactMap { $0["Month"] }.map { min(max($0, 1), 12) })).sorted()
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
            !arguments.isEmpty
        else {
            return nil
        }

        var job = CronJob.blank()
        job.backend = .launchDaemon
        job.label = label
        job.isManaged = label.hasPrefix(prefix)
        job.name = job.isManaged ? displayName(from: label) : label
        applyProgramArguments(arguments, to: &job)
        job.isEnabled = true
        job.isInstalled = true

        job.runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        job.standardOutPath = (plist["StandardOutPath"] as? String) ?? ""
        job.standardErrorPath = (plist["StandardErrorPath"] as? String) ?? ""
        job.loggingEnabled = !job.standardOutPath.isEmpty || !job.standardErrorPath.isEmpty
        job.scheduleEnabled = plist["StartInterval"] != nil || plist["StartCalendarInterval"] != nil
        job.watchPathsText = ((plist["WatchPaths"] as? [String]) ?? []).joined(separator: "\n")
        job.queueDirectoriesText = ((plist["QueueDirectories"] as? [String]) ?? []).joined(separator: "\n")
        job.startOnMount = (plist["StartOnMount"] as? Bool) ?? false
        job.keepAlive = (plist["KeepAlive"] as? Bool) ?? false
        job.workingDirectory = (plist["WorkingDirectory"] as? String) ?? ""
        if let environment = plist["EnvironmentVariables"] as? [String: String] {
            job.environmentVariablesText = environment.keys.sorted().map { "\($0)=\(environment[$0] ?? "")" }.joined(separator: "\n")
        }
        if let throttleInterval = plist["ThrottleInterval"] as? Int {
            job.throttleIntervalEnabled = true
            job.throttleInterval = max(throttleInterval, 1)
        }

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

        if !job.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            plist["WorkingDirectory"] = job.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let environment = keyValueLines(from: job.environmentVariablesText)
        if !environment.isEmpty {
            plist["EnvironmentVariables"] = environment
        }
        let watchPaths = lines(from: job.watchPathsText)
        if !watchPaths.isEmpty {
            plist["WatchPaths"] = watchPaths
        }
        let queueDirectories = lines(from: job.queueDirectoriesText)
        if !queueDirectories.isEmpty {
            plist["QueueDirectories"] = queueDirectories
        }
        if job.startOnMount {
            plist["StartOnMount"] = true
        }
        if job.keepAlive {
            plist["KeepAlive"] = true
        }
        if job.throttleIntervalEnabled {
            plist["ThrottleInterval"] = max(job.throttleInterval, 1)
        }

        if job.scheduleEnabled {
            if job.scheduleKind == .interval {
                plist["StartInterval"] = job.startIntervalSeconds
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
        guard job.selectedMonthDays.isEmpty, job.selectedMonths.isEmpty else { return nil }
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
                ? calendarDimensions(for: job).map { startCalendarInterval(for: job, weekday: $0.weekday, monthDay: $0.monthDay, month: $0.month) }
                : calendarDimensions(for: job).map { startCalendarInterval(for: job, weekday: $0.weekday, monthDay: $0.monthDay, month: $0.month) }
            return intervals.count == 1 ? intervals[0] : intervals
        }

        let intervals = calendarDimensions(for: job).flatMap { dimension in
            times.map { time in
                var calendar: [String: Int] = ["Hour": time.hour, "Minute": time.minute]
                if let weekday = dimension.weekday, let value = Int(weekday.cronValue) {
                    calendar["Weekday"] = value == 0 ? 7 : value
                }
                if let monthDay = dimension.monthDay {
                    calendar["Day"] = monthDay
                }
                if let month = dimension.month {
                    calendar["Month"] = month
                }
                return calendar
            }
        }

        return intervals.count == 1 ? intervals[0] : intervals
    }

    private func calendarDimensions(for job: CronJob) -> [(weekday: Weekday?, monthDay: Int?, month: Int?)] {
        let weekdays = job.activeWeekdays.isEmpty ? [Weekday?.none] : job.activeWeekdays.map(Optional.some)
        let monthDays = job.selectedMonthDays.isEmpty ? [Int?.none] : job.selectedMonthDays.sorted().map(Optional.some)
        let months = job.selectedMonths.isEmpty ? [Int?.none] : job.selectedMonths.sorted().map(Optional.some)

        return weekdays.flatMap { weekday in
            monthDays.flatMap { monthDay in
                months.map { month in
                    (weekday: weekday, monthDay: monthDay, month: month)
                }
            }
        }
    }

    private func startCalendarInterval(for job: CronJob, weekday selectedWeekday: Weekday?, monthDay: Int?, month: Int?) -> [String: Int] {
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
        if let monthDay {
            calendar["Day"] = monthDay
        }
        if let month {
            calendar["Month"] = month
        }
        if calendar.isEmpty {
            calendar["Minute"] = 0
        }
        return calendar
    }

    private func applyStartInterval(_ interval: Int, to job: inout CronJob) {
        job.scheduleKind = .interval
        if interval % 3600 == 0 {
            job.intervalUnit = .hours
            job.intervalValue = max(interval / 3600, 1)
        } else if interval % 60 == 0 {
            job.intervalUnit = .minutes
            job.intervalValue = max(interval / 60, 1)
        } else {
            job.intervalUnit = .seconds
            job.intervalValue = max(interval, 1)
        }

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
        job.scheduleKind = .calendar
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
        if let day = calendar["Day"] {
            job.selectedMonthDays = [min(max(day, 1), 31)]
        }
        if let month = calendar["Month"] {
            job.selectedMonths = [min(max(month, 1), 12)]
        }
    }

    private func applyCalendars(_ calendars: [[String: Int]], to job: inout CronJob) {
        job.scheduleKind = .calendar
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
        job.selectedMonthDays = Array(Set(calendars.compactMap { $0["Day"] }.map { min(max($0, 1), 31) })).sorted()
        job.selectedMonths = Array(Set(calendars.compactMap { $0["Month"] }.map { min(max($0, 1), 12) })).sorted()
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
        .background(WindowCloseHandler(viewModel: viewModel))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Crontab Editor")
                    .font(.title3.bold())
                Text(L10n.t("Crontab, LaunchAgent, and LaunchDaemon"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(L10n.t("Jobs"))
                    .font(.title3.bold())
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
                            .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    }
                }

                if viewModel.showExternalJobs {
                    Section(L10n.t("External")) {
                        ForEach(viewModel.externalJobs) { job in
                            JobRow(job: job)
                                .tag(job.id)
                                .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: 340)
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

                Picker(L10n.t("Schedule Type"), selection: binding(index, \.scheduleKind)) {
                    ForEach(scheduleKinds(for: viewModel.jobs[index])) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .disabled(!viewModel.jobs[index].scheduleEnabled)

                if viewModel.jobs[index].scheduleKind == .interval {
                    intervalScheduleControls(index: index)
                        .disabled(!viewModel.jobs[index].scheduleEnabled || viewModel.jobs[index].backend == .crontab)
                    if viewModel.jobs[index].backend == .crontab {
                        Text(L10n.t("Interval schedules use launchd StartInterval and are available for LaunchAgent and LaunchDaemon jobs."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    calendarScheduleControls(index: index)
                        .disabled(!viewModel.jobs[index].scheduleEnabled)
                }

                Text(viewModel.jobs[index].scheduleDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func calendarScheduleControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

            monthDayControls(index: index)
            monthControls(index: index)

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
        }
    }

    private func intervalScheduleControls(index: Int) -> some View {
        HStack(spacing: 10) {
            Stepper(value: binding(index, \.intervalValue), in: 1...86_400) {
                Text(L10n.f("Every %d", viewModel.jobs[index].intervalValue))
                    .monospacedDigit()
            }
            .frame(width: 160)

            Picker(L10n.t("Unit"), selection: binding(index, \.intervalUnit)) {
                ForEach(IntervalUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
        .padding(10)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }

    private func monthDayControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("Month Days"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 16), alignment: .leading, spacing: 4) {
                ForEach(1...31, id: \.self) { day in
                    Toggle("\(day)", isOn: Binding(
                        get: { viewModel.jobs[index].selectedMonthDays.contains(day) },
                        set: { _ in viewModel.toggleMonthDayForSelectedJob(day) }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.mini)
                    .frame(width: 34)
                }
            }
            Text(L10n.t("Leave empty for every day of the month."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func monthControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("Months"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    Toggle(monthShortTitle(month), isOn: Binding(
                        get: { viewModel.jobs[index].selectedMonths.contains(month) },
                        set: { _ in viewModel.toggleMonthForSelectedJob(month) }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.mini)
                }
            }
            Text(L10n.t("Leave empty for every month."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func monthShortTitle(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        return formatter.shortMonthSymbols[max(min(month, 12), 1) - 1]
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

    private func scheduleKinds(for job: CronJob) -> [ScheduleKind] {
        job.backend == .crontab ? [.calendar] : ScheduleKind.allCases
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
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(L10n.t("Run with interpreter"), isOn: binding(index, \.useInterpreter))

                            if viewModel.jobs[index].useInterpreter {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(L10n.t("Interpreter"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Picker(L10n.t("Interpreter"), selection: interpreterSelectionBinding(index)) {
                                            ForEach(ShellInterpreter.allCases) { interpreter in
                                                Text(interpreter.title).tag(interpreter)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .labelsHidden()
                                    }

                                    if selectedInterpreter(for: viewModel.jobs[index]) == .custom {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(L10n.t("Custom Path"))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            TextField("/opt/homebrew/bin/bash", text: binding(index, \.interpreterPath))
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(.body, design: .monospaced))
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.t("Interpreter Arguments"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField("-l", text: binding(index, \.interpreterArgumentsText))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                    Text(L10n.t("Optional. Example: -l for a login shell."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

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
                        } else {
                            launchdOptions(index: index)
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

    private func launchdOptions(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("LaunchD Options"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Watch Paths"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: binding(index, \.watchPathsText))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    Text(L10n.t("One file or folder path per line."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Queue Directories"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: binding(index, \.queueDirectoriesText))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    Text(L10n.t("One directory path per line."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Working Directory"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("/Users/me/project", text: binding(index, \.workingDirectory))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Environment Variables"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: binding(index, \.environmentVariablesText))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    Text(L10n.t("KEY=value, one per line."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Toggle(L10n.t("Start on mount"), isOn: binding(index, \.startOnMount))
                Toggle(L10n.t("Keep alive"), isOn: binding(index, \.keepAlive))
                Toggle(L10n.t("Throttle"), isOn: binding(index, \.throttleIntervalEnabled))

                if viewModel.jobs[index].throttleIntervalEnabled {
                    Stepper(value: binding(index, \.throttleInterval), in: 1...86_400) {
                        Text(L10n.f("%d seconds", viewModel.jobs[index].throttleInterval))
                            .monospacedDigit()
                    }
                    .frame(width: 160)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
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
                viewModel.markDirty()
            }
        )
    }

    private func selectedInterpreter(for job: CronJob) -> ShellInterpreter {
        ShellInterpreter.allCases.first { $0.rawValue == job.interpreterPath } ?? .custom
    }

    private func interpreterSelectionBinding(_ index: Int) -> Binding<ShellInterpreter> {
        Binding(
            get: { selectedInterpreter(for: viewModel.jobs[index]) },
            set: { interpreter in
                guard viewModel.jobs.indices.contains(index) else { return }
                if interpreter == .custom {
                    viewModel.jobs[index].interpreterPath = ""
                } else {
                    viewModel.jobs[index].interpreterPath = interpreter.rawValue
                }
                viewModel.markDirty()
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

struct SettingsView: View {
    private var backupPath: String {
        CrontabManager.backupDirectory.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("Settings"))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("Crontab Backups"))
                    .font(.headline)
                Text(L10n.t("Before every crontab save, the previous crontab is written to this folder."))
                    .foregroundStyle(.secondary)
                Text(backupPath)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                Button(L10n.t("Open Backup Folder")) {
                    openBackupFolder()
                }
            }

            Spacer()
        }
        .padding(22)
        .frame(width: 560, height: 260)
    }

    private func openBackupFolder() {
        try? FileManager.default.createDirectory(at: CrontabManager.backupDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(CrontabManager.backupDirectory)
    }
}

struct WindowCloseHandler: NSViewRepresentable {
    @ObservedObject var viewModel: CrontabViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.viewModel = viewModel
        DispatchQueue.main.async {
            nsView.window?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var viewModel: CrontabViewModel

        init(viewModel: CrontabViewModel) {
            self.viewModel = viewModel
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard viewModel.hasUnsavedChanges else {
                return true
            }

            let alert = NSAlert()
            alert.messageText = L10n.t("Save changes before closing?")
            alert.informativeText = L10n.t("You have unsaved jobs or changes. Save them before closing, discard them, or cancel closing.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.t("Save"))
            alert.addButton(withTitle: L10n.t("Discard"))
            alert.addButton(withTitle: L10n.t("Cancel"))

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                return viewModel.save()
            case .alertSecondButtonReturn:
                return true
            default:
                return false
            }
        }
    }
}

struct JobRow: View {
    let job: CronJob

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            StatusLight(job: job)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(job.backend.rawValue)
                    Text("·")
                    Text(job.cronExpressions.first ?? job.cronExpression)
                        .monospacedDigit()
                    Text("·")
                    Text(job.statusTitle)
                    if !job.isManaged {
                        Text("·")
                        Text(L10n.t("external"))
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .help(jobTooltip)
    }

    private var jobTooltip: String {
        [
            job.title,
            job.label,
            job.backend.rawValue,
            job.cronExpressions.first ?? job.cronExpression
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

struct StatusLight: View {
    let job: CronJob

    var body: some View {
        Circle()
            .fill(fill)
            .overlay {
                Circle()
                    .strokeBorder(stroke, lineWidth: job.isInstalled ? 0 : 1.5)
            }
            .shadow(color: glow, radius: job.isInstalled && job.isEnabled ? 3 : 0)
            .frame(width: 9, height: 9)
            .accessibilityLabel(job.statusTitle)
    }

    private var fill: Color {
        if !job.isInstalled { return .white.opacity(0.85) }
        return job.isEnabled ? .green : .gray.opacity(0.55)
    }

    private var stroke: Color {
        job.isInstalled ? .clear : .gray.opacity(0.55)
    }

    private var glow: Color {
        .green.opacity(0.45)
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
