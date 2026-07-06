import SwiftUI

// MARK: - Panel

struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
    }
}

// MARK: - Status

struct StatusDot: View {
    let zone: StatusZone

    var body: some View {
        Circle()
            .fill(Theme.status(zone))
            .frame(width: 6, height: 6)
    }
}

// MARK: - Values

/// A data value with its unit receding (smaller, tertiary ink).
struct ValueText: View {
    let value: String
    var unit: String?
    var size: CGFloat = 20

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.value(size))
                .foregroundStyle(Theme.ink)
            if let unit {
                Text(unit)
                    .font(.label(size * 0.55))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    var unit: String?
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrow()
            ValueText(value: value, unit: unit)
            if let detail {
                Text(detail)
                    .font(.label(11))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Instrument dial

/// A 240° arc gauge. Track is hairline ink; the indicator arc is graphite
/// unless the metric is a status, in which case it carries the muted
/// status color.
struct InstrumentDial: View {
    let progress: Double          // 0–1
    let value: String
    var unit: String?
    var caption: String?
    var color: Color = Theme.graphite
    var size: CGFloat = 148

    private let sweep = 240.0 / 360.0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(Theme.track, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(150))
            Circle()
                .trim(from: 0, to: sweep * min(1, max(0.005, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(150))
            ForEach(0..<5) { i in
                tick(at: Double(i) / 4)
            }
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.value(size * 0.26))
                        .foregroundStyle(Theme.ink)
                    if let unit {
                        Text(unit)
                            .font(.label(size * 0.115))
                            .foregroundStyle(Theme.ink3)
                    }
                }
                if let caption {
                    Text(caption).eyebrow()
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func tick(at fraction: Double) -> some View {
        let angle = 150 + 240 * fraction
        return Rectangle()
            .fill(Theme.ink.opacity(0.16))
            .frame(width: 1, height: 4)
            .offset(y: -(size / 2) + 10)
            .rotationEffect(.degrees(angle + 90))
    }
}

// MARK: - Band bar

/// Horizontal instrument bar: hairline track, graphite fill, a tick marking
/// the target. Used for sleep hours against need.
struct TargetBar: View {
    let value: Double
    let target: Double
    let maxValue: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.track)
                    .frame(height: 6)
                Capsule()
                    .fill(Theme.graphite)
                    .frame(width: max(6, w * min(1, value / maxValue)), height: 6)
                Rectangle()
                    .fill(Theme.ink.opacity(0.45))
                    .frame(width: 1.5, height: 12)
                    .offset(x: w * min(1, target / maxValue))
            }
            .frame(height: 12, alignment: .center)
        }
        .frame(height: 12)
    }
}

// MARK: - Rows

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var unit: String?
    var note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.body(13))
                .foregroundStyle(Theme.ink2)
            Spacer()
            if let note {
                Text(note)
                    .font(.label(11))
                    .foregroundStyle(Theme.ink3)
            }
            ValueText(value: value, unit: unit, size: 15)
        }
    }
}
