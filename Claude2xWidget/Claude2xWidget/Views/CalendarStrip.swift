// CalendarStrip.swift
// Horizontal calendar strip for March 21–28 with staggered entrance animation

import SwiftUI

struct CalendarStrip: View {
    let days: [CalendarDay]

    @State private var appeared = false
    @State private var hoveredDay: UUID? = nil

    var body: some View {
        VStack(spacing: 10) {
            // Section header
            HStack {
                Text("PROMOTION WINDOW")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .kerning(1.2)

                Spacer()

                Text("MAR 2026")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#C96442").opacity(0.7))
                    .kerning(0.8)
            }
            .padding(.horizontal, 20)

            // Calendar tiles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        CalendarDayTile(
                            day: day,
                            isHovered: hoveredDay == day.id
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                hoveredDay = hovering ? day.id : nil
                            }
                        }
                        // Staggered slide-in from bottom
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.75)
                            .delay(Double(index) * 0.05),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16, shadowRadius: 16)
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }
}

// MARK: - Individual Day Tile

struct CalendarDayTile: View {
    let day: CalendarDay
    let isHovered: Bool

    @State private var todayGlowPhase: Double = 0

    private let todayGlowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            // Month (only show if first day or first of month)
            Text(day.monthName)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
                .kerning(0.8)

            // Day number
            Text(day.dayNumber)
                .font(.system(size: 22, weight: day.isToday ? .bold : .light, design: .rounded))
                .foregroundColor(tileTextColor)

            // Day name
            Text(day.dayName)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(tileLabelColor)
                .kerning(0.6)

            // Status indicator dot
            Circle()
                .fill(statusDotColor)
                .frame(width: 5, height: 5)
                .shadow(color: statusDotColor.opacity(0.8), radius: day.isWeekend ? 0 : 3)
        }
        .frame(width: 52, height: 80)
        .background(tileBackground)
        .overlay(tileBorder)
        // Today: animated glow ring
        .overlay(
            day.isToday
            ? AnyView(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: "#C96442").opacity(0.6 + 0.3 * sin(todayGlowPhase)),
                                Color(hex: "#F59E0B").opacity(0.3 + 0.2 * cos(todayGlowPhase))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(
                        color: Color(hex: "#C96442").opacity(0.3),
                        radius: 6
                    )
              )
            : AnyView(EmptyView())
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .shadow(
            color: isHovered ? Color.black.opacity(0.25) : Color.black.opacity(0.1),
            radius: isHovered ? 12 : 4,
            y: isHovered ? 6 : 2
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .onReceive(todayGlowTimer) { _ in
            if day.isToday {
                todayGlowPhase += 0.04
            }
        }
    }

    // MARK: - Computed Styles

    private var tileTextColor: Color {
        if day.isToday   { return Color(hex: "#C96442") }
        if day.isWeekend { return .white.opacity(0.25) }
        return .white.opacity(0.8)
    }

    private var tileLabelColor: Color {
        if day.isWeekend { return .white.opacity(0.2) }
        if day.isToday   { return Color(hex: "#C96442").opacity(0.8) }
        return .white.opacity(0.4)
    }

    private var statusDotColor: Color {
        if day.isWeekend { return Color(hex: "#4B5563") }
        if day.isToday   { return Color(hex: "#C96442") }
        return Color(hex: "#4ADE80")
    }

    @ViewBuilder
    private var tileBackground: some View {
        if day.isToday {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#C96442").opacity(0.18),
                            Color(hex: "#7C3AED").opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else if day.isWeekend {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isHovered
                    ? Color.white.opacity(0.1)
                    : Color.white.opacity(0.06)
                )
        }
    }

    @ViewBuilder
    private var tileBorder: some View {
        if !day.isToday {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(day.isWeekend ? 0.04 : 0.1),
                    lineWidth: 0.5
                )
        }
    }
}
