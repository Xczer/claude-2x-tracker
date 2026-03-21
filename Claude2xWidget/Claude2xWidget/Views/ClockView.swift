// ClockView.swift
// Live IST clock with smooth digit transitions and monospaced display

import SwiftUI

struct ClockView: View {
    let timeComponents: (hours: String, minutes: String, seconds: String)

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            // Label
            HStack(spacing: 5) {
                Image(systemName: "globe.asia.australia")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                Text("INDIA STANDARD TIME")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .kerning(1.2)
                Spacer()
            }
            .padding(.horizontal, 20)

            // Clock digits
            HStack(alignment: .center, spacing: 0) {
                // Hours
                ClockSegment(value: timeComponents.hours, color: .white.opacity(0.92))

                ClockColon()

                // Minutes
                ClockSegment(value: timeComponents.minutes, color: .white.opacity(0.92))

                ClockColon()

                // Seconds (slightly dimmer)
                ClockSegment(value: timeComponents.seconds, color: .white.opacity(0.45))

                Spacer()
            }
            .padding(.horizontal, 20)
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
    }
}

// MARK: - Clock Segment (single time unit with flip animation)

struct ClockSegment: View {
    let value: String
    let color: Color

    @State private var displayValue: String = "00"
    @State private var flipOffset: CGFloat = 0

    var body: some View {
        Text(value)
            .font(.system(size: 42, weight: .thin, design: .monospaced))
            .foregroundColor(color)
            .contentTransition(.numericText(countsDown: false))
            .animation(.easeOut(duration: 0.25), value: value)
            .frame(width: 58)
    }
}

// MARK: - Blinking Colon Separator

struct ClockColon: View {
    @State private var opacity: Double = 1.0

    let blink = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(":")
            .font(.system(size: 38, weight: .ultraLight, design: .monospaced))
            .foregroundColor(.white.opacity(opacity * 0.5))
            .frame(width: 18)
            .onReceive(blink) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    opacity = opacity == 1.0 ? 0.2 : 1.0
                }
            }
    }
}

// MARK: - Compact time pill (used in header)

struct TimePill: View {
    let time: String

    var body: some View {
        Text(time)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.45))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }
}
