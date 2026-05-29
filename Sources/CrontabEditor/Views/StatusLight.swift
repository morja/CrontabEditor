import AppKit
import Foundation
import SwiftUI

struct StatusLight: View {
    let job: CronJob

    var body: some View {
        Circle()
            .fill(fill)
            .overlay {
                Circle()
                    .strokeBorder(stroke, lineWidth: job.isInstalled ? 0 : 1.5)
            }
            .shadow(color: glow, radius: job.isInstalled && job.isEnabled ? 3 : 0)
            .frame(width: 9, height: 9)
            .accessibilityLabel(job.statusTitle)
    }

    private var fill: Color {
        if !job.isInstalled { return .white.opacity(0.85) }
        return job.isEnabled ? .green : .gray.opacity(0.55)
    }

    private var stroke: Color {
        job.isInstalled ? .clear : .gray.opacity(0.55)
    }

    private var glow: Color {
        .green.opacity(0.45)
    }
}
