import SwiftUI

// MARK: - Rocket

private struct RocketBody: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.58),
                       control: CGPoint(x: w * 0.82, y: h * 0.22))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.58))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0),
                       control: CGPoint(x: w * 0.18, y: h * 0.22))
        p.closeSubpath()
        return p
    }
}

private struct RocketFins: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.56))
        p.addLine(to: CGPoint(x: 0, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.84))
        p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.82, y: h * 0.56))
        p.addLine(to: CGPoint(x: w, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.84))
        p.closeSubpath()
        return p
    }
}

private struct RocketGlyph: View {
    var thrusting: Bool
    /// Drives the flame flicker.
    var flicker: Double

    var body: some View {
        ZStack {
            if thrusting {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow.opacity(0.75), .orange.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: 11 + flicker * 5)
                    .offset(y: 13 + flicker * 2)
                    .blur(radius: 1.2)
            }

            RocketFins()
                .fill(Color(white: 0.55))
                .frame(width: 17, height: 23)

            RocketBody()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 1.0), Color(white: 0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 17, height: 23)

            Circle()
                .fill(Color(red: 0.36, green: 0.68, blue: 1.0))
                .frame(width: 5, height: 5)
                .offset(y: -3)
        }
        .frame(width: 17, height: 23)
    }
}

// MARK: - Earth

private struct Earth: View {
    /// Slow continuous spin.
    var spin: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.40, green: 0.72, blue: 1.0),
                            Color(red: 0.10, green: 0.36, blue: 0.78),
                            Color(red: 0.03, green: 0.14, blue: 0.40)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 1,
                        endRadius: 46
                    )
                )

            continents
                .rotationEffect(.degrees(spin))
                .clipShape(Circle())
                .opacity(0.85)

            // Terminator shading towards the lower right.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.45)],
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 12,
                        endRadius: 42
                    )
                )

            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
        .frame(width: 62, height: 62)
        .shadow(color: Color(red: 0.25, green: 0.55, blue: 1).opacity(0.45), radius: 13)
    }

    private var continents: some View {
        let land = Color(red: 0.30, green: 0.68, blue: 0.42)
        return ZStack {
            Ellipse().fill(land).frame(width: 26, height: 17).offset(x: -13, y: -11)
            Ellipse().fill(land).frame(width: 16, height: 23).offset(x: -6, y: 13)
            Ellipse().fill(land).frame(width: 23, height: 14).offset(x: 15, y: -4)
            Ellipse().fill(land).frame(width: 12, height: 9).offset(x: 12, y: 17)
            Ellipse().fill(land).frame(width: 9, height: 7).offset(x: 1, y: -20)
        }
        .frame(width: 62, height: 62)
    }
}

// MARK: - Starfield

private struct Starfield: View {
    var twinkle: Double

    /// Fixed positions so the sky doesn't reshuffle on every redraw.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, phase: Double)] = [
        (0.08, 0.16, 1.1, 0.0), (0.22, 0.06, 0.8, 0.6), (0.41, 0.13, 0.7, 1.7),
        (0.62, 0.05, 1.0, 2.4), (0.83, 0.14, 0.9, 0.9), (0.93, 0.34, 0.7, 3.1),
        (0.06, 0.44, 0.9, 1.2), (0.16, 0.74, 1.1, 2.8), (0.33, 0.90, 0.8, 0.3),
        (0.55, 0.95, 0.7, 1.9), (0.76, 0.86, 1.0, 2.2), (0.92, 0.66, 0.8, 0.5),
        (0.03, 0.62, 0.7, 2.6), (0.68, 0.24, 0.6, 1.1)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(.white)
                        .frame(width: star.r * 2, height: star.r * 2)
                        .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                        .opacity(0.25 + 0.35 * (0.5 + 0.5 * sin(twinkle * 1.6 + star.phase)))
                }
            }
        }
    }
}

// MARK: - Timer page

struct TimerView: View {
    @Bindable var timer: PomodoroTimer
    @Bindable var settings: Settings

    @Environment(\.palette) private var palette
    @FocusState private var minutesFocused: Bool
    @State private var minutesText = ""

    private let orbitRadius: CGFloat = 66

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !timer.isRunning)) { context in
                let now = context.date
                let seconds = now.timeIntervalSinceReferenceDate
                system(progress: timer.progress(at: now), seconds: seconds)
            }
            .frame(width: 168, height: 156)

            Text(timer.displayTime)
                .font(.system(size: 27, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.text)

            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Orbit

    private func system(progress: Double, seconds: Double) -> some View {
        ZStack {
            Starfield(twinkle: seconds)
                .opacity(timer.isRunning ? 1 : 0.55)

            Circle()
                .stroke(palette.fill, style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                .frame(width: orbitRadius * 2, height: orbitRadius * 2)

            Circle()
                .trim(from: 0, to: max(0.0001, progress))
                .stroke(
                    LinearGradient(
                        colors: [palette.contrast.opacity(0.25), palette.contrast],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: orbitRadius * 2, height: orbitRadius * 2)

            Earth(spin: seconds * 4)

            RocketGlyph(
                thrusting: timer.isRunning,
                flicker: 0.5 + 0.5 * sin(seconds * 9)
            )
            // Nose points along the direction of travel.
            .rotationEffect(.degrees(90))
            .offset(y: -orbitRadius)
            .rotationEffect(.degrees(progress * 360))
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        switch timer.phase {
        case .idle:
            HStack(spacing: 10) {
                stepper
                actionButton("Start", filled: true) {
                    timer.start(minutes: settings.timerMinutes)
                }
            }

        case .running:
            HStack(spacing: 8) {
                actionButton("Pause", filled: true) { timer.pause() }
                actionButton("Reset") { timer.reset(minutes: settings.timerMinutes) }
            }

        case .paused:
            HStack(spacing: 8) {
                actionButton("Resume", filled: true) { timer.resume() }
                actionButton("Reset") { timer.reset(minutes: settings.timerMinutes) }
            }

        case .finished:
            HStack(spacing: 8) {
                Text("Session complete")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.muted)
                actionButton("Again", filled: true) {
                    timer.start(minutes: settings.timerMinutes)
                }
            }
        }
    }

    /// Type any number of minutes, or nudge it 5 at a time.
    private var stepper: some View {
        HStack(spacing: 6) {
            stepButton("minus") { setMinutes(settings.timerMinutes - 5) }

            HStack(spacing: 3) {
                TextField("", text: $minutesText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 11.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                    .tint(palette.contrast)
                    .frame(width: 26)
                    .focused($minutesFocused)
                    .onSubmit { commitMinutes() }
                    .onChange(of: minutesFocused) { _, focused in
                        if !focused { commitMinutes() }
                    }
                Text("min")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.muted)
            }

            stepButton("plus") { setMinutes(settings.timerMinutes + 5) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(palette.fill))
        .onAppear { minutesText = "\(settings.timerMinutes)" }
        .onChange(of: settings.timerMinutes) { _, value in
            if !minutesFocused { minutesText = "\(value)" }
        }
    }

    private func setMinutes(_ value: Int) {
        let clamped = min(600, max(1, value))
        settings.timerMinutes = clamped
        minutesText = "\(clamped)"
        timer.reset(minutes: clamped)
    }

    /// Anything unparseable falls back to what was there before.
    private func commitMinutes() {
        let digits = minutesText.filter(\.isNumber)
        if let value = Int(digits), value > 0 {
            setMinutes(value)
        } else {
            minutesText = "\(settings.timerMinutes)"
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.muted)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ title: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(filled ? palette.background : palette.muted)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(Capsule().fill(filled ? palette.contrast : palette.fill))
        }
        .buttonStyle(.plain)
    }
}
