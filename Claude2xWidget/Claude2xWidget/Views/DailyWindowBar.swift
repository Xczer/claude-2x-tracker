// DailyWindowBar.swift
// Live bar chart showing the 2× active window across 24 hours (IST)
// Active:  00:00–17:30  and  23:30–24:00  (green)
// Blocked: 17:30–23:30                    (red/dim)
// A glowing "now" cursor slides through as the day progresses.

import SwiftUI

// MARK: - Segment definition

private struct DaySegment {
    let startMinute: Int   // 0–1440
    let endMinute: Int
    let isActive: Bool

    var fraction: CGFloat { CGFloat(endMinute - startMinute) / 1440 }
}

// Fixed weekday schedule (all times in minutes since midnight, IST)
private let daySegments: [DaySegment] = [
    DaySegment(startMinute: 0,    endMinute: 1050, isActive: true),   // 00:00–17:30 ✅
    DaySegment(startMinute: 1050, endMinute: 1410, isActive: false),  // 17:30–23:30 ❌
    DaySegment(startMinute: 1410, endMinute: 1440, isActive: true),   // 23:30–24:00 ✅
]

// MARK: - Main View

struct DailyWindowBar: View {
    let status: UsageStatus
    let currentTime: Date
    let etTimeZone: TimeZone

    @State private var appeared = false
    @State private var cursorGlow: Double = 0

    // Timer drives the glow pulse on the now-cursor
    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            // ── Header row ────────────────────────────────────────
            HStack {
                Label {
                    Text("2× DAILY WINDOW")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .kerning(1.2)
                } icon: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                }

                Spacer()

                // Show today's total active hours or weekend label
                Text(headerRightText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(status == .weekend
                        ? Color(hex: "#6B7280").opacity(0.6)
                        : Color(hex: "#4ADE80").opacity(0.7))
                    .kerning(0.6)
            }
            .padding(.horizontal, 20)

            // ── The bar ───────────────────────────────────────────
            GeometryReader { geo in
                let barWidth = geo.size.width
                let barHeight: CGFloat = 28

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: barHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                        )

                    // Colored segments
                    if status != .weekend {
                        HStack(spacing: 2) {
                            ForEach(Array(daySegments.enumerated()), id: \.offset) { _, seg in
                                SegmentBar(
                                    segment: seg,
                                    barWidth: barWidth,
                                    barHeight: barHeight,
                                    isFirstSegment: seg.startMinute == 0,
                                    isLastSegment: seg.endMinute == 1440,
                                    appeared: appeared
                                )
                            }
                        }

                        // "Now" cursor — a glowing vertical line
                        let nowFrac = nowFraction
                        let cursorX = nowFrac * barWidth

                        // Fill overlay: dims the "past" portion of active segments
                        PastFillOverlay(
                            nowFrac: nowFrac,
                            barWidth: barWidth,
                            barHeight: barHeight
                        )

                        // Glowing cursor line
                        ZStack {
                            // Outer glow
                            Capsule()
                                .fill(cursorColor.opacity(0.3 + 0.15 * sin(cursorGlow)))
                                .frame(width: 8, height: barHeight + 6)
                                .blur(radius: 4)

                            // Core line
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 1.5, height: barHeight + 4)
                                .shadow(color: cursorColor, radius: 4)
                        }
                        .offset(x: cursorX - 4)
                        .animation(.linear(duration: 1), value: nowFraction)

                    } else {
                        // Weekend: full dim bar with diagonal stripes
                        WeekendBarOverlay(barWidth: barWidth, barHeight: barHeight)
                    }
                }
                .frame(height: barHeight)
            }
            .frame(height: 28)
            .padding(.horizontal, 20)

            // ── Time labels ───────────────────────────────────────
            HStack(spacing: 0) {
                // 12 AM
                BarLabel(text: "12 AM", alignment: .leading)

                Spacer()

                // 5:30 PM label at 72.9% of the bar
                BarLabel(text: "5:30 PM", alignment: .center)
                    // shift left proportionally
                    .frame(maxWidth: .infinity)

                Spacer()

                // 11:30 PM at 97.9%
                BarLabel(text: "11:30 PM", alignment: .center)

                Spacer()

                // Midnight
                BarLabel(text: "12 AM", alignment: .trailing)
            }
            .padding(.horizontal, 20)

            // ── Progress stats row ────────────────────────────────
            if status != .weekend {
                HStack(spacing: 12) {
                    StatPill(
                        label: "ELAPSED",
                        value: elapsedInWindowText,
                        color: Color(hex: "#4ADE80")
                    )

                    StatPill(
                        label: "REMAINING",
                        value: remainingInWindowText,
                        color: Color(hex: "#C96442")
                    )

                    Spacer()

                    // % through today's active time
                    Text("\(Int(progressPercent * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.5), value: Int(progressPercent * 100))
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16, shadowRadius: 16)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1)) {
                appeared = true
            }
        }
        .onReceive(glowTimer) { _ in
            cursorGlow += 0.05
        }
    }

    // MARK: - Time Calculations

    /// Minutes since midnight in IST
    private var nowMinutes: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = etTimeZone
        let h = cal.component(.hour,   from: currentTime)
        let m = cal.component(.minute, from: currentTime)
        let s = cal.component(.second, from: currentTime)
        return h * 60 + m + (s > 30 ? 1 : 0) // round to nearest minute
    }

    /// 0.0–1.0 fraction of the full 24-hour bar where "now" sits
    private var nowFraction: CGFloat {
        CGFloat(nowMinutes) / 1440.0
    }

    /// Color of the now-cursor based on current status
    private var cursorColor: Color {
        switch status {
        case .active:  return Color(hex: "#4ADE80")
        case .blocked: return Color(hex: "#F87171")
        case .weekend: return Color(hex: "#6B7280")
        }
    }

    /// How far through today's ACTIVE windows we are (0–1)
    private var progressPercent: Double {
        let now = nowMinutes
        let totalActive = 1050 + 30  // 1080 minutes of active time per weekday
        var passedActive = 0

        for seg in daySegments where seg.isActive {
            if now >= seg.endMinute {
                passedActive += seg.endMinute - seg.startMinute
            } else if now > seg.startMinute {
                passedActive += now - seg.startMinute
            }
        }

        return min(1, Double(passedActive) / Double(totalActive))
    }

    /// "X h Ym" elapsed in today's active windows
    private var elapsedInWindowText: String {
        let totalActive = 1080
        let elapsed = Int(progressPercent * Double(totalActive))
        return formatMinutes(elapsed)
    }

    /// Time remaining in today's active windows
    private var remainingInWindowText: String {
        let totalActive = 1080
        let elapsed = Int(progressPercent * Double(totalActive))
        return formatMinutes(totalActive - elapsed)
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var headerRightText: String {
        switch status {
        case .weekend: return "NO 2× TODAY"
        default:       return "18h ACTIVE / DAY"
        }
    }
}

// MARK: - Segment Bar

private struct SegmentBar: View {
    let segment: DaySegment
    let barWidth: CGFloat
    let barHeight: CGFloat
    let isFirstSegment: Bool
    let isLastSegment: Bool
    let appeared: Bool

    var body: some View {
        let width = segment.fraction * barWidth - 2  // -2 for spacing

        RoundedRectangle(cornerRadius: segmentRadius, style: .continuous)
            .fill(segmentGradient)
            .frame(width: max(0, appeared ? width : 0), height: barHeight)
            .animation(
                .spring(response: 0.8, dampingFraction: 0.8)
                .delay(isFirstSegment ? 0.15 : isLastSegment ? 0.35 : 0.25),
                value: appeared
            )
    }

    private var segmentRadius: CGFloat {
        // Full pill shape on the outermost edges
        return 6
    }

    private var segmentGradient: LinearGradient {
        if segment.isActive {
            return LinearGradient(
                colors: [
                    Color(hex: "#22C55E").opacity(0.85),
                    Color(hex: "#16A34A").opacity(0.65),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(hex: "#DC2626").opacity(0.45),
                    Color(hex: "#991B1B").opacity(0.30),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Past Dimming Overlay

/// Dims the portion of the bar that has already passed
private struct PastFillOverlay: View {
    let nowFrac: CGFloat
    let barWidth: CGFloat
    let barHeight: CGFloat

    var body: some View {
        // Left side (past) = slightly dimmer
        Rectangle()
            .fill(Color.black.opacity(0.28))
            .frame(width: nowFrac * barWidth, height: barHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .allowsHitTesting(false)
    }
}

// MARK: - Weekend Placeholder

private struct WeekendBarOverlay: View {
    let barWidth: CGFloat
    let barHeight: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: "#374151").opacity(0.5))
            .frame(width: barWidth, height: barHeight)
            .overlay(
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.2))
                    Text("NO 2× ON WEEKENDS")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.2))
                        .kerning(0.8)
                }
            )
    }
}

// MARK: - Helper Views

private struct BarLabel: View {
    let text: String
    let alignment: TextAlignment

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.2))
            .multilineTextAlignment(alignment)
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
                .kerning(0.8)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color.opacity(0.85))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.4), value: value)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}
