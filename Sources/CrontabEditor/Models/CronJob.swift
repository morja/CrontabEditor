import AppKit
import Foundation
import SwiftUI

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
    var monthDayMode: TimeFieldMode
    var monthDayInterval: Int
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
            monthDayMode: .every,
            monthDayInterval: 5,
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
        switch monthDayMode {
        case .every:
            "*"
        case .specific:
            selectedMonthDays.isEmpty ? "*" : selectedMonthDays.sorted().map(String.init).joined(separator: ",")
        case .interval:
            "*/\(monthDayInterval)"
        }
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
        let monthDayText = switch monthDayMode {
        case .every:
            ""
        case .specific:
            selectedMonthDays.isEmpty ? "" : L10n.f(" on day(s) %@", selectedMonthDays.sorted().map(String.init).joined(separator: ", "))
        case .interval:
            L10n.f(" every %d day(s) of the month", monthDayInterval)
        }
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
