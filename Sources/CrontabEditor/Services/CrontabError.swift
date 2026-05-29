import AppKit
import Foundation
import SwiftUI

struct CrontabError: LocalizedError {
    let status: Int32
    let output: String

    var errorDescription: String? {
        output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "crontab exited with status \(status)"
            : output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
