// StatusEngine.swift
// Core business logic: status computed in ET, displayed in local timezone.
//
// Claude 2x promotion: usage doubled outside 8 AM - 2 PM ET on weekdays (ET).
// The blocked window is always defined in Eastern Time (America/New_York).
// Display (bar, labels, now-indicator) uses the user's local timezone.

import Foundation
import Combine
import SwiftUI

// MARK: - Status Model

enum UsageStatus: Equatable {
    case active   // Weekday (ET), outside 8:00-14:00 ET
    case blocked  // Weekday (ET), inside 8:00-14:00 ET (peak hours)
    case weekend  // Saturday or Sunday (in ET)

    var label: String {
        switch self {
        case .active:  return "2\u{00d7} ACTIVE"
        case .blocked: return "BLOCKED"
        case .weekend: return "WEEKEND"
        }
    }

    var sublabel: String {
        switch self {
        case .active:  return "smash those prompts"
        case .blocked: return "standard limits"
        case .weekend: return "enjoy the weekend"
        }
    }

    var dotColor: Color {
        switch self {
        case .active:  return Color(hex: "#4ADE80")
        case .blocked: return Color(hex: "#F87171")
        case .weekend: return Color(hex: "#6B7280")
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
        case .active:  return [Color(hex: "#4ADE80"), Color(hex: "#22D3EE")]
        case .blocked: return [Color(hex: "#F87171"), Color(hex: "#C96442")]
        case .weekend: return [Color(hex: "#6B7280"), Color(hex: "#4B5563")]
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
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    var dayName: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date).uppercased()
    }
    var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: date).uppercased()
    }
    var dayStatus: DayStatus { isWeekend ? .weekend : .eligible }
    enum DayStatus { case eligible, weekend }
}

// MARK: - Status Engine (ViewModel)

@MainActor
final class StatusEngine: ObservableObject {
    @Published var currentStatus: UsageStatus = .active
    @Published var currentTime: Date = Date()
    @Published var nextWindowText: String = ""
    @Published var calendarDays: [CalendarDay] = []

    /// Local blocked window times (converted from ET) — for bar display
    @Published var localBlockStartMinutes: Int = 0
    @Published var localBlockEndMinutes: Int = 0
    @Published var localBlockStartLabel: String = ""
    @Published var localBlockEndLabel: String = ""
    /// Bar segment fractions (in local time)
    @Published var seg1Fraction: CGFloat = 0  // active before block
    @Published var seg2Fraction: CGFloat = 0  // blocked
    @Published var seg3Fraction: CGFloat = 0  // active after block

    private var timer: AnyCancellable?

    /// ET = America/New_York (handles EST/EDT automatically)
    let etTimeZone = TimeZone(identifier: "America/New_York")!
    /// User's local timezone
    let localTimeZone = TimeZone.current

    /// Blocked window in ET: 8:00 AM - 2:00 PM (default, overridden by remote config)
    var etBlockStart = 8 * 60   // 480
    var etBlockEnd   = 14 * 60  // 840

    /// Remote schedule URL
    private let scheduleURL = "https://raw.githubusercontent.com/Xczer/claude-2x/main/schedule.json"
    private var fetchTimer: AnyCancellable?

    init() {
        computeLocalBlockWindow()
        generateCalendarDays()
        update()
        startTimer()
        fetchRemoteSchedule()
        startFetchTimer()
    }

    // MARK: - Remote Config

    private func startFetchTimer() {
        // Re-fetch every 6 hours
        fetchTimer = Timer.publish(every: 6 * 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchRemoteSchedule() }
    }

    private func fetchRemoteSchedule() {
        guard let url = URL(string: scheduleURL) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let peakStart = json["peak_start"] as? String,
                  let peakEnd = json["peak_end"] as? String else { return }

            let startMin = Self.parseHHMM(peakStart)
            let endMin = Self.parseHHMM(peakEnd)
            guard startMin >= 0 && endMin >= 0 else { return }

            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.etBlockStart != startMin || self.etBlockEnd != endMin {
                    self.etBlockStart = startMin
                    self.etBlockEnd = endMin
                    self.computeLocalBlockWindow()
                    self.update()
                }
            }
        }.resume()
    }

    private static func parseHHMM(_ s: String) -> Int {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return -1 }
        return parts[0] * 60 + parts[1]
    }

    // MARK: - Compute local blocked window (ET → local)

    private func computeLocalBlockWindow() {
        let now = Date()
        // Get the offset difference between local and ET for today
        let etOffset = etTimeZone.secondsFromGMT(for: now)
        let localOffset = localTimeZone.secondsFromGMT(for: now)
        let diffMinutes = (localOffset - etOffset) / 60

        localBlockStartMinutes = (etBlockStart + diffMinutes + 1440) % 1440
        localBlockEndMinutes   = (etBlockEnd + diffMinutes + 1440) % 1440

        // Format labels
        localBlockStartLabel = formatMinutes(localBlockStartMinutes)
        localBlockEndLabel   = formatMinutes(localBlockEndMinutes)

        // Bar fractions (handle midnight crossing for far-east timezones)
        if localBlockStartMinutes < localBlockEndMinutes {
            // Normal case: blocked window doesn't cross midnight
            seg1Fraction = CGFloat(localBlockStartMinutes) / 1440.0
            seg2Fraction = CGFloat(localBlockEndMinutes - localBlockStartMinutes) / 1440.0
            seg3Fraction = CGFloat(1440 - localBlockEndMinutes) / 1440.0
        } else {
            // Crossed midnight: e.g. 10 PM to 4 AM
            seg1Fraction = CGFloat(localBlockEndMinutes) / 1440.0       // active: midnight to block end
            seg2Fraction = CGFloat(1440 - localBlockStartMinutes + localBlockEndMinutes) / 1440.0  // blocked (wraps)
            seg3Fraction = CGFloat(localBlockStartMinutes - localBlockEndMinutes) / 1440.0  // active: block end to block start
        }
    }

    private func formatMinutes(_ m: Int) -> String {
        let h = m / 60
        let min = m % 60
        let suffix = h >= 12 ? "PM" : "AM"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        if min == 0 { return "\(h12) \(suffix)" }
        return "\(h12):\(String(format: "%02d", min)) \(suffix)"
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.publish(every: 1.0, tolerance: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
    }

    private func update() {
        let now = Date()
        currentTime = now
        currentStatus = computeStatus(for: now)
        nextWindowText = computeNextWindow(from: now)
    }

    // MARK: - Core Status Logic
    // Weekday check: user's LOCAL timezone (Monday is Monday for you)
    // Blocked window check: local-converted ET peak hours

    func computeStatus(for date: Date) -> UsageStatus {
        let cal = Calendar.current // user's local timezone

        let weekday = cal.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return .weekend }

        let totalMinutes = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)

        if localBlockStartMinutes < localBlockEndMinutes {
            // Normal case (doesn't cross midnight)
            if totalMinutes >= localBlockStartMinutes && totalMinutes < localBlockEndMinutes {
                return .blocked
            }
        } else {
            // Crosses midnight (far-east timezones)
            if totalMinutes >= localBlockStartMinutes || totalMinutes < localBlockEndMinutes {
                return .blocked
            }
        }
        return .active
    }

    // MARK: - Next Window (direct calculation in local time)

    func computeNextWindow(from date: Date) -> String {
        let cal = Calendar.current
        let status = computeStatus(for: date)
        let nowMin = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        let weekday = cal.component(.weekday, from: date) // 1=Sun..7=Sat

        switch status {
        case .active:
            // Find when active ends: either blocked window starts or weekend
            if localBlockStartMinutes < localBlockEndMinutes {
                // Normal case
                if nowMin < localBlockStartMinutes {
                    return formatCountdown(minutes: localBlockStartMinutes - nowMin, prefix: "Active for")
                } else {
                    // After block → until next transition
                    let toMidnight = 1440 - nowMin
                    if weekday == 6 { // Friday → weekend at midnight
                        return formatCountdown(minutes: toMidnight, prefix: "Active for")
                    } else {
                        return formatCountdown(minutes: toMidnight + localBlockStartMinutes, prefix: "Active for")
                    }
                }
            } else {
                // Crosses midnight: active zone is between blockEnd and blockStart
                return formatCountdown(minutes: localBlockStartMinutes - nowMin, prefix: "Active for")
            }

        case .blocked:
            if localBlockStartMinutes < localBlockEndMinutes {
                return formatCountdown(minutes: localBlockEndMinutes - nowMin, prefix: "Next 2\u{00d7} in")
            } else {
                // Crosses midnight
                if nowMin >= localBlockStartMinutes {
                    return formatCountdown(minutes: (1440 - nowMin) + localBlockEndMinutes, prefix: "Next 2\u{00d7} in")
                } else {
                    return formatCountdown(minutes: localBlockEndMinutes - nowMin, prefix: "Next 2\u{00d7} in")
                }
            }

        case .weekend:
            // Time until Monday 00:00 LOCAL
            let toMidnight = 1440 - nowMin
            if weekday == 7 { // Saturday
                return formatCountdown(minutes: toMidnight + 1440, prefix: "Next 2\u{00d7} in")
            } else { // Sunday
                return formatCountdown(minutes: toMidnight, prefix: "Next 2\u{00d7} in")
            }
        }
    }

    private func formatCountdown(minutes: Int, prefix: String) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(prefix) \(h)h \(m)m" }
        return "\(prefix) \(m)m"
    }

    // MARK: - Calendar Generation (dynamic 8 days from today)

    private func generateCalendarDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = etTimeZone
        let today = Date()
        let todayComps = cal.dateComponents([.year, .month, .day], from: today)
        var days: [CalendarDay] = []
        for offset in 0..<8 {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let wd = cal.component(.weekday, from: date)
            let isWeekend = wd == 1 || wd == 7
            let dc = cal.dateComponents([.year, .month, .day], from: date)
            let isToday = dc == todayComps
            days.append(CalendarDay(date: date, isWeekend: isWeekend, isToday: isToday))
        }
        calendarDays = days
    }
}
