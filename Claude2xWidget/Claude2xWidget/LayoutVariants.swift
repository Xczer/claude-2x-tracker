// LayoutVariants.swift
// All 5 layout candidates — shown simultaneously for visual comparison.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared helpers used across all variants
// ─────────────────────────────────────────────────────────────────────────────

/// Thin horizontal day-bar used by most layouts.
struct MiniDayBar: View {
    let status: UsageStatus
    let currentTime: Date
    let istTimeZone: TimeZone

    private var nowFrac: CGFloat {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = istTimeZone
        let h = cal.component(.hour,   from: currentTime)
        let m = cal.component(.minute, from: currentTime)
        let s = cal.component(.second, from: currentTime)
        return CGFloat(h * 60 + m + (s > 30 ? 1 : 0)) / 1440.0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.05))

                // Segments: 0–72.9% green, 72.9–97.9% red, 97.9–100% green
                HStack(spacing: 1.5) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "#22C55E").opacity(0.8), Color(hex: "#16A34A").opacity(0.55)], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.729 - 1.5)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "#DC2626").opacity(0.5), Color(hex: "#991B1B").opacity(0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.250 - 1.5)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "#22C55E").opacity(0.8), Color(hex: "#16A34A").opacity(0.55)], startPoint: .top, endPoint: .bottom))
                }

                if status != .weekend {
                    // Past dim
                    Rectangle()
                        .fill(Color.black.opacity(0.32))
                        .frame(width: nowFrac * w)
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    // Now cursor
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2, height: geo.size.height + 4)
                        .shadow(color: status.dotColor, radius: 4)
                        .offset(x: nowFrac * w - 1)
                }
            }
        }
    }
}

/// Row of 8 day dots for Mar 21–28.
struct MiniCalendarDots: View {
    let days: [CalendarDay]
    var dotSize: CGFloat = 6

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    Text(day.dayNumber)
                        .font(.system(size: 8, weight: day.isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(day.isToday ? Color(hex: "#C96442") : .white.opacity(day.isWeekend ? 0.2 : 0.45))
                    Circle()
                        .fill(day.isWeekend ? Color(hex: "#374151") : (day.isToday ? Color(hex: "#C96442") : Color(hex: "#22C55E").opacity(0.7)))
                        .frame(width: dotSize, height: dotSize)
                        .shadow(color: day.isToday ? Color(hex: "#C96442").opacity(0.6) : .clear, radius: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Bar time axis labels.
struct BarAxisLabels: View {
    var body: some View {
        HStack {
            Text("12A").font(.system(size: 7, design: .rounded)).foregroundColor(.white.opacity(0.2))
            Spacer()
            Text("5:30P").font(.system(size: 7, design: .rounded)).foregroundColor(.white.opacity(0.2))
            Spacer()
            Text("11:30P").font(.system(size: 7, design: .rounded)).foregroundColor(.white.opacity(0.2))
            Spacer()
            Text("12A").font(.system(size: 7, design: .rounded)).foregroundColor(.white.opacity(0.2))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Layout 1 · "Left Accent"
// ─────────────────────────────────────────────────────────────────────────────

struct Layout1_LeftAccent: View {
    @StateObject private var e = StatusEngine()
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            // ── Left status strip ──
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [e.currentStatus.dotColor, e.currentStatus.dotColor.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .shadow(color: e.currentStatus.dotColor.opacity(0.8), radius: 6)
                .padding(.vertical, 12)

            // ── Content ──
            VStack(alignment: .leading, spacing: 10) {
                // Status + countdown
                HStack(alignment: .firstTextBaseline) {
                    Text(e.currentStatus.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(e.nextWindowText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Bar
                VStack(spacing: 4) {
                    MiniDayBar(status: e.currentStatus, currentTime: e.currentTime, istTimeZone: e.istTimeZone)
                        .frame(height: 18)
                    BarAxisLabels()
                }

                // Calendar dots
                MiniCalendarDots(days: e.calendarDays)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#1A1714").opacity(0.88))
                // Subtle status tint on the left edge
                LinearGradient(
                    colors: [e.currentStatus.dotColor.opacity(0.07), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.95).opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Layout 2 · "Mono Card"
// ─────────────────────────────────────────────────────────────────────────────

struct Layout2_MonoCard: View {
    @StateObject private var e = StatusEngine()
    @State private var glowPhase: Double = 0
    @State private var appeared = false

    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status dot inline with label
            HStack(spacing: 8) {
                Circle()
                    .fill(e.currentStatus.dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: e.currentStatus.dotColor.opacity(0.9 + 0.1 * sin(glowPhase)), radius: 6 + 2 * sin(glowPhase))
                Text(e.currentStatus.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(e.nextWindowText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Bar
            VStack(spacing: 4) {
                MiniDayBar(status: e.currentStatus, currentTime: e.currentTime, istTimeZone: e.istTimeZone)
                    .frame(height: 16)
                BarAxisLabels()
            }

            Divider().background(Color.white.opacity(0.06))

            // Calendar
            MiniCalendarDots(days: e.calendarDays)
        }
        .padding(16)
        .background(Color(hex: "#1A1714").opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // Glowing border — the whole status lives here
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            e.currentStatus.dotColor.opacity(0.5 + 0.2 * sin(glowPhase)),
                            e.currentStatus.dotColor.opacity(0.15),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: e.currentStatus.dotColor.opacity(0.15 + 0.08 * sin(glowPhase)), radius: 16)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.95).opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
        .onReceive(glowTimer) { _ in glowPhase += 0.04 }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Layout 3 · "Two Panel"
// ─────────────────────────────────────────────────────────────────────────────

struct Layout3_TwoPanel: View {
    @StateObject private var e = StatusEngine()
    @State private var pulse: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: Status orb ──
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(e.currentStatus.dotColor.opacity(0.12)).scaleEffect(pulse)
                    Circle().fill(e.currentStatus.glowColor).blur(radius: 10).scaleEffect(1.4)
                    Circle()
                        .fill(LinearGradient(colors: e.currentStatus.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8))
                        .shadow(color: e.currentStatus.dotColor.opacity(0.6), radius: 8)
                        .frame(width: 38, height: 38)
                }
                .frame(width: 60, height: 60)

                Text(e.currentStatus.label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(e.currentStatus.dotColor)
                    .kerning(0.5)
                    .multilineTextAlignment(.center)

                Text(e.nextWindowText)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()

                MiniDayBar(status: e.currentStatus, currentTime: e.currentTime, istTimeZone: e.istTimeZone)
                    .frame(height: 10)
            }
            .frame(width: 88)
            .padding(.vertical, 16)
            .padding(.leading, 14)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 0.5)
                .padding(.vertical, 12)

            // ── Right: Calendar ──
            VStack(alignment: .leading, spacing: 0) {
                ForEach(e.calendarDays) { day in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(day.isWeekend ? Color(hex: "#374151") : (day.isToday ? Color(hex: "#C96442") : Color(hex: "#22C55E").opacity(0.7)))
                            .frame(width: 5, height: 5)
                            .shadow(color: day.isToday ? Color(hex: "#C96442").opacity(0.6) : .clear, radius: 3)
                        Text(day.dayName)
                            .font(.system(size: 9, weight: day.isToday ? .bold : .regular, design: .rounded))
                            .foregroundColor(.white.opacity(day.isWeekend ? 0.2 : (day.isToday ? 0.9 : 0.5)))
                        Spacer()
                        Text(day.dayNumber)
                            .font(.system(size: 9, weight: day.isToday ? .bold : .light, design: .monospaced))
                            .foregroundColor(day.isToday ? Color(hex: "#C96442") : .white.opacity(0.3))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(day.isToday ? Color(hex: "#C96442").opacity(0.08) : .clear)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(hex: "#1A1714").opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.95).opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = 2.2 }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Layout 4 · "Timeline Hero"
// ─────────────────────────────────────────────────────────────────────────────

struct Layout4_TimelineHero: View {
    @StateObject private var e = StatusEngine()
    @State private var appeared = false

    private var nowFrac: CGFloat {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = e.istTimeZone
        let h = cal.component(.hour,   from: e.currentTime)
        let m = cal.component(.minute, from: e.currentTime)
        return CGFloat(h * 60 + m) / 1440.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: status inline
            HStack {
                Circle()
                    .fill(e.currentStatus.dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: e.currentStatus.dotColor, radius: 5)
                Text(e.currentStatus.label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(e.nextWindowText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Hero bar — tall and prominent
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))

                    // Segments
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .frame(width: w * 0.729 - 2)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "#DC2626").opacity(0.5), Color(hex: "#991B1B").opacity(0.3)], startPoint: .top, endPoint: .bottom))
                            .frame(width: w * 0.250 - 2)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    }

                    // Past dim
                    if e.currentStatus != .weekend {
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: nowFrac * w)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Now cursor + status dot riding on it
                        VStack(spacing: 0) {
                            Circle()
                                .fill(e.currentStatus.dotColor)
                                .frame(width: 10, height: 10)
                                .shadow(color: e.currentStatus.dotColor, radius: 6)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 2, height: geo.size.height)
                                .shadow(color: e.currentStatus.dotColor, radius: 4)
                        }
                        .frame(height: geo.size.height + 14)
                        .offset(x: nowFrac * w - 5, y: -7)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                )
            }
            .frame(height: 38)

            // Axis
            BarAxisLabels()

            // Calendar dots
            MiniCalendarDots(days: e.calendarDays)
        }
        .padding(16)
        .background(Color(hex: "#1A1714").opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.95).opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Layout 5 · "Compact Pill"
// ─────────────────────────────────────────────────────────────────────────────

struct Layout5_CompactPill: View {
    @StateObject private var e = StatusEngine()
    @State private var pulse: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 9) {
            // Row 1: status dot + label + countdown — all inline
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(e.currentStatus.dotColor.opacity(0.2)).frame(width: 14, height: 14).scaleEffect(pulse)
                    Circle().fill(e.currentStatus.dotColor).frame(width: 7, height: 7)
                        .shadow(color: e.currentStatus.dotColor, radius: 4)
                }
                Text(e.currentStatus.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Text("·")
                    .foregroundColor(.white.opacity(0.2))
                Text(e.nextWindowText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }

            // Row 2: bar
            VStack(spacing: 3) {
                MiniDayBar(status: e.currentStatus, currentTime: e.currentTime, istTimeZone: e.istTimeZone)
                    .frame(height: 14)
                BarAxisLabels()
            }

            // Row 3: calendar dots
            MiniCalendarDots(days: e.calendarDays, dotSize: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color(hex: "#1A1714").opacity(0.90)
                // Very subtle status tint across whole card
                e.currentStatus.dotColor.opacity(0.04)
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear],
                    startPoint: .top, endPoint: .center
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.95).opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = 2.0 }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Comparison host view
// ─────────────────────────────────────────────────────────────────────────────

struct LayoutComparisonView: View {
    var body: some View {
        ZStack {
            // Same dark bg used in real widget
            Color(hex: "#0F0D0B").ignoresSafeArea()
            LinearGradient(
                colors: [Color(hex: "#C96442").opacity(0.08), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    variantRow(number: 1, name: "Left Accent",    hint: "Status as left color strip + subtle bg tint") { Layout1_LeftAccent() }
                    variantRow(number: 2, name: "Mono Card",      hint: "Entire border glows with status color")       { Layout2_MonoCard() }
                    variantRow(number: 3, name: "Two Panel",      hint: "Status orb left / calendar list right")       { Layout3_TwoPanel() }
                    variantRow(number: 4, name: "Timeline Hero",  hint: "Tall bar is the focus, dot rides the cursor") { Layout4_TimelineHero() }
                    variantRow(number: 5, name: "Compact Pill",   hint: "Ultra-minimal 3-row single surface")          { Layout5_CompactPill() }
                }
                .padding(32)
            }
        }
    }

    @ViewBuilder
    private func variantRow<V: View>(number: Int, name: String, hint: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#C96442"))
                    .frame(width: 22, height: 22)
                    .background(Color(hex: "#C96442").opacity(0.15))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text(hint)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            content()
        }
    }
}
