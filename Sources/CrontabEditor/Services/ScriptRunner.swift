import AppKit
import Foundation
import SwiftUI

struct ScriptRunner {
    static func run(path: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
    }
}
