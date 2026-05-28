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

struct CronJob: Identifiable, Equatable {
    var id = UUID()
    var scriptPath: String
    var minuteMode: TimeFieldMode
    var specificMinute: Int
    var minuteInterval: Int
    var hourMode: TimeFieldMode
    var specificHour: Int
    var hourInterval: Int
    var weekday: Weekday
    var isEnabled: Bool
    var originalCommand: String?

    static func blank() -> CronJob {
        CronJob(
            scriptPath: "",
            minuteMode: .specific,
            specificMinute: 0,
            minuteInterval: 15,
            hourMode: .specific,
            specificHour: 2,
            hourInterval: 1,
            weekday: .every,
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
        "\(minuteExpression) \(hourExpression) * * \(weekday.cronValue)"
    }

    var command: String {
        originalCommand ?? shellEscaped(scriptPath)
    }

    var cronLine: String {
        let line = "\(cronExpression) \(command)"
        return isEnabled ? line : "# \(line)"
    }

    var title: String {
        let value = scriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Neuer Job" : URL(fileURLWithPath: value).lastPathComponent
    }

    var subtitle: String {
        "\(cronExpression) \(isEnabled ? "aktiv" : "inaktiv")"
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

        return "\(weekday.rawValue), \(hourText), \(minuteText)."
    }

    private func shellEscaped(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
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

    private let manager = CrontabManager()
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
            jobs = document.jobs
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
            statusMessage = "Alle Jobs brauchen einen Script-Pfad."
            return
        }

        do {
            try manager.save(jobs: jobs, preservedLines: preservedLines)
            statusMessage = "Crontab gespeichert."
        } catch {
            statusMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
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
        }
    }

    func updateSelectedJob(_ update: (inout CronJob) -> Void) {
        guard let selectedIndex else { return }
        update(&jobs[selectedIndex])
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
        let jobLines = jobs.map(\.cronLine)
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
        job.scriptPath = scriptPath
        job.isEnabled = isEnabled
        job.originalCommand = command == job.command ? nil : command
        applyMinute(parts[0], to: &job)
        applyHour(parts[1], to: &job)
        job.weekday = Weekday.fromCronValue(parts[4])
        return job
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Cronjobs")
                .font(.title2.bold())

            List(selection: $viewModel.selectedJobID) {
                ForEach(viewModel.jobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(job.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                    .tag(job.id)
                }
            }

            HStack {
                Button("Hinzufügen") {
                    viewModel.addJob()
                }
                Button("Löschen") {
                    viewModel.deleteSelectedJob()
                }
                .disabled(viewModel.selectedJobID == nil)
            }
        }
        .padding(18)
        .frame(width: 280)
    }

    @ViewBuilder
    private var editor: some View {
        if let index = viewModel.selectedIndex {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
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
            Text("Liest deine User-Crontab, zeigt parsebare Jobs an und speichert sie wieder als normale Crontab.")
                .foregroundStyle(.secondary)
        }
    }

    private func scriptSection(index: Int) -> some View {
        SectionBox(title: "Script") {
            HStack(spacing: 10) {
                TextField("/Users/mathis/bin/backup.sh", text: binding(index, \.scriptPath))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: viewModel.jobs[index].scriptPath) {
                        viewModel.updateSelectedJob { $0.originalCommand = nil }
                    }
                Button("Auswählen") {
                    viewModel.chooseScriptForSelectedJob()
                }
            }
        }
    }

    private func scheduleSection(index: Int) -> some View {
        SectionBox(title: "Zeitplan") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Picker("Wochentag", selection: binding(index, \.weekday)) {
                        ForEach(Weekday.allCases) { weekday in
                            Text(weekday.rawValue).tag(weekday)
                        }
                    }
                    .frame(width: 220)

                    Picker("Stunde", selection: binding(index, \.hourMode)) {
                        ForEach(TimeFieldMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .frame(width: 170)

                    hourValueControl(index: index)
                }

                HStack(spacing: 12) {
                    Picker("Minute", selection: binding(index, \.minuteMode)) {
                        ForEach(TimeFieldMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .frame(width: 220)

                    minuteValueControl(index: index)
                }

                Text(viewModel.jobs[index].scheduleDescription)
                    .foregroundStyle(.secondary)
            }
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cron-Zeile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.jobs[index].cronLine)
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
            Button("Speichern") {
                viewModel.save()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canSave)
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
