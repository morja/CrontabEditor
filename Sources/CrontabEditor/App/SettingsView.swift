import AppKit
import Foundation
import SwiftUI

struct SettingsView: View {
    private var backupPath: String {
        CrontabManager.backupDirectory.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("Settings"))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("Crontab Backups"))
                    .font(.headline)
                Text(L10n.t("Before every crontab save, the previous crontab is written to this folder."))
                    .foregroundStyle(.secondary)
                Text(backupPath)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                Button(L10n.t("Open Backup Folder")) {
                    openBackupFolder()
                }
            }

            Spacer()
        }
        .padding(22)
        .frame(width: 560, height: 260)
    }

    private func openBackupFolder() {
        try? FileManager.default.createDirectory(at: CrontabManager.backupDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(CrontabManager.backupDirectory)
    }
}
