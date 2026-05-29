import AppKit
import Foundation
import SwiftUI

struct BackendHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("Execution Types"))
                .font(.headline)

            helpRow(
                title: "Crontab",
                text: L10n.t("Simple user cron job. Runs in the user context. On macOS it is less modern than launchd and depends on cron being active.")
            )

            helpRow(
                title: "LaunchAgent",
                text: L10n.t("Apple launchd job for your user. Runs in the background, but reliably only inside your user session, meaning while you are logged in.")
            )

            helpRow(
                title: "LaunchDaemon",
                text: L10n.t("System-wide launchd job. Runs even without a logged-in user and fits server or Mac mini background jobs. Requires admin rights.")
            )
        }
        .padding(16)
        .frame(width: 420)
    }

    private func helpRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
