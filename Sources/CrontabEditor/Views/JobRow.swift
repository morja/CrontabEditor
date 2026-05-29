import AppKit
import Foundation
import SwiftUI

struct JobRow: View {
    let job: CronJob

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            StatusLight(job: job)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(job.backend.rawValue)
                    Text("·")
                    Text(job.cronExpressions.first ?? job.cronExpression)
                        .monospacedDigit()
                    Text("·")
                    Text(job.statusTitle)
                    if !job.isManaged {
                        Text("·")
                        Text(L10n.t("external"))
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .help(jobTooltip)
    }

    private var jobTooltip: String {
        [
            job.title,
            job.label,
            job.backend.rawValue,
            job.cronExpressions.first ?? job.cronExpression
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}
