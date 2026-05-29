import AppKit
import Foundation
import SwiftUI

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
