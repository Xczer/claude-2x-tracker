// GlassContainer.swift
// Liquid glass visual effect container using NSVisualEffectView

import SwiftUI
import AppKit

// MARK: - NSVisualEffectView Wrapper

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material    = material
        view.blendingMode = blendingMode
        view.state       = state
        view.wantsLayer  = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material     = material
        nsView.blendingMode = blendingMode
        nsView.state        = state
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderOpacity: CGFloat = 0.18
    var shadowRadius: CGFloat = 24
    var isElevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Layer 1: Solid opaque base — prevents ANY wallpaper color from bleeding through.
                    // We intentionally avoid NSVisualEffectView(.behindWindow) here because that
                    // composites with the wallpaper behind the entire floating window, pulling in
                    // whatever color the user's background is (red, blue, etc.).
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(hex: "#1A1714").opacity(0.82))

                    // Layer 2: Subtle warm tint to match the Claude palette
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(hex: "#C96442").opacity(0.04))

                    // Layer 3: Top highlight — sells the "glass" look without needing real blur
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            // Glass border
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            // Soft floating shadow
            .shadow(
                color: Color.black.opacity(isElevated ? 0.35 : 0.22),
                radius: isElevated ? shadowRadius * 1.4 : shadowRadius,
                x: 0,
                y: isElevated ? 12 : 8
            )
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, borderOpacity: CGFloat = 0.18, shadowRadius: CGFloat = 24, isElevated: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity, shadowRadius: shadowRadius, isElevated: isElevated))
    }
}

// MARK: - Animated Background

struct AnimatedGradientBackground: View {
    @State private var phase: Double = 0
    @State private var phase2: Double = 0.5
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Base layer
            Rectangle()
                .fill(
                    colorScheme == .dark
                    ? Color(hex: "#0F0D0B")
                    : Color(hex: "#F5EFE8")
                )

            // Animated warm blob 1 (orange/rust)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#C96442").opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 260, height: 200)
                .offset(
                    x: 60 * cos(phase),
                    y: 40 * sin(phase * 0.7)
                )
                .blur(radius: 30)

            // Animated purple blob 2
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#8B5CF6").opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 160)
                .offset(
                    x: -50 * cos(phase2),
                    y: 60 * sin(phase2 * 0.5)
                )
                .blur(radius: 40)

            // Noise grain overlay for texture
            NoiseOverlay()
                .opacity(colorScheme == .dark ? 0.04 : 0.025)
        }
        .onReceive(timer) { _ in
            phase  += 0.004
            phase2 += 0.003
        }
        .ignoresSafeArea()
    }
}

// MARK: - Noise Texture

struct NoiseOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<Int(size.width * size.height * 0.15) {
                let x = CGFloat.random(in: 0..<size.width,  using: &rng)
                let y = CGFloat.random(in: 0..<size.height, using: &rng)
                let g = Double.random(in: 0.5...1.0,        using: &rng)
                ctx.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(Color(white: g, opacity: 0.6))
                )
            }
        }
        .drawingGroup()
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
