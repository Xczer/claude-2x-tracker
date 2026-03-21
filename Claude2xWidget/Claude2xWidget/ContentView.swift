// ContentView.swift
// Layout 4 — Timeline Hero: tall bar is the hero, status dot rides the now-cursor

import SwiftUI

struct ContentView: View {
    @StateObject private var engine = StatusEngine()
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(alignment: .leading, spacing: 10) {

                // ── Row 1: status dot + label + countdown ────────────
                StatusRow(status: engine.currentStatus, nextWindowText: engine.nextWindowText)
                    .offset(y: appeared ? 0 : -8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)

                // ── Row 2: tall timeline bar with now-indicator ───────
                TimelineBar(
                    status: engine.currentStatus,
                    currentTime: engine.currentTime,
                    seg1: engine.seg1Fraction,
                    seg2: engine.seg2Fraction,
                    seg3: engine.seg3Fraction,
                    blockStartLabel: engine.localBlockStartLabel,
                    blockEndLabel: engine.localBlockEndLabel
                )
                .offset(y: appeared ? 0 : 8)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.12), value: appeared)

                // ── Row 3: calendar dots ──────────────────────────────
                CalendarDotsRow(days: engine.calendarDays)
                    .offset(y: appeared ? 0 : 10)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 0)
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 440, maxHeight: 148)
        .clipped()
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Status Row
// ─────────────────────────────────────────────────────────────────────────────

struct StatusRow: View {
    let status: UsageStatus
    let nextWindowText: String

    var body: some View {
        HStack(spacing: 9) {
            // Status orb with glow
            ZStack {
                if status.isActive {
                    Circle()
                        .fill(status.dotColor.opacity(0.2))
                        .frame(width: 18, height: 18)
                        .blur(radius: 4)
                }

                Circle()
                    .fill(status.dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: status.dotColor.opacity(0.9), radius: status.isActive ? 6 : 2)
            }
            .frame(width: 20, height: 20)

            // Status label
            Text(status.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: status.label)

            Spacer()

            // Next window countdown
            Text(nextWindowText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.38))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: nextWindowText)
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timeline Bar (the hero element)
// ─────────────────────────────────────────────────────────────────────────────

struct TimelineBar: View {
    let status: UsageStatus
    let currentTime: Date
    let seg1: CGFloat      // active before block (local)
    let seg2: CGFloat      // blocked (local)
    let seg3: CGFloat      // active after block (local)
    let blockStartLabel: String  // e.g. "5:30 PM" for IST
    let blockEndLabel: String    // e.g. "11:30 PM" for IST

    @State private var barAppeared = false
    @State private var glowPhase: Double = 0

    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    // Now-indicator position in LOCAL time (user's timezone)
    private var nowFraction: CGFloat {
        let cal = Calendar.current  // uses system timezone
        let h = cal.component(.hour,   from: currentTime)
        let m = cal.component(.minute, from: currentTime)
        let s = cal.component(.second, from: currentTime)
        return CGFloat(h * 60 + m + (s > 30 ? 1 : 0)) / 1440.0
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pinX = nowFraction * w

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                        )

                    if status != .weekend {
                        // Dynamic segments based on local timezone conversion
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barAppeared ? w * seg1 - 1 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: barAppeared)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#DC2626").opacity(0.5), Color(hex: "#991B1B").opacity(0.28)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barAppeared ? w * seg2 - 2 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.18), value: barAppeared)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barAppeared ? w * seg3 - 1 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.26), value: barAppeared)
                        }

                        // Past-dimming overlay
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.black.opacity(0.28))
                                .frame(width: max(0, pinX - 14))
                            LinearGradient(
                                colors: [Color.black.opacity(0.28), Color.black.opacity(0)],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: 14)
                        }
                        .frame(width: pinX, height: h)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .allowsHitTesting(false)

                        // Now indicator
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 1.5, height: h)
                            .shadow(color: Color.white.opacity(0.5 + 0.2 * sin(glowPhase)), radius: 3)
                            .offset(x: pinX - 0.75)
                            .animation(.linear(duration: 1), value: nowFraction)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.2))
                            Text("NO 2\u{00d7} ON WEEKENDS")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.2))
                                .kerning(0.8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 36)

            // ── Axis labels — invisible on weekends but space reserved ──
            Color.clear
                .frame(height: 10)
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width
                        axisLabel(blockStartLabel)
                            .position(x: w * seg1, y: 5)
                        axisLabel(blockEndLabel)
                            .position(x: w * (seg1 + seg2), y: 5)
                    }
                }
                .opacity(status == .weekend ? 0 : 1)
        }
        .onAppear {
            withAnimation { barAppeared = true }
        }
        .onReceive(glowTimer) { _ in glowPhase += 0.05 }
    }

    private func axisLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 7.5, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.22))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Calendar Dots Row
// ─────────────────────────────────────────────────────────────────────────────

struct CalendarDotsRow: View {
    let days: [CalendarDay]
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                VStack(spacing: 4) {
                    Text(day.dayNumber)
                        .font(.system(size: 9, weight: day.isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(
                            day.isToday   ? Color(hex: "#C96442") :
                            day.isWeekend ? .white.opacity(0.2) : .white.opacity(0.42)
                        )

                    Circle()
                        .fill(
                            day.isWeekend ? Color(hex: "#374151") :
                            day.isToday   ? Color(hex: "#C96442") :
                                            Color(hex: "#22C55E").opacity(0.75)
                        )
                        .frame(width: 5, height: 5)
                        .shadow(
                            color: day.isToday ? Color(hex: "#C96442").opacity(0.7) :
                                   !day.isWeekend ? Color(hex: "#22C55E").opacity(0.4) : .clear,
                            radius: 4
                        )

                    Text(day.dayName)
                        .font(.system(size: 7, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(day.isWeekend ? 0.15 : 0.28))
                }
                .frame(maxWidth: .infinity)
                // Staggered slide-up
                .offset(y: appeared ? 0 : 8)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.78).delay(Double(i) * 0.04), value: appeared)
            }
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview {
    ContentView()
        .frame(width: 340, height: 210)
        .preferredColorScheme(.dark)
}
