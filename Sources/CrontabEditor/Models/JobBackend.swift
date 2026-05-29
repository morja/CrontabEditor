import AppKit
import Foundation
import SwiftUI

enum JobBackend: String, CaseIterable, Identifiable {
    case crontab = "Crontab"
    case launchAgent = "LaunchAgent"
    case launchDaemon = "LaunchDaemon"

    var id: String { rawValue }
}
