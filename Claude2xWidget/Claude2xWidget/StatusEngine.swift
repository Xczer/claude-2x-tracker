// StatusEngine.swift
// Core business logic: IST timezone, 2x eligibility rules, calendar generation

import Foundation
import Combine
import SwiftUI

// MARK: - Status Model

enum UsageStatus: Equatable {
    case active   // Weekday, outside 17:30–23:30 IST
    case blocked  // Weekday, inside 17:30–23:30 IST
    case weekend  // Saturday or Sunday

    var label: String {
        switch self {
        case .active:  return "2× ACTIVE"
        case .blocked: return "BLOCKED"
        case .weekend: return "WEEKEND"
        }
    }

    var sublabel: String {
        switch self {
        case .active:  return "Full rate limit in effect"
        case .blocked: return "5:30 PM – 11:30 PM window"
        case .weekend: return "Resumes Monday"
        }
    }

    var dotColor: Color {
        switch self {
        case .active:  return Color(hex: "#4ADE80")  // emerald green
        case .blocked: return Color(hex: "#F87171")  // soft red
        case .weekend: return Color(hex: "#6B7280")  // muted gray
        }
    }

    var glowColor: Color {
        switch self {
        case .active:  return Color(hex: "#4ADE80").opacity(0.6)
        case .blocked: return Color(hex: "#F87171").opacity(0.4)
        case .weekend: return Color(hex: "#6B7280").opacity(0.3)
        }
    }

    var accentGradient: [Color] {
        switch self {
        case .active:
            return [Color(hex: "#4ADE80"), Color(hex: "#22D3EE")]
        case .blocked:
            return [Color(hex: "#F87171"), Color(hex: "#C96442")]
        case .weekend:
            return [Color(hex: "#6B7280"), Color(hex: "#4B5563")]
        }
    }

    var isActive: Bool { self == .active }
}

// MARK: - Calendar Day Model

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isWeekend: Bool
    let isToday: Bool

    var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased()
    }

    // Status for this full day (ignores time — shows overall day eligibility)
    var dayStatus: DayStatus {
        if isWeekend { return .weekend }
        return .eligible
    }

    enum DayStatus {
        case eligible, weekend
    }
}

// MARK: - Status Engine (ViewModel)

@MainActor
final class StatusEngine: ObservableObject {
    // Published state — views bind to these
    @Published var currentStatus: UsageStatus = .active
    @Published var currentTime: Date = Date()
    @Published var nextWindowText: String = ""
    @Published var calendarDays: [CalendarDay] = []
    @Published var istTimeComponents: (hours: String, minutes: String, seconds: String) = ("00", "00", "00")

    private var timer: AnyCancellable?

    /// IST = UTC+5:30
    let istTimeZone = TimeZone(identifier: "Asia/Kolkata")!

    init() {
        generateCalendarDays()
        update()
        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        // Fire every second on the main run loop
        timer = Timer.publish(every: 1.0, tolerance: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.update()
            }
    }

    private func update() {
        let now = Date()
        currentTime = now
        currentStatus = computeStatus(for: now)
        nextWindowText = computeNextWindow(from: now)
        istTimeComponents = breakTimeComponents(from: now)
    }

    // MARK: - Core Status Logic

    /// Determines 2x eligibility for any given date (IST)
    func computeStatus(for date: Date) -> UsageStatus {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = istTimeZone

        // weekday: 1=Sunday, 2=Monday … 7=Saturday
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return .weekend }

        // Blocked window: 17:30 – 23:30 IST
        let hour   = calendar.component(.hour,   from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = hour * 60 + minute

        let blockStart = 17 * 60 + 30  // 1050
        let blockEnd   = 23 * 60 + 30  // 1410

        if totalMinutes >= blockStart && totalMinutes < blockEnd {
            return .blocked
        }

        return .active
    }

    // MARK: - Next Window Calculation

    /// Returns a human-readable string like "Active for 3h 12m" or "Next 2× in 1h 45m"
    func computeNextWindow(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = istTimeZone

        let status = computeStatus(for: date)

        if status == .active {
            // Count time remaining until block starts or next weekend
            var searchDate = date.addingTimeInterval(60)
            var minutes = 1
            while minutes < 14 * 24 * 60 {
                if computeStatus(for: searchDate) != .active {
                    let diff = searchDate.timeIntervalSince(date)
                    let h = Int(diff / 3600)
                    let m = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
                    if h > 0 { return "Active for \(h)h \(m)m" }
                    return "Active for \(m)m"
                }
                searchDate = searchDate.addingTimeInterval(60)
                minutes += 1
            }
            return "Active"
        }

        // Find next active minute (search up to 7 days ahead in 1-min steps)
        var searchDate = date.addingTimeInterval(60)
        for _ in 0..<(7 * 24 * 60) {
            if computeStatus(for: searchDate) == .active {
                let diff = searchDate.timeIntervalSince(date)
                let h = Int(diff / 3600)
                let m = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
                if h > 0 { return "Next 2× in \(h)h \(m)m" }
                return "Next 2× in \(m)m"
            }
            searchDate = searchDate.addingTimeInterval(60)
        }

        return "Next window unavailable"
    }

    // MARK: - Time Formatting

    func istTimeString(from date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = istTimeZone
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func breakTimeComponents(from date: Date) -> (String, String, String) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = istTimeZone
        let h = cal.component(.hour,   from: date)
        let m = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)
        return (String(format: "%02d", h),
                String(format: "%02d", m),
                String(format: "%02d", s))
    }

    // MARK: - Calendar Generation (Mar 21–28 2026)

    private func generateCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = istTimeZone

        let today = Date()
        let todayComps = calendar.dateComponents([.year, .month, .day], from: today)

        var days: [CalendarDay] = []
        for day in 21...28 {
            var comps = DateComponents()
            comps.year  = 2026
            comps.month = 3
            comps.day   = day
            guard let date = calendar.date(from: comps) else { continue }

            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7

            let dc = calendar.dateComponents([.year, .month, .day], from: date)
            let isToday = dc.year == todayComps.year &&
                          dc.month == todayComps.month &&
                          dc.day == todayComps.day

            days.append(CalendarDay(date: date, isWeekend: isWeekend, isToday: isToday))
        }

        calendarDays = days
    }
}
