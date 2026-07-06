import SwiftUI

/// "Warm Studio, instrument-grade" palette. Color carries status only —
/// neutral metrics stay ink.
enum Theme {
    static let canvas = Color(hex: 0xF4EFE6)
    static let panel = Color(hex: 0xFBF8F2)
    static let ink = Color(hex: 0x1A1714)
    static let ink2 = ink.opacity(0.55)
    static let ink3 = ink.opacity(0.38)
    static let hairline = ink.opacity(0.08)
    static let track = ink.opacity(0.07)
    static let graphite = Color(hex: 0x45403A)

    static let green = Color(hex: 0x4F7B5E)
    static let amber = Color(hex: 0xB08A3E)
    static let red = Color(hex: 0xA84B3F)

    static func status(_ zone: StatusZone) -> Color {
        switch zone {
        case .green: return green
        case .amber: return amber
        case .red: return red
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// Data values: the only place weight 600 appears.
    static func value(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }

    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular)
    }
}

extension View {
    /// Small-caps section label in tertiary ink.
    func eyebrow() -> some View {
        self
            .font(.label())
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink3)
    }
}

enum Fmt {
    static func num(_ v: Double, _ decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f", v)
    }

    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }

    static func hours(_ hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dayTitle(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
