import Testing
@testable import CrontabEditor

struct CrontabManagerTests {
    @Test func preservesUnsupportedExternalCronLines() {
        let input = """
        SHELL=/bin/zsh
        MAILTO=""
        */15 8-18 * * 1-5 /usr/local/bin/workday
        30 2 * * * cd /tmp && /usr/local/bin/backup
        45 3 * * * FOO=bar /usr/local/bin/env-job
        0 4 * * * /usr/local/bin/plain > /tmp/plain.log 2>&1
        """

        let manager = CrontabManager()
        let document = manager.parse(crontab: input)
        let rendered = manager.render(jobs: document.jobs, preservedLines: document.preservedLines)

        #expect(document.jobs.isEmpty)
        #expect(rendered == input + "\n")
    }

    @Test func parsesAndRendersSupportedCronJobWithLogging() throws {
        let input = "*/10 2 * * 1,3 '/Users/mathis/bin/test script.sh' '--name=A B' >> '/Users/mathis/Library/Logs/test out.log' 2>> '/Users/mathis/Library/Logs/test err.log'\n"

        let manager = CrontabManager()
        let document = manager.parse(crontab: input)
        let job = try #require(document.jobs.first)

        #expect(document.jobs.count == 1)
        #expect(document.preservedLines.isEmpty)
        #expect(job.scriptPath == "/Users/mathis/bin/test script.sh")
        #expect(job.programArguments == ["--name=A B"])
        #expect(job.loggingEnabled)
        #expect(job.standardOutPath == "/Users/mathis/Library/Logs/test out.log")
        #expect(job.standardErrorPath == "/Users/mathis/Library/Logs/test err.log")
        #expect(job.minuteMode == .interval)
        #expect(job.minuteInterval == 10)
        #expect(job.hourMode == .specific)
        #expect(job.specificHour == 2)
        #expect(job.selectedWeekdays == [.monday, .wednesday])

        let rendered = manager.render(jobs: document.jobs, preservedLines: document.preservedLines)
        #expect(rendered == input)
    }

    @Test func parsesBareCommandCronJobWithArgumentsAndLogging() throws {
        let input = "* * * * * 'test' 'tet' 'asd' >> '/Users/mathis/Library/Logs/local.crontabeditor.test.out.log' 2>> '/Users/mathis/Library/Logs/local.crontabeditor.test.err.log'\n"

        let manager = CrontabManager()
        let document = manager.parse(crontab: input)
        let job = try #require(document.jobs.first)

        #expect(document.jobs.count == 1)
        #expect(document.preservedLines.isEmpty)
        #expect(job.scriptPath == "test")
        #expect(job.programArguments == ["tet", "asd"])
        #expect(job.loggingEnabled)
        #expect(job.standardOutPath == "/Users/mathis/Library/Logs/local.crontabeditor.test.out.log")
        #expect(job.standardErrorPath == "/Users/mathis/Library/Logs/local.crontabeditor.test.err.log")

        let rendered = manager.render(jobs: document.jobs, preservedLines: document.preservedLines)
        #expect(rendered == input)
    }

    @Test func parsesAndRendersEveryNthMonthDay() throws {
        let input = "0 2 */5 * * '/Users/mathis/bin/every-five-days.sh'\n"

        let manager = CrontabManager()
        let document = manager.parse(crontab: input)
        let job = try #require(document.jobs.first)

        #expect(document.jobs.count == 1)
        #expect(job.monthDayMode == .interval)
        #expect(job.monthDayInterval == 5)
        #expect(job.monthDayExpression == "*/5")

        let rendered = manager.render(jobs: document.jobs, preservedLines: document.preservedLines)
        #expect(rendered == input)
    }

    @Test func parsesAndRendersCronJobWithInterpreter() throws {
        let input = "* * * * * /bin/bash -l '/Users/mathis/bin/test script.sh' '--name=A B'\n"

        let manager = CrontabManager()
        let document = manager.parse(crontab: input)
        let job = try #require(document.jobs.first)

        #expect(job.useInterpreter)
        #expect(job.interpreterPath == "/bin/bash")
        #expect(job.interpreterArguments == ["-l"])
        #expect(job.scriptPath == "/Users/mathis/bin/test script.sh")
        #expect(job.programArguments == ["--name=A B"])

        let rendered = manager.render(jobs: document.jobs, preservedLines: document.preservedLines)
        #expect(rendered == "* * * * * '/bin/bash' '-l' '/Users/mathis/bin/test script.sh' '--name=A B'\n")
    }

    @Test func parsesCustomShellPathAsInterpreter() throws {
        let input = "* * * * * /opt/homebrew/bin/bash '/Users/mathis/bin/test.sh'\n"

        let document = CrontabManager().parse(crontab: input)
        let job = try #require(document.jobs.first)

        #expect(job.useInterpreter)
        #expect(job.interpreterPath == "/opt/homebrew/bin/bash")
        #expect(job.scriptPath == "/Users/mathis/bin/test.sh")
    }

    @Test func rendersManagedCronJobWithInterpreter() {
        var job = CronJob.blank()
        job.name = "Shell Job"
        job.label = CronJob.label(for: job.name)
        job.scriptPath = "/Users/mathis/bin/shell-job.sh"
        job.useInterpreter = true
        job.interpreterPath = "/bin/zsh"
        job.interpreterArgumentsText = "-l"
        job.programArgumentsText = "--flag value"

        let rendered = CrontabManager().render(jobs: [job], preservedLines: [])

        #expect(rendered == """
        # CrontabEditor JOB Shell Job
        * * * * * '/bin/zsh' '-l' '/Users/mathis/bin/shell-job.sh' '--flag' 'value'

        """)
    }

    @Test func preservesComplexLinesAroundManagedJobs() {
        let input = """
        PATH=/opt/homebrew/bin:/usr/bin:/bin
        0 5 1 * * /usr/local/bin/monthly --mode full
        # CrontabEditor JOB Backup Job
        * * * * * /Users/mathis/bin/backup.sh --quick
        @daily /usr/local/bin/special
        """

        let manager = CrontabManager()
        let document = manager.parse(crontab: input)

        #expect(document.jobs.count == 2)
        #expect(!document.jobs[0].isManaged)
        #expect(document.jobs[0].name == "monthly")
        #expect(document.jobs[0].selectedMonthDays == [1])
        #expect(document.jobs[1].isManaged)
        #expect(document.jobs[1].name == "Backup Job")
        #expect(document.preservedLines == [
            "PATH=/opt/homebrew/bin:/usr/bin:/bin",
            "@daily /usr/local/bin/special"
        ])

        let rendered = manager.render(jobs: document.jobs, preservedLines: document.preservedLines)
        #expect(rendered.contains("0 5 1 * * '/usr/local/bin/monthly' '--mode' 'full'"))
        #expect(rendered.contains("@daily /usr/local/bin/special"))
        #expect(rendered.contains("# CrontabEditor JOB Backup Job"))
    }
}
