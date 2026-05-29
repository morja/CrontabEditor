import AppKit
import Foundation
import SwiftUI

@main
struct CrontabEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button(L10n.t("Crontab Editor Help")) {
                    if let url = URL(string: "https://github.com/morja/CrontabEditor#readme") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
