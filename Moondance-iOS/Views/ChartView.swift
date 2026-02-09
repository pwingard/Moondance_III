import SwiftUI
import Charts

struct ChartView: View {
    let result: CalculationResult
    var title: String = "Moon & Target Analysis"
    var chartHeight: CGFloat = 320
    @State private var showImagingWindows = false
    @State private var showHelp = false
    @State private var selectedDay: DayResult?
    @State private var dismissTimer: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 8) {
                    legendItem(color: .blue, label: "Moon")
                    legendItem(color: .white, label: "Target")
                    legendItem(color: .orange, label: "Sep", dashed: true)
                    HStack(spacing: 3) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("<60°")
                    }
                    HStack(spacing: 3) {
                        Circle().fill(.yellow).frame(width: 6, height: 6)
                        Text("60-90°")
                    }
                    HStack(spacing: 3) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text(">90°")
                    }
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            }

            Toggle("Show Imaging Windows", isOn: $showImagingWindows)
                .font(.caption)
                .padding(.horizontal)

            ZStack(alignment: .topLeading) {
                chart
                    .frame(height: chartHeight)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 36)

                // Floating tooltip overlay
                if let day = selectedDay {
                    tooltip(day)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 3) {
            if dashed {
                HStack(spacing: 1) {
                    Rectangle().fill(color).frame(width: 3, height: 2)
                    Rectangle().fill(color).frame(width: 3, height: 2)
                }
            } else {
                Rectangle().fill(color).frame(width: 10, height: 2)
            }
            Text(label).foregroundStyle(color)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Dashed reference lines at ±30, ±60, ±90
            ForEach([30, 60, 90], id: \.self) { val in
                RuleMark(y: .value("Ref", val))
                    .foregroundStyle(.white.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                RuleMark(y: .value("Ref", -val))
                    .foregroundStyle(.white.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
            }

            // Horizon / center line
            RuleMark(y: .value("Horizon", 0))
                .foregroundStyle(.white.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 2))

            ForEach(Array(result.days.enumerated()), id: \.offset) { index, day in

                // Imaging window overlay (colored by separation quality)
                if showImagingWindows && day.imagingWindow.durationHours > 0 {
                    let windowColor = separationColor(day.angularSeparation, targetAlt: day.targetAlt)
                    BarMark(
                        x: .value("Date", day.dateLabel),
                        yStart: .value("Start", 30),
                        yEnd: .value("End", min(day.targetAlt, 90))
                    )
                    .foregroundStyle(windowColor.opacity(0.35))
                }

                // Moon altitude line
                LineMark(
                    x: .value("Date", day.dateLabel),
                    y: .value("Altitude", day.moonAlt),
                    series: .value("Series", "Moon Alt")
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))

                // Moon phase-colored markers
                PointMark(
                    x: .value("Date", day.dateLabel),
                    y: .value("Altitude", day.moonAlt)
                )
                .foregroundStyle(moonPhaseColor(day.moonPhase))
                .symbolSize(moonPhaseSize(day.moonPhase))

                // Target altitude line
                LineMark(
                    x: .value("Date", day.dateLabel),
                    y: .value("Altitude", day.targetAlt),
                    series: .value("Series", "Target Alt")
                )
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2))

                // Angular separation line (scaled to fit altitude axis)
                LineMark(
                    x: .value("Date", day.dateLabel),
                    y: .value("Separation", scaledSeparation(day.angularSeparation)),
                    series: .value("Series", "Separation")
                )
                .foregroundStyle(.orange.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 2]))

                // Separation point markers (colored by value)
                PointMark(
                    x: .value("Date", day.dateLabel),
                    y: .value("Separation", scaledSeparation(day.angularSeparation))
                )
                .foregroundStyle(separationColor(day.angularSeparation, targetAlt: day.targetAlt))
                .symbolSize(20)
            }

            // Vertical dashed lines at moon phase milestones (after data to preserve x-axis order)
            ForEach(phaseLines, id: \.dateLabel) { phase in
                RuleMark(x: .value("Phase", phase.dateLabel))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: -yExtent...yExtent)
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading, values: [-90.0, -60.0, -30.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(centered: false) {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))°")
                            .font(.caption2)
                    }
                }
            }
            AxisMarks(preset: .aligned, position: .leading, values: [0.0, 30.0, 60.0, 90.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(centered: false) {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))°")
                            .font(.caption2)
                    }
                }
            }
            AxisMarks(position: .trailing, values: separationTickPositions) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self),
                       let tick = separationTicks.first(where: { abs($0.position - v) < 0.1 }) {
                        Text("\(tick.label)°")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.caption2)
                            .fixedSize()
                            .rotationEffect(.degrees(-45))
                    }
                }
                AxisGridLine()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plotFrame = geo[proxy.plotFrame!]

                // Axis titles (vertical, running along each axis)
                Text("Altitude")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .position(
                        x: plotFrame.origin.x - 24,
                        y: plotFrame.midY
                    )
                Text("Angular Separation")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.7))
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .position(
                        x: plotFrame.origin.x + plotFrame.width + 40,
                        y: plotFrame.midY
                    )

                // Phase labels positioned at the top of each vertical line
                ForEach(Array(spacedPhaseLines(in: proxy, plotFrame: plotFrame).enumerated()), id: \.element.dateLabel) { _, phase in
                    if let xPos = proxy.position(forX: phase.dateLabel) {
                        Text(phase.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .fixedSize()
                            .position(
                                x: plotFrame.origin.x + xPos,
                                y: plotFrame.origin.y + 10
                            )
                    }
                }

                // Tap gesture for tooltip
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        selectDay(at: location, proxy: proxy, geo: geo)
                    }
            }
        }
    }

    // MARK: - Tooltip

    private func tooltip(_ day: DayResult) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day.dateLabel)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Circle().fill(Color.blue).frame(width: 6, height: 6)
                Text("Moon: \(day.moonAlt, specifier: "%.1f")° (\(day.moonPhase, specifier: "%.0f")%)")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 6, height: 6)
                Text("Target: \(day.targetAlt, specifier: "%.1f")°")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Sep: \(day.angularSeparation, specifier: "%.1f")°")
                    .foregroundColor(.orange)
            }
            if day.imagingWindow.durationHours > 0 {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Window: \(day.imagingWindow.durationHours, specifier: "%.1f")h")
                        .foregroundColor(.green)
                }
            }
        }
        .font(.caption2)
        .padding(10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .padding(8)
    }

    // MARK: - Moon Phase Vertical Lines

    /// Phase milestones to draw as vertical dashed lines
    private var phaseLines: [(dateLabel: String, label: String)] {
        let days = result.days
        guard days.count >= 3 else { return [] }

        var lines: [(String, String)] = []

        // New moon: global minimum phase
        if let day = days.min(by: { $0.moonPhase < $1.moonPhase }),
           day.moonPhase < 10 {
            lines.append((day.dateLabel, "New"))
        }

        // Full moon: global maximum phase
        if let day = days.max(by: { $0.moonPhase < $1.moonPhase }),
           day.moonPhase > 90 {
            lines.append((day.dateLabel, "Full"))
        }

        // 1st quarter: phase crosses 50% while waxing
        for i in 1..<days.count {
            if days[i - 1].moonPhase < 50 && days[i].moonPhase >= 50
                && (i + 1 >= days.count || days[i].moonPhase < days[i + 1].moonPhase) {
                lines.append((days[i].dateLabel, "1st Qtr"))
                break
            }
        }

        // 3rd quarter: phase crosses 50% while waning
        for i in 1..<days.count {
            if days[i - 1].moonPhase > 50 && days[i].moonPhase <= 50
                && (i + 1 >= days.count || days[i].moonPhase > days[i + 1].moonPhase) {
                lines.append((days[i].dateLabel, "3rd Qtr"))
                break
            }
        }

        return lines
    }

    /// Filter phase lines to remove overlapping labels
    private func spacedPhaseLines(in proxy: ChartProxy, plotFrame: CGRect) -> [(dateLabel: String, label: String)] {
        let all = phaseLines
        guard all.count > 1 else { return all }

        // Resolve x positions and sort by position
        var positioned: [(dateLabel: String, label: String, x: CGFloat)] = []
        for phase in all {
            if let xPos = proxy.position(forX: phase.dateLabel) {
                positioned.append((phase.dateLabel, phase.label, plotFrame.origin.x + xPos))
            }
        }
        positioned.sort { $0.x < $1.x }

        // Keep labels that are at least 50pt apart
        var result: [(dateLabel: String, label: String)] = []
        var lastX: CGFloat = -.infinity
        let minSpacing: CGFloat = 50
        for p in positioned {
            if p.x - lastX >= minSpacing {
                result.append((p.dateLabel, p.label))
                lastX = p.x
            }
        }
        return result
    }

    /// X-axis values: ~6 evenly spaced dates
    private var xAxisValues: [String] {
        let allLabels = result.days.map(\.dateLabel)
        guard allLabels.count > 1 else { return allLabels }

        let step = max(allLabels.count / 6, 1)
        var selected = Set<String>()
        for i in stride(from: 0, to: allLabels.count, by: step) {
            selected.insert(allLabels[i])
        }
        selected.insert(allLabels.last!)

        return allLabels.filter { selected.contains($0) }
    }

    // MARK: - Dual Y-Scale

    /// The symmetric extent based on altitude data only (not separation)
    private var yExtent: Double {
        let maxAlt = result.days.map(\.moonAlt).max() ?? 90
        let maxTargetAlt = result.days.map(\.targetAlt).max() ?? 90
        let minAlt = result.days.map(\.moonAlt).min() ?? -90
        let minTargetAlt = result.days.map(\.targetAlt).min() ?? -90
        let absMax = max(maxAlt, maxTargetAlt, abs(minAlt), abs(minTargetAlt), 30)
        return ceil(absMax / 30.0) * 30.0
    }

    /// Maximum separation value for scaling the right axis
    private var maxSeparation: Double {
        let maxSep = result.days.map(\.angularSeparation).max() ?? 180
        return ceil(maxSep / 30.0) * 30.0
    }

    /// Scale a separation value into the altitude Y domain
    private func scaledSeparation(_ sep: Double) -> Double {
        sep * yExtent / maxSeparation
    }

    private var altitudeTickValues: [Double] {
        let ext = Int(yExtent)
        return stride(from: -ext, through: ext, by: 30).map { Double($0) }
    }

    /// Right axis tick positions (in altitude-domain units) with original separation labels
    private var separationTicks: [(position: Double, label: Int)] {
        let step = maxSeparation <= 90 ? 15.0 : 30.0
        var ticks: [(Double, Int)] = []
        var sep = 0.0
        while sep <= maxSeparation {
            ticks.append((scaledSeparation(sep), Int(sep)))
            sep += step
        }
        return ticks
    }

    private var separationTickPositions: [Double] {
        separationTicks.map(\.position)
    }

    // MARK: - Helpers

    private func moonPhaseColor(_ phase: Double) -> Color {
        let t = phase / 100.0
        return Color(
            red: 0.2 + 0.8 * t,
            green: 0.2 + 0.6 * t,
            blue: 0.3 * (1 - t)
        )
    }

    private func moonPhaseSize(_ phase: Double) -> CGFloat {
        20 + 30 * phase / 100.0
    }

    private func separationColor(_ sep: Double, targetAlt: Double) -> Color {
        if targetAlt < 0 { return .red }
        if sep >= 90 { return .green }
        if sep >= 60 { return .yellow }
        return .red
    }

    private func selectDay(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotFrame = geo[proxy.plotFrame!]
        let xPos = location.x - plotFrame.origin.x

        guard let dateLabel: String = proxy.value(atX: xPos) else { return }
        selectedDay = result.days.first { $0.dateLabel == dateLabel }

        // Auto-dismiss after 5 seconds
        dismissTimer?.cancel()
        dismissTimer = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation {
                        selectedDay = nil
                    }
                }
            }
        }
    }
}
