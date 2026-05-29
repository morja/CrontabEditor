import AppKit
import Foundation
import SwiftUI

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
