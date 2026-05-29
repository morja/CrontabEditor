import AppKit
import Foundation
import SwiftUI

final class CrontabViewModel: ObservableObject {
    @Published var jobs: [CronJob] = []
    @Published var selectedJobID: CronJob.ID?
    @Published var statusMessage = L10n.t("Not loaded yet.")
    @Published var invalidJobIDs: Set<CronJob.ID> = []
    @Published var showExternalJobs = false
    @Published var hasUnsavedChanges = false

    private let manager = CrontabManager()
    private let launchAgentManager = LaunchAgentManager()
    private let launchDaemonManager = LaunchDaemonManager()
    private var preservedLines: [String] = []

    var selectedIndex: Int? {
        guard let selectedJobID else { return nil }
        return jobs.firstIndex { $0.id == selectedJobID }
    }

    var selectedJob: CronJob? {
        guard let selectedIndex else { return nil }
        return jobs[selectedIndex]
    }

    var canSave: Bool {
        jobs.filter(isEditable).allSatisfy {
            !$0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (!$0.useInterpreter || !$0.interpreterPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    var managedJobs: [CronJob] {
        jobs.filter(\.isManaged)
    }

    var externalJobs: [CronJob] {
        jobs.filter { !$0.isManaged }
    }

    func isEditable(_ job: CronJob) -> Bool {
        job.isManaged || job.backend == .crontab
    }

    var visibleJobs: [CronJob] {
        showExternalJobs ? jobs : managedJobs
    }

    func load() {
        let previousSelectedID = selectedJobID
        let previousSelectionKey = selectedJob.map(selectionKey)

        do {
            let document = try manager.load()
            let launchAgentJobs = try launchAgentManager.load()
            let launchDaemonJobs = try launchDaemonManager.load()
            jobs = document.jobs + launchAgentJobs + launchDaemonJobs
            preservedLines = document.preservedLines
            if let previousSelectedID,
               visibleJobs.contains(where: { $0.id == previousSelectedID }) {
                selectedJobID = previousSelectedID
            } else if let previousSelectionKey,
                      let matchingJob = visibleJobs.first(where: { selectionKey(for: $0) == previousSelectionKey }) {
                selectedJobID = matchingJob.id
            } else {
                selectedJobID = defaultSelectedJobID
            }
            hasUnsavedChanges = false
            statusMessage = jobs.isEmpty ? L10n.t("No cron jobs found.") : L10n.f("%d cron job(s) loaded.", jobs.count)
        } catch {
            statusMessage = L10n.f("Could not read crontab: %@", error.localizedDescription)
        }
    }

    private var defaultSelectedJobID: CronJob.ID? {
        managedJobs.first?.id ?? (showExternalJobs ? externalJobs.first?.id : nil)
    }

    private func selectionKey(for job: CronJob) -> String {
        if job.backend == .crontab {
            return "crontab|\(job.isManaged)|\(job.name)|\(job.originalCommand ?? job.cronLine)"
        }

        return "\(job.backend.rawValue)|\(job.label)"
    }

    func addJob() {
        let job = CronJob.blank()
        jobs.append(job)
        selectedJobID = job.id
        hasUnsavedChanges = true
        statusMessage = L10n.t("New job created.")
    }

    func deleteSelectedJob() {
        guard let selectedIndex else { return }
        guard isEditable(jobs[selectedIndex]) else {
            statusMessage = L10n.t("External LaunchAgent/LaunchDaemon jobs are display-only.")
            return
        }
        jobs.remove(at: selectedIndex)
        selectedJobID = jobs.indices.contains(selectedIndex) ? jobs[selectedIndex].id : jobs.last?.id
        hasUnsavedChanges = true
        statusMessage = L10n.t("Job removed. Save writes the change to the crontab.")
    }

    @discardableResult
    func save() -> Bool {
        let previousSelectedID = selectedJobID

        guard canSave else {
            invalidJobIDs = Set(jobs
                .filter(isEditable)
                .filter {
                    $0.scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || ($0.useInterpreter && $0.interpreterPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .map(\.id))
            selectedJobID = invalidJobIDs.first ?? selectedJobID
            statusMessage = L10n.t("All jobs need a script path and selected interpreter path.")
            return false
        }
        invalidJobIDs.removeAll()

        do {
            let backupURL = try manager.save(jobs: jobs.filter { $0.backend == .crontab }, preservedLines: preservedLines)
            try launchAgentManager.save(jobs: jobs.filter { $0.backend == .launchAgent && $0.isManaged })
            try launchDaemonManager.save(jobs: jobs.filter { $0.backend == .launchDaemon && $0.isManaged })
            markEditableJobsInstalled()
            restoreSelection(previousSelectedID)
            hasUnsavedChanges = false
            statusMessage = L10n.f("Jobs saved. Backup: %@", backupURL.lastPathComponent)
            return true
        } catch {
            statusMessage = L10n.f("Save failed: %@", error.localizedDescription)
            return false
        }
    }

    private func markEditableJobsInstalled() {
        for index in jobs.indices where isEditable(jobs[index]) {
            jobs[index].isInstalled = true
        }
    }

    private func restoreSelection(_ jobID: CronJob.ID?) {
        guard let jobID, visibleJobs.contains(where: { $0.id == jobID }) else { return }
        selectedJobID = jobID
    }

    func runSelectedNow() {
        guard let selectedJob else { return }

        do {
            switch selectedJob.backend {
            case .crontab:
                try ScriptRunner.run(path: selectedJob.executablePath, arguments: Array(selectedJob.launchdProgramArguments.dropFirst()))
            case .launchAgent:
                try launchAgentManager.runNow(selectedJob)
            case .launchDaemon:
                try launchDaemonManager.runNow(selectedJob)
            }
            statusMessage = L10n.t("Job started.")
        } catch {
            statusMessage = L10n.f("Start failed: %@", error.localizedDescription)
        }
    }

    @MainActor
    func chooseScriptForSelectedJob() {
        guard let selectedIndex else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = L10n.t("Choose Script")

        if panel.runModal() == .OK, let url = panel.url {
            jobs[selectedIndex].scriptPath = url.path
            jobs[selectedIndex].originalCommand = nil
            invalidJobIDs.remove(jobs[selectedIndex].id)
            hasUnsavedChanges = true
        }
    }

    func updateSelectedJob(_ update: (inout CronJob) -> Void) {
        guard let selectedIndex else { return }
        update(&jobs[selectedIndex])
        hasUnsavedChanges = true
    }

    func updateSelectedJobName(_ name: String) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].name = name
        jobs[selectedIndex].label = CronJob.label(for: name)
        hasUnsavedChanges = true
    }

    func setBackendForSelectedJob(_ backend: JobBackend) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].backend = backend
        if backend == .crontab {
            jobs[selectedIndex].runAtLoad = false
            jobs[selectedIndex].scheduleKind = .calendar
        }
        hasUnsavedChanges = true
    }

    func setWeekdaysForSelectedJob(_ weekdays: [Weekday]) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].selectedWeekdays = weekdays
        hasUnsavedChanges = true
    }

    func toggleMonthDayForSelectedJob(_ day: Int) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedMonthDays.contains(day) {
            jobs[selectedIndex].selectedMonthDays.removeAll { $0 == day }
        } else {
            jobs[selectedIndex].selectedMonthDays.append(day)
        }
        hasUnsavedChanges = true
    }

    func toggleMonthForSelectedJob(_ month: Int) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedMonths.contains(month) {
            jobs[selectedIndex].selectedMonths.removeAll { $0 == month }
        } else {
            jobs[selectedIndex].selectedMonths.append(month)
        }
        hasUnsavedChanges = true
    }

    func toggleWeekdayForSelectedJob(_ weekday: Weekday) {
        guard let selectedIndex else { return }
        if jobs[selectedIndex].selectedWeekdays.contains(weekday) {
            jobs[selectedIndex].selectedWeekdays.removeAll { $0 == weekday }
        } else {
            jobs[selectedIndex].selectedWeekdays.append(weekday)
        }
        hasUnsavedChanges = true
    }

    func addFixedTimeForSelectedJob() {
        guard let selectedIndex else { return }
        jobs[selectedIndex].fixedTimes.append(DailyTime(hour: jobs[selectedIndex].specificHour, minute: jobs[selectedIndex].specificMinute))
        hasUnsavedChanges = true
    }

    func removeFixedTimeForSelectedJob(_ time: DailyTime) {
        guard let selectedIndex else { return }
        jobs[selectedIndex].fixedTimes.removeAll { $0.id == time.id }
        hasUnsavedChanges = true
    }

    func markDirty() {
        hasUnsavedChanges = true
    }
}
