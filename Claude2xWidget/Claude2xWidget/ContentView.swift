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
                    istTimeZone: engine.istTimeZone
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
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 440)
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

    @State private var pulse: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 9) {
            // Pulsing status orb
            ZStack {
                Circle()
                    .fill(status.dotColor.opacity(0.18))
                    .frame(width: 18, height: 18)
                    .scaleEffect(pulse)
                    .opacity(status.isActive ? 1 : 0)

                Circle()
                    .fill(status.dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: status.dotColor.opacity(0.9), radius: 5)
            }

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
        .onAppear {
            guard status.isActive else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = 2.2
            }
        }
        .onChange(of: status) { s in
            pulse = 1.0
            if s.isActive {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulse = 2.2
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timeline Bar (the hero element)
// ─────────────────────────────────────────────────────────────────────────────

struct TimelineBar: View {
    let status: UsageStatus
    let currentTime: Date
    let istTimeZone: TimeZone

    @State private var barAppeared = false
    @State private var glowPhase: Double = 0

    // 60 fps glow pulse on the now-line
    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    // 0.0–1.0 position of "now" across the 24-hour bar
    private var nowFraction: CGFloat {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = istTimeZone
        let h = cal.component(.hour,   from: currentTime)
        let m = cal.component(.minute, from: currentTime)
        let s = cal.component(.second, from: currentTime)
        return CGFloat(h * 60 + m + (s > 30 ? 1 : 0)) / 1440.0
    }

    // Current IST time as HH:MM string for the floating label
    private var nowLabel: String {
        let f = DateFormatter()
        f.timeZone = istTimeZone
        f.dateFormat = "HH:mm"
        return f.string(from: currentTime)
    }

    var body: some View {
        VStack(spacing: 4) {
            // ── The bar + now-indicator ───────────────────────────
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pinX = nowFraction * w                      // x of the now-line
                let overrun: CGFloat = 8                        // how far line extends above/below bar

                ZStack(alignment: .leading) {

                    // ── Background track ──
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                        )

                    // ── Coloured segments (animate width on appear) ──
                    if status != .weekend {
                        HStack(spacing: 2) {
                            // Active: 00:00–17:30  (72.9%)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barAppeared ? w * 0.729 - 2 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: barAppeared)

                            // Blocked: 17:30–23:30  (25.0%)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#DC2626").opacity(0.5), Color(hex: "#991B1B").opacity(0.28)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barAppeared ? w * 0.250 - 2 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.18), value: barAppeared)

                            // Active: 23:30–24:00  (2.1%)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barAppeared ? w * 0.021 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.26), value: barAppeared)
                        }

                        // ── Past-dimming overlay (left of now) ──
                        Rectangle()
                            .fill(Color.black.opacity(0.30))
                            .frame(width: pinX)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .allowsHitTesting(false)

                        // ── NOW INDICATOR ────────────────────────────────
                        // Composed of three layers:
                        //  1. Soft glow blur  (widest, most transparent)
                        //  2. Core white line (1.5 px)
                        //  3. Pin cap circle  (sits above bar, anchors the line)
                        //  4. Time label      (floats above the pin)

                        ZStack(alignment: .top) {

                            // 1. Outer glow
                            Capsule()
                                .fill(status.dotColor.opacity(0.20 + 0.08 * sin(glowPhase)))
                                .frame(width: 8, height: h + overrun * 2)
                                .blur(radius: 5)

                            // 2. Core line — runs the full bar height plus overrun top/bottom
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            status.dotColor.opacity(0.9),
                                            Color.white,
                                            status.dotColor.opacity(0.6)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 1.8, height: h + overrun * 2)
                                .shadow(color: status.dotColor.opacity(0.7 + 0.2 * sin(glowPhase)), radius: 4)

                            // 3. Pin cap — circle sitting at the very top of the line
                            Circle()
                                .fill(status.dotColor)
                                .frame(width: 10, height: 10)
                                .shadow(color: status.dotColor.opacity(0.9), radius: 6 + 2 * sin(glowPhase))
                                .offset(y: -5)  // centre the cap on top edge of overrun

                            // 4. Time label above the pin cap
                            Text(nowLabel)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundColor(status.dotColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(status.dotColor.opacity(0.12))
                                .clipShape(Capsule())
                                .offset(y: -26)  // float above the cap
                        }
                        // Position the whole indicator at pinX
                        .frame(width: 8)
                        .offset(x: pinX - 4, y: -overrun)
                        .animation(.linear(duration: 1), value: nowFraction)

                    } else {
                        // Weekend placeholder
                        HStack(spacing: 6) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.2))
                            Text("NO 2× ON WEEKENDS")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.2))
                                .kerning(0.8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 40)

            // ── Axis labels ───────────────────────────────────────
            HStack {
                axisLabel("12 AM")
                Spacer()
                axisLabel("5:30 PM")
                Spacer()
                axisLabel("11:30 PM")
                Spacer()
                axisLabel("12 AM")
            }
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
