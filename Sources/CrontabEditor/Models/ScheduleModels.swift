import AppKit
import Foundation
import SwiftUI

enum TimeFieldMode: String, CaseIterable, Identifiable {
    case every = "Every"
    case specific = "Specific"
    case interval = "Every N"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
}

enum Weekday: String, CaseIterable, Identifiable {
    case every = "Every Day"
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
    var shortTitle: String {
        switch self {
        case .every: L10n.t("Every Day.short")
        case .sunday: L10n.t("Sunday.short")
        case .monday: L10n.t("Monday.short")
        case .tuesday: L10n.t("Tuesday.short")
        case .wednesday: L10n.t("Wednesday.short")
        case .thursday: L10n.t("Thursday.short")
        case .friday: L10n.t("Friday.short")
        case .saturday: L10n.t("Saturday.short")
        }
    }

    var cronValue: String {
        switch self {
        case .every: "*"
        case .sunday: "0"
        case .monday: "1"
        case .tuesday: "2"
        case .wednesday: "3"
        case .thursday: "4"
        case .friday: "5"
        case .saturday: "6"
        }
    }

    static func fromCronValue(_ value: String) -> Weekday {
        allCases.first { $0.cronValue == value } ?? .every
    }
}

struct DailyTime: Identifiable, Equatable {
    var id = UUID()
    var hour: Int
    var minute: Int

    var label: String {
        "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
    }
}

enum ScheduleKind: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case interval = "Interval"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
}

enum IntervalUnit: String, CaseIterable, Identifiable {
    case seconds = "Seconds"
    case minutes = "Minutes"
    case hours = "Hours"

    var id: String { rawValue }
    var title: String { L10n.t(rawValue) }
}
