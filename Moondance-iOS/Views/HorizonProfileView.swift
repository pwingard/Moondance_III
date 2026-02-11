import SwiftUI

/// Compass radar diagram showing 8-direction minimum altitude values
/// with set-all and per-direction adjustment sliders.
struct HorizonProfileView: View {
    @Binding var altitudes: DirectionalAltitudes

    var body: some View {
        VStack(spacing: 12) {
            // Compass radar chart
            compassDiagram
                .frame(height: 200)
                .padding(.horizontal, 16)

            // "Set All" slider
            VStack(alignment: .leading, spacing: 4) {
                let allSame = Set(altitudes.values.map { Int($0) }).count == 1
                HStack {
                    Text("Set All Directions")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(altitudes.values[0]))\u{00B0}\(allSame ? "" : " (mixed)")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { altitudes.values[0] },
                        set: { newVal in
                            altitudes.values = Array(repeating: newVal, count: 8)
                        }
                    ),
                    in: 10...60, step: 5
                )
            }

            // Per-direction sliders
            DisclosureGroup("Per-Direction Minimums") {
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CardinalDirection.allCases) { dir in
                        VStack(spacing: 2) {
                            HStack {
                                Text(dir.label)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(width: 24, alignment: .leading)
                                Spacer()
                                Text("\(Int(altitudes.values[dir.rawValue]))\u{00B0}")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                            Slider(
                                value: $altitudes.values[dir.rawValue],
                                in: 10...60, step: 5
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Compass Diagram

    private var compassDiagram: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = min(geo.size.width, geo.size.height) / 2 - 28
            let altPoints = altitudePoints(center: center, radius: outerRadius)

            ZStack {
                // Reference circles
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    .frame(width: outerRadius * 1.33, height: outerRadius * 1.33)
                    .position(center)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    .frame(width: outerRadius * 0.67, height: outerRadius * 0.67)
                    .position(center)

                // Cross lines
                ForEach(0..<4, id: \.self) { i in
                    Path { path in
                        let angle = Double(i) * .pi / 4
                        path.move(to: CGPoint(
                            x: center.x - outerRadius * CGFloat(cos(angle)),
                            y: center.y - outerRadius * CGFloat(sin(angle))
                        ))
                        path.addLine(to: CGPoint(
                            x: center.x + outerRadius * CGFloat(cos(angle)),
                            y: center.y + outerRadius * CGFloat(sin(angle))
                        ))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }

                // Altitude polygon — filled
                Path { path in
                    for (i, point) in altPoints.enumerated() {
                        if i == 0 { path.move(to: point) }
                        else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                }
                .fill(Color.cyan.opacity(0.15))

                // Altitude polygon — stroke
                Path { path in
                    for (i, point) in altPoints.enumerated() {
                        if i == 0 { path.move(to: point) }
                        else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                }
                .stroke(Color.cyan.opacity(0.8), lineWidth: 2)

                // Vertex dots
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 6, height: 6)
                        .position(altPoints[i])
                }

                // Direction labels
                ForEach(CardinalDirection.allCases) { dir in
                    let angleDeg = Double(dir.rawValue) * 45.0 - 90.0
                    let angleRad = angleDeg * .pi / 180.0
                    let labelR = outerRadius + 18

                    VStack(spacing: 0) {
                        Text(dir.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(Int(altitudes.values[dir.rawValue]))\u{00B0}")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                    }
                    .position(
                        x: center.x + labelR * CGFloat(cos(angleRad)),
                        y: center.y + labelR * CGFloat(sin(angleRad))
                    )
                }
            }
        }
    }

    private func altitudePoints(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        CardinalDirection.allCases.map { dir in
            let angleDeg = Double(dir.rawValue) * 45.0 - 90.0 // -90 puts N at top
            let angleRad = angleDeg * .pi / 180.0
            let normalizedAlt = CGFloat(altitudes.values[dir.rawValue]) / 60.0
            let r = radius * normalizedAlt
            return CGPoint(
                x: center.x + r * CGFloat(cos(angleRad)),
                y: center.y + r * CGFloat(sin(angleRad))
            )
        }
    }
}
