import AppKit
import Foundation
import SwiftUI

enum L10n {
    private static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "CrontabEditor_CrontabEditor", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        return .main
    }()

    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: .current, arguments: arguments)
    }
}
