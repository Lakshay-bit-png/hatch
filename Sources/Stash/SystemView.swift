import SwiftUI

// MARK: - Pieces

/// Circular gauge with the reading in the middle.
private struct GaugeRing: View {
    var value: Double
    var headline: String
    var label: String
    var caption: String
    var tint: Color

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(palette.fill, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, value)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.45), value: value)

                Text(headline)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
            }
            .frame(width: 58, height: 58)

            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.text)

            Text(caption)
                .font(.system(size: 9.5))
                .foregroundStyle(palette.faint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Line through the recent samples, with a soft fill underneath.
private struct Sparkline: Shape {
    var values: [Double]
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        let step = rect.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let y = rect.height * (1 - CGFloat(min(1, max(0, value))))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// One horizontal capacity bar — used for disks.
private struct MeterRow: View {
    var name: String
    var used: Int64
    var total: Int64
    var fraction: Double
    var tint: Color

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .frame(width: 104, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.fill)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(3, geo.size.width * CGFloat(min(1, fraction))))
                        .animation(.easeOut(duration: 0.45), value: fraction)
                }
            }
            .frame(height: 6)

            Text("\(ByteText.string(used)) / \(ByteText.string(total))")
                .font(.system(size: 9.5))
                .monospacedDigit()
                .foregroundStyle(palette.muted)
                .frame(width: 122, alignment: .trailing)
        }
        .frame(height: 22)
    }
}

// MARK: - Page

struct SystemView: View {
    @Bindable var monitor: SystemMonitor

    @Environment(\.palette) private var palette

    /// Neutral until it matters, then amber, then red.
    private func tint(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.60: return palette.contrast
        case ..<0.85: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            gauges
            cpuTrend
            disks
            Spacer(minLength: 0)
            summary
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var gauges: some View {
        HStack(spacing: 6) {
            GaugeRing(
                value: monitor.cpuUsage,
                headline: "\(Int(monitor.cpuUsage * 100))%",
                label: "CPU",
                caption: "\(monitor.coreCount) cores",
                tint: tint(monitor.cpuUsage)
            )

            GaugeRing(
                value: monitor.memoryFraction,
                headline: "\(Int(monitor.memoryFraction * 100))%",
                label: "Memory",
                caption: "\(ByteText.string(monitor.memoryUsed)) of \(ByteText.string(monitor.memoryTotal))",
                tint: tint(monitor.memoryFraction)
            )

            batteryGauge
        }
    }

    @ViewBuilder
    private var batteryGauge: some View {
        if let battery = monitor.battery {
            GaugeRing(
                value: Double(battery.percentage) / 100,
                headline: "\(battery.percentage)%",
                label: battery.isCharging ? "Charging" : (battery.isPlugged ? "Plugged in" : "Battery"),
                caption: batteryCaption(battery),
                // A full battery is good news, so the scale runs the other way.
                tint: battery.percentage < 20 ? .red : palette.contrast
            )
        } else if let boot = monitor.volumes.first {
            GaugeRing(
                value: boot.fraction,
                headline: "\(Int(boot.fraction * 100))%",
                label: "Disk",
                caption: "\(ByteText.string(boot.free)) free",
                tint: tint(boot.fraction)
            )
        }
    }

    private func batteryCaption(_ battery: SystemMonitor.BatteryInfo) -> String {
        if let health = battery.health {
            if let cycles = battery.cycleCount {
                return "\(health)% health · \(cycles) cycles"
            }
            return "\(health)% health"
        }
        if let minutes = battery.minutesRemaining {
            return "\(minutes / 60)h \(minutes % 60)m left"
        }
        return battery.isPlugged ? "On power" : "On battery"
    }

    private var cpuTrend: some View {
        ZStack {
            Sparkline(values: monitor.cpuHistory, closed: true)
                .fill(
                    LinearGradient(
                        colors: [tint(monitor.cpuUsage).opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Sparkline(values: monitor.cpuHistory, closed: false)
                .stroke(tint(monitor.cpuUsage).opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .frame(height: 30)
        .overlay(alignment: .topLeading) {
            Text("CPU · last 70s")
                .font(.system(size: 8.5))
                .foregroundStyle(palette.faint)
        }
    }

    private var disks: some View {
        VStack(spacing: 2) {
            ForEach(monitor.volumes.prefix(3)) { volume in
                MeterRow(
                    name: volume.name,
                    used: volume.used,
                    total: volume.total,
                    fraction: volume.fraction,
                    tint: tint(volume.fraction)
                )
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 6) {
            Text("Up \(monitor.uptimeText)")
            Text("·")
            Text("\(ByteText.string(monitor.memoryTotal)) RAM")
            Text("·")
            Text("\(monitor.coreCount) cores")
            Spacer(minLength: 0)
        }
        .font(.system(size: 9.5))
        .foregroundStyle(palette.faint)
    }
}
