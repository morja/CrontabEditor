import AppKit
import Foundation
import SwiftUI

func applyProgramArguments(_ arguments: [String], to job: inout CronJob) {
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
func quoteArgument(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func isKnownInterpreter(_ value: String) -> Bool {
    if (ShellInterpreter.allCases
        .filter { $0 != .custom }
        .map(\.rawValue)
        .contains(value)) {
        return true
    }

    return ["sh", "bash", "zsh", "fish"].contains(URL(fileURLWithPath: value).lastPathComponent)
}

func lines(from text: String) -> [String] {
    text
        .split(whereSeparator: \.isNewline)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func keyValueLines(from text: String) -> [String: String] {
    Dictionary(uniqueKeysWithValues: lines(from: text).compactMap { line in
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    })
}
