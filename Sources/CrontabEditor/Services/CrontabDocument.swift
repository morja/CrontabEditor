import AppKit
import Foundation
import SwiftUI

struct CrontabDocument {
    var jobs: [CronJob]
    var preservedLines: [String]
}
