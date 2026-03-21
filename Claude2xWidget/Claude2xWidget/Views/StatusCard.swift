// StatusCard.swift
// Animated status indicator with pulsing glow, morphing colors, spring transitions

import SwiftUI

struct StatusCard: View {
    let status: UsageStatus
    let nextWindowText: String

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var glowScale: CGFloat = 1.0
    @State private var dotRotation: Double = 0
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top section: dot + status label
            HStack(spacing: 16) {
                // Animated status orb
                StatusOrb(status: status)
                    .frame(width: 52, height: 52)

                // Status text
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.label)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(statusTextGradient)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: status.label)

                    Text(status.sublabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: status.sublabel)
                }

                Spacer()

                // Status badge pill
                StatusBadge(status: status)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            // Bottom: next window countdown
            HStack(spacing: 6) {
                Image(systemName: nextWindowIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(status.dotColor.opacity(0.8))

                Text(nextWindowText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.4), value: nextWindowText)

                Spacer()

                // IST label
                Text("IST")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .glassCard(cornerRadius: 18, shadowRadius: 20)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private var nextWindowIcon: String {
        switch status {
        case .active:  return "clock.badge.checkmark"
        case .blocked: return "clock.badge.xmark"
        case .weekend: return "moon.zzz"
        }
    }

    private var statusTextGradient: some ShapeStyle {
        switch status {
        case .active:
            return LinearGradient(
                colors: [Color(hex: "#4ADE80"), Color(hex: "#A3E635")],
                startPoint: .leading,
                endPoint: .trailing
            ).asShapeStyle()
        case .blocked:
            return LinearGradient(
                colors: [Color(hex: "#F87171"), Color(hex: "#C96442")],
                startPoint: .leading,
                endPoint: .trailing
            ).asShapeStyle()
        case .weekend:
            return LinearGradient(
                colors: [Color(hex: "#9CA3AF"), Color(hex: "#6B7280")],
                startPoint: .leading,
                endPoint: .trailing
            ).asShapeStyle()
        }
    }
}

// MARK: - Animated Status Orb

struct StatusOrb: View {
    let status: UsageStatus

    @State private var pulse1: CGFloat = 1.0
    @State private var pulse2: CGFloat = 1.0
    @State private var innerGlow: Double = 0.7
    @State private var shimmer: Double = 0

    var body: some View {
        ZStack {
            // Outer pulse ring 1
            Circle()
                .fill(status.dotColor.opacity(0.12))
                .scaleEffect(pulse1)
                .opacity(status.isActive ? (2.2 - pulse1) * 0.5 : 0)

            // Outer pulse ring 2 (offset phase)
            Circle()
                .fill(status.dotColor.opacity(0.08))
                .scaleEffect(pulse2)
                .opacity(status.isActive ? (2.2 - pulse2) * 0.35 : 0)

            // Glow halo
            Circle()
                .fill(status.glowColor)
                .blur(radius: 8)
                .scaleEffect(1.3)

            // Core dot with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: status.accentGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Inner highlight
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .scaleEffect(0.45)
                        .offset(x: -4, y: -4)
                        .blur(radius: 2)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: status.dotColor.opacity(0.6), radius: 6)
        }
        .onAppear {
            guard status.isActive else { return }
            startPulse()
        }
        .onChange(of: status) { newStatus in
            if newStatus.isActive {
                startPulse()
            }
        }
    }

    private func startPulse() {
        // Pulse ring 1
        withAnimation(
            .easeOut(duration: 1.8)
            .repeatForever(autoreverses: false)
        ) {
            pulse1 = 2.2
        }

        // Pulse ring 2 (slight delay for offset effect)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(
                .easeOut(duration: 1.8)
                .repeatForever(autoreverses: false)
            ) {
                pulse2 = 2.2
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: UsageStatus

    var body: some View {
        Text(badgeText)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(status.dotColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.dotColor.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(status.dotColor.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .animation(.spring(response: 0.4), value: status)
    }

    private var badgeText: String {
        switch status {
        case .active:  return "LIVE"
        case .blocked: return "OFF"
        case .weekend: return "WKD"
        }
    }
}

// MARK: - Gradient ShapeStyle helper

extension LinearGradient {
    func asShapeStyle() -> LinearGradient { self }
}
