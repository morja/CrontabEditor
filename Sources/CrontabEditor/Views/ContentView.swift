import AppKit
import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CrontabViewModel()
    @State private var isBackendHelpVisible = false
    @State private var isAdvancedExpanded = false
    @State private var isMonthScheduleExpanded = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            viewModel.load()
        }
        .background(WindowCloseHandler(viewModel: viewModel))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Crontab Editor")
                    .font(.title3.bold())
                Text(L10n.t("Crontab, LaunchAgent, and LaunchDaemon"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(L10n.t("Jobs"))
                    .font(.title3.bold())
                Spacer()
                Text("\(viewModel.visibleJobs.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            List(selection: $viewModel.selectedJobID) {
                Section(L10n.t("From Crontab Editor")) {
                    ForEach(viewModel.managedJobs) { job in
                        JobRow(job: job)
                            .tag(job.id)
                            .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    }
                }

                if viewModel.showExternalJobs {
                    Section(L10n.t("External")) {
                        ForEach(viewModel.externalJobs) { job in
                            JobRow(job: job)
                                .tag(job.id)
                                .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack(spacing: 8) {
                Button {
                    viewModel.addJob()
                } label: {
                    Label(L10n.t("Add"), systemImage: "plus")
                }
                Button {
                    viewModel.deleteSelectedJob()
                } label: {
                    Label(L10n.t("Delete"), systemImage: "trash")
                }
                .disabled(viewModel.selectedJobID == nil)
                Spacer()
                Toggle(L10n.t("External"), isOn: $viewModel.showExternalJobs)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: 340)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var editor: some View {
        if let index = viewModel.selectedIndex {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !viewModel.isEditable(viewModel.jobs[index]) {
                        externalJobNotice
                    }
                    jobBasicsSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    scriptSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    scheduleSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    statusSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    advancedSection(index: index)
                        .disabled(!viewModel.isEditable(viewModel.jobs[index]))
                    footer
                }
                .padding(24)
            }
        } else {
            VStack(spacing: 12) {
                Text(L10n.t("No job selected"))
                    .font(.title2.bold())
                Button(L10n.t("Add Job")) {
                    viewModel.addJob()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var externalJobNotice: some View {
        Text(L10n.t("External LaunchAgents and LaunchDaemons are not editable."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func jobBasicsSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Job")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("Name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Backup Job", text: Binding(
                            get: { viewModel.jobs[index].name },
                            set: { viewModel.updateSelectedJobName($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text(L10n.t("Type"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Button {
                                isBackendHelpVisible.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.t("Differences between Crontab, LaunchAgent, and LaunchDaemon"))
                            .popover(isPresented: $isBackendHelpVisible, arrowEdge: .top) {
                                BackendHelpView()
                            }
                        }

                        Picker(L10n.t("Type"), selection: Binding(
                            get: { viewModel.jobs[index].backend },
                            set: { viewModel.setBackendForSelectedJob($0) }
                        )) {
                            ForEach(JobBackend.allCases) { backend in
                                Text(backend.rawValue).tag(backend)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                }

                Text(L10n.f("LaunchD ID: %@", viewModel.jobs[index].label))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(viewModel.jobs[index].backend == .crontab
                    ? L10n.t("Saves the job in your user crontab.")
                    : viewModel.jobs[index].backend == .launchAgent
                        ? L10n.t("Saves the job as a LaunchAgent under ~/Library/LaunchAgents.")
                        : L10n.t("Saves the job as a LaunchDaemon under /Library/LaunchDaemons. macOS asks for admin rights."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scriptSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Script")) {
            let isInvalid = viewModel.invalidJobIDs.contains(viewModel.jobs[index].id)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    TextField("/Users/mathis/bin/backup.sh", text: binding(index, \.scriptPath))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 2)
                        }
                        .onChange(of: viewModel.jobs[index].scriptPath) {
                            viewModel.updateSelectedJob {
                                $0.originalCommand = nil
                                viewModel.invalidJobIDs.remove($0.id)
                            }
                        }
                    Button(L10n.t("Choose")) {
                        viewModel.chooseScriptForSelectedJob()
                    }
                }

                if isInvalid {
                    Text(L10n.t("Script path is missing. Choose a file or enter a path."))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func scheduleSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Schedule")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(L10n.t("Schedule enabled"), isOn: binding(index, \.scheduleEnabled))

                Picker(L10n.t("Schedule Type"), selection: binding(index, \.scheduleKind)) {
                    ForEach(scheduleKinds(for: viewModel.jobs[index])) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .disabled(!viewModel.jobs[index].scheduleEnabled)

                if viewModel.jobs[index].scheduleKind == .interval {
                    intervalScheduleControls(index: index)
                        .disabled(!viewModel.jobs[index].scheduleEnabled || viewModel.jobs[index].backend == .crontab)
                    if viewModel.jobs[index].backend == .crontab {
                        Text(L10n.t("Interval schedules use launchd StartInterval and are available for LaunchAgent and LaunchDaemon jobs."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    calendarScheduleControls(index: index)
                        .disabled(!viewModel.jobs[index].scheduleEnabled)
                }

                Text(viewModel.jobs[index].scheduleDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func calendarScheduleControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Picker(L10n.t("Days"), selection: Binding(
                    get: { weekdayPreset(for: viewModel.jobs[index]) },
                    set: { applyWeekdayPreset($0) }
                )) {
                    Text(L10n.t("Daily")).tag("daily")
                    Text(L10n.t("Workdays")).tag("workdays")
                    Text(L10n.t("Weekend")).tag("weekend")
                    Text(L10n.t("Custom")).tag("custom")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 330)

                HStack(spacing: 4) {
                    ForEach([Weekday.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]) { weekday in
                        Toggle(weekday.shortTitle, isOn: Binding(
                            get: { viewModel.jobs[index].selectedWeekdays.contains(weekday) },
                            set: { _ in viewModel.toggleWeekdayForSelectedJob(weekday) }
                        ))
                        .toggleStyle(.button)
                        .controlSize(.small)
                    }
                }
            }

            DisclosureGroup(isExpanded: $isMonthScheduleExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    monthDayControls(index: index)
                    monthControls(index: index)
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L10n.t("Advanced schedule options"), systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

            HStack(alignment: .top, spacing: 14) {
                compactTimeControl(
                    title: L10n.t("Hour"),
                    picker: Picker(L10n.t("Hour"), selection: binding(index, \.hourMode)) {
                        ForEach(TimeFieldMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    },
                    value: AnyView(hourValueControl(index: index))
                )

                compactTimeControl(
                    title: L10n.t("Minute"),
                    picker: Picker(L10n.t("Minute"), selection: binding(index, \.minuteMode)) {
                        ForEach(TimeFieldMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    },
                    value: AnyView(minuteValueControl(index: index))
                )
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.addFixedTimeForSelectedJob()
                } label: {
                    Label(L10n.t("Time"), systemImage: "plus")
                }
                .controlSize(.small)

                if viewModel.jobs[index].fixedTimes.isEmpty {
                    Text(L10n.t("no fixed times"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.jobs[index].fixedTimes) { time in
                        Button {
                            viewModel.removeFixedTimeForSelectedJob(time)
                        } label: {
                            HStack(spacing: 4) {
                                Text(time.label)
                                    .monospacedDigit()
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.small)
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }

    private func intervalScheduleControls(index: Int) -> some View {
        HStack(spacing: 10) {
            Stepper(value: binding(index, \.intervalValue), in: 1...86_400) {
                Text(L10n.f("Every %d", viewModel.jobs[index].intervalValue))
                    .monospacedDigit()
            }
            .frame(width: 160)

            Picker(L10n.t("Unit"), selection: binding(index, \.intervalUnit)) {
                ForEach(IntervalUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
        .padding(10)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }

    private func monthDayControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("Month Days"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker(L10n.t("Month Days"), selection: binding(index, \.monthDayMode)) {
                    ForEach(TimeFieldMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)

                Stepper(value: binding(index, \.monthDayInterval), in: 1...31) {
                    Text(L10n.f("every %d days", viewModel.jobs[index].monthDayInterval))
                        .monospacedDigit()
                }
                .frame(width: 180)
                .opacity(viewModel.jobs[index].monthDayMode == .interval ? 1 : 0)
                .allowsHitTesting(viewModel.jobs[index].monthDayMode == .interval)
            }
            .frame(width: 450, alignment: .leading)

            ZStack(alignment: .topLeading) {
                if viewModel.jobs[index].monthDayMode == .specific {
                    VStack(alignment: .leading, spacing: 6) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 16), alignment: .leading, spacing: 4) {
                            ForEach(1...31, id: \.self) { day in
                                Toggle("\(day)", isOn: Binding(
                                    get: { viewModel.jobs[index].selectedMonthDays.contains(day) },
                                    set: { _ in viewModel.toggleMonthDayForSelectedJob(day) }
                                ))
                                .toggleStyle(.button)
                                .controlSize(.mini)
                                .frame(width: 34)
                            }
                        }
                        Text(L10n.t("Leave empty for every day of the month."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.jobs[index].monthDayMode == .interval {
                    Text(L10n.t("Cron uses day-of-month steps. LaunchD stores this as explicit month days."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 610, height: 62, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("Months"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    Toggle(monthShortTitle(month), isOn: Binding(
                        get: { viewModel.jobs[index].selectedMonths.contains(month) },
                        set: { _ in viewModel.toggleMonthForSelectedJob(month) }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.mini)
                    .frame(width: 54)
                }
            }
            Text(L10n.t("Leave empty for every month."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthShortTitle(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        return formatter.shortMonthSymbols[max(min(month, 12), 1) - 1]
    }

    private func compactTimeControl<PickerContent: View>(title: String, picker: PickerContent, value: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                picker
                    .labelsHidden()
                    .frame(width: 132)
                value
                    .frame(minWidth: 118, alignment: .leading)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }

    private func weekdayPreset(for job: CronJob) -> String {
        let days = Set(job.selectedWeekdays)
        if days.isEmpty { return "daily" }
        if days == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) { return "workdays" }
        if days == Set([.saturday, .sunday]) { return "weekend" }
        return "custom"
    }

    private func applyWeekdayPreset(_ preset: String) {
        switch preset {
        case "daily":
            viewModel.setWeekdaysForSelectedJob([])
        case "workdays":
            viewModel.setWeekdaysForSelectedJob([.monday, .tuesday, .wednesday, .thursday, .friday])
        case "weekend":
            viewModel.setWeekdaysForSelectedJob([.saturday, .sunday])
        default:
            break
        }
    }

    private func scheduleKinds(for job: CronJob) -> [ScheduleKind] {
        job.backend == .crontab ? [.calendar] : ScheduleKind.allCases
    }

    @ViewBuilder
    private func hourValueControl(index: Int) -> some View {
        switch viewModel.jobs[index].hourMode {
        case .every:
            Text(L10n.t("every hour"))
                .foregroundStyle(.secondary)
        case .specific:
            Stepper(value: binding(index, \.specificHour), in: 0...23) {
                Text("\(String(format: "%02d", viewModel.jobs[index].specificHour)):00")
                    .monospacedDigit()
            }
            .frame(width: 150)
        case .interval:
            Stepper(value: binding(index, \.hourInterval), in: 1...23) {
                Text(L10n.f("every %d h", viewModel.jobs[index].hourInterval))
                    .monospacedDigit()
            }
            .frame(width: 150)
        }
    }

    @ViewBuilder
    private func minuteValueControl(index: Int) -> some View {
        switch viewModel.jobs[index].minuteMode {
        case .every:
            Text(L10n.t("every minute"))
                .foregroundStyle(.secondary)
        case .specific:
            Stepper(value: binding(index, \.specificMinute), in: 0...59) {
                Text(L10n.f("Minute %d", viewModel.jobs[index].specificMinute))
                    .monospacedDigit()
            }
            .frame(width: 150)
        case .interval:
            Stepper(value: binding(index, \.minuteInterval), in: 1...59) {
                Text(L10n.f("every %d min", viewModel.jobs[index].minuteInterval))
                    .monospacedDigit()
            }
            .frame(width: 170)
        }
    }

    private func statusSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Status")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(L10n.t("Job enabled"), isOn: binding(index, \.isEnabled))

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.jobs[index].backend == .crontab ? L10n.t("Cron line") : "LaunchAgent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(previewText(for: viewModel.jobs[index]))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func advancedSection(index: Int) -> some View {
        SectionBox(title: L10n.t("Advanced")) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    isAdvancedExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isAdvancedExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(isAdvancedExpanded ? L10n.t("Hide options") : L10n.t("Show options"))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                if isAdvancedExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(L10n.t("Run with interpreter"), isOn: binding(index, \.useInterpreter))

                            if viewModel.jobs[index].useInterpreter {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(L10n.t("Interpreter"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Picker(L10n.t("Interpreter"), selection: interpreterSelectionBinding(index)) {
                                            ForEach(ShellInterpreter.allCases) { interpreter in
                                                Text(interpreter.title).tag(interpreter)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .labelsHidden()
                                    }

                                    if selectedInterpreter(for: viewModel.jobs[index]) == .custom {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(L10n.t("Custom Path"))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            TextField("/opt/homebrew/bin/bash", text: binding(index, \.interpreterPath))
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(.body, design: .monospaced))
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.t("Interpreter Arguments"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField("-l", text: binding(index, \.interpreterArgumentsText))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                    Text(L10n.t("Optional. Example: -l for a login shell."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.t("Arguments"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("--flag value", text: binding(index, \.programArgumentsText))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Text(L10n.t("Optional. For LaunchD, these are saved as additional ProgramArguments."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(L10n.t("Start immediately when loaded"), isOn: binding(index, \.runAtLoad))
                            .disabled(viewModel.jobs[index].backend == .crontab)

                        if viewModel.jobs[index].backend == .crontab {
                            Text(L10n.t("RunAtLoad is only available for LaunchAgent and LaunchDaemon jobs."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            launchdOptions(index: index)
                        }

                        Toggle(L10n.t("Enable logging"), isOn: binding(index, \.loggingEnabled))

                        if viewModel.jobs[index].loggingEnabled {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.t("Standard Output Log"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField(defaultOutLogPath(for: viewModel.jobs[index]), text: binding(index, \.standardOutPath))
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.t("Error Log"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    TextField(defaultErrorLogPath(for: viewModel.jobs[index]), text: binding(index, \.standardErrorPath))
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Text(L10n.t("Empty fields automatically use the default paths for this backend."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    private func launchdOptions(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("LaunchD Options"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Watch Paths"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: binding(index, \.watchPathsText))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    Text(L10n.t("One file or folder path per line."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Queue Directories"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: binding(index, \.queueDirectoriesText))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    Text(L10n.t("One directory path per line."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Working Directory"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("/Users/me/project", text: binding(index, \.workingDirectory))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Environment Variables"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: binding(index, \.environmentVariablesText))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    Text(L10n.t("KEY=value, one per line."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Toggle(L10n.t("Start on mount"), isOn: binding(index, \.startOnMount))
                Toggle(L10n.t("Keep alive"), isOn: binding(index, \.keepAlive))
                Toggle(L10n.t("Throttle"), isOn: binding(index, \.throttleIntervalEnabled))

                if viewModel.jobs[index].throttleIntervalEnabled {
                    Stepper(value: binding(index, \.throttleInterval), in: 1...86_400) {
                        Text(L10n.f("%d seconds", viewModel.jobs[index].throttleInterval))
                            .monospacedDigit()
                    }
                    .frame(width: 160)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        let selectedIsEditable = viewModel.selectedJob.map(viewModel.isEditable) == true

        return HStack {
            Text(viewModel.statusMessage)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.t("Reload")) {
                viewModel.load()
            }
            Button(L10n.t("Run now")) {
                viewModel.runSelectedNow()
            }
            .disabled(!selectedIsEditable)
            Button(L10n.t("Save")) {
                viewModel.save()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!selectedIsEditable)
        }
    }

    private func previewText(for job: CronJob) -> String {
        switch job.backend {
        case .crontab:
            job.cronLine
        case .launchAgent:
            job.launchAgentPath.path
        case .launchDaemon:
            job.launchDaemonPath.path
        }
    }

    private func defaultOutLogPath(for job: CronJob) -> String {
        switch job.backend {
        case .crontab:
            job.defaultCronOutLogPath
        case .launchAgent:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs")
                .appendingPathComponent("\(job.label).out.log")
                .path
        case .launchDaemon:
            "/var/log/\(job.label).out.log"
        }
    }

    private func defaultErrorLogPath(for job: CronJob) -> String {
        switch job.backend {
        case .crontab:
            job.defaultCronErrorLogPath
        case .launchAgent:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs")
                .appendingPathComponent("\(job.label).err.log")
                .path
        case .launchDaemon:
            "/var/log/\(job.label).err.log"
        }
    }

    private func binding<Value>(_ index: Int, _ keyPath: WritableKeyPath<CronJob, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.jobs[index][keyPath: keyPath] },
            set: { value in
                viewModel.jobs[index][keyPath: keyPath] = value
                viewModel.markDirty()
            }
        )
    }

    private func selectedInterpreter(for job: CronJob) -> ShellInterpreter {
        ShellInterpreter.allCases.first { $0.rawValue == job.interpreterPath } ?? .custom
    }

    private func interpreterSelectionBinding(_ index: Int) -> Binding<ShellInterpreter> {
        Binding(
            get: { selectedInterpreter(for: viewModel.jobs[index]) },
            set: { interpreter in
                guard viewModel.jobs.indices.contains(index) else { return }
                if interpreter == .custom {
                    viewModel.jobs[index].interpreterPath = ""
                } else {
                    viewModel.jobs[index].interpreterPath = interpreter.rawValue
                }
                viewModel.markDirty()
            }
        )
    }
}
