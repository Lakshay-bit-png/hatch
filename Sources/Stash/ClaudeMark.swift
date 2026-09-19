import SwiftUI

/// Claude's burst mark.
///
/// The ray angles, lengths, widths and colour below were measured off the official
/// app icon by scanning its pixels — not eyeballed. Two things that are easy to get
/// wrong: the rays are round-capped strokes (not tapered points), and their lengths
/// are nearly equal — the variation a viewer notices is in thickness, not reach.
struct ClaudeMark: View {
    var size: CGFloat = 14
    var color: Color = ClaudeMark.clay

    /// Sampled from the icon: #D97757.
    static let clay = Color(red: 0.851, green: 0.467, blue: 0.341)

    /// angle° (0 = right, counter-clockwise), length and width as fractions of radius.
    private static let rays: [(angle: Double, length: Double, width: Double)] = [
        (18, 0.90, 0.13),
        (44, 0.94, 0.11),
        (60, 0.91, 0.16),
        (96, 0.96, 0.11),
        (123, 0.97, 0.13),
        (145, 0.91, 0.13),
        (177, 0.94, 0.11),
        (-149, 0.96, 0.17),
        (-120, 1.00, 0.20),
        (-82, 0.87, 0.14),
        (-50, 0.90, 0.24),
        (-9, 0.89, 0.14)
    ]

    /// Round caps add half a stroke width past each endpoint, so pull the rays in
    /// enough that the longest one still lands inside the frame.
    private static let fit = 0.88

    var body: some View {
        Canvas { context, canvasSize in
            let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            for ray in Self.rays {
                let radians = ray.angle * .pi / 180
                // Measurements are y-up; Canvas is y-down, so the sine is flipped.
                let direction = CGVector(dx: cos(radians), dy: -sin(radians))
                let reach = radius * ray.length * Self.fit

                let start = CGPoint(
                    x: centre.x + direction.dx * radius * 0.04,
                    y: centre.y + direction.dy * radius * 0.04
                )
                let end = CGPoint(
                    x: centre.x + direction.dx * reach,
                    y: centre.y + direction.dy * reach
                )

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: radius * ray.width * Self.fit, lineCap: .round)
                )
            }
        }
        .frame(width: size, height: size)
    }
}
