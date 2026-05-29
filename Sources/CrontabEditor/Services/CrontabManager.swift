import AppKit
import Foundation
import SwiftUI

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
