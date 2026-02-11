import SwiftUI
import Charts

struct NightBarChartView: View {
    let result: CalculationResult
    var title: String = "Nightly Target Visibility"
    var chartHeight: CGFloat = 320
    var moonTierConfig: MoonTierConfig = .defaults

    @State private var selectedDay: DayResult?
    @State private var selectedTarget: TargetNightResult?
    @State private var showHelp = false

    private let barSpacing: CGFloat = 4

    private let targetColors: [Color] = [
        .cyan.opacity(0.8),
        .orange.opacity(0.8),
        .pink.opacity(0.8),
        .purple.opacity(0.8),
        .teal.opacity(0.8),
        .blue.opacity(0.8)
    ]

    private var targetCount: Int {
        result.targetNames.count
    }

    /// Width of the full column (background + glow) for one night
    private var columnWidth: CGFloat {
        switch targetCount {
        case 0, 1: return 24
        case 2: return 28
        case 3, 4: return 34
        case 5, 6: return 40
        default: return 46
        }
    }

    /// Width of each individual target sub-bar within a column
    private var subBarWidth: CGFloat {
        if targetCount <= 1 { return columnWidth }
        return (columnWidth - CGFloat(targetCount - 1) * 1) / CGFloat(targetCount)
    }

    /// Moon glow color: white, with sharp horizon edge and altitude-based brightness
    private func moonGlowColor(altitude: Double, phase: Double) -> Color {
        guard altitude > 0 else { return .clear }
        let phaseFactor = phase / 100.0
        // Sharp edge at horizon (base 0.15) ramping up to 0.60 at high altitude
        let altNorm = min(altitude / 55.0, 1.0)
        let intensity = (0.15 + 0.45 * altNorm) * phaseFactor
        return Color.white.opacity(intensity)
    }

    private var chartWidth: CGFloat {
        CGFloat(result.days.count) * (columnWidth + barSpacing) + 80
    }

    // MARK: - Clock-time Y-axis

    /// Hours from 1 AM center for a given Date
    private func hoursFromCenter(_ date: Date, night: NightWindow) -> Double {
        let center = night.midnight.addingTimeInterval(3600) // 1 AM
        return date.timeIntervalSince(center) / 3600.0
    }

    /// Y-axis bounds: earliest darkness start and latest darkness end across all nights
    private var yDomain: ClosedRange<Double> {
        var minY: Double = -6
        var maxY: Double = 5
        for day in result.days {
            guard let night = day.nightWindow else { continue }
            let start = hoursFromCenter(night.darknessStart, night: night)
            let end = hoursFromCenter(night.darknessEnd, night: night)
            if start < minY { minY = start }
            if end > maxY { maxY = end }
        }
        return floor(minY)...ceil(maxY)
    }

    /// All whole-hour tick values within the y domain
    private var hourTicks: [Double] {
        let range = yDomain
        return Array(stride(from: range.lowerBound, through: range.upperBound, by: 1))
    }

    /// Convert hours-from-1AM to a clock label like "9 PM", "1 AM"
    private func clockLabel(for offset: Double) -> String {
        // offset 0 = 1 AM, offset -1 = 12 AM, offset -5 = 8 PM, offset +4 = 5 AM
        let hour24 = ((Int(offset) + 1) % 24 + 24) % 24 // +1 because center is 1 AM
        if hour24 == 0 { return "12 AM" }
        if hour24 < 12 { return "\(hour24) AM" }
        if hour24 == 12 { return "12 PM" }
        return "\(hour24 - 12) PM"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Legend (wrapping flow layout)
            FlowLayout(spacing: 8) {
                HStack(spacing: 3) {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 10, height: 10)
                    Text("Dark hrs")
                }
                HStack(spacing: 3) {
                    Rectangle().fill(Color.white.opacity(0.35)).frame(width: 10, height: 10)
                    Text("Moon glow")
                }
                ForEach(Array(result.targetNames.enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 3) {
                        Rectangle().fill(targetColors[index]).frame(width: 10, height: 10)
                        Text(name)
                    }
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

            // Scrollable bar chart
            ScrollView(.horizontal, showsIndicators: true) {
                chart
                    .frame(width: chartWidth, height: chartHeight)
                    .padding(.bottom, 36)
            }
            .overlay(alignment: .topLeading) {
                if let day = selectedDay {
                    tooltip(day)
                        .transition(.opacity)
                        .padding(8)
                }
            }
            .sheet(item: $selectedTarget) { target in
                if let day = selectedDay {
                    targetDetailSheet(day: day, target: target)
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Data bars first (preserves x-axis category ordering)
            ForEach(Array(result.days.enumerated()), id: \.offset) { index, day in
                if let night = day.nightWindow {
                    let darkStart = hoursFromCenter(night.darknessStart, night: night)
                    let darkEnd = hoursFromCenter(night.darknessEnd, night: night)

                    // Background bar: dark sky
                    BarMark(
                        x: .value("Date", day.dateLabel),
                        yStart: .value("Start", darkStart),
                        yEnd: .value("End", darkEnd),
                        width: .fixed(columnWidth)
                    )
                    .foregroundStyle(Color(white: 0.03))

                    // Moon glow: stacked thin bars, brightness = altitude × phase
                    let stepHours = 20.0 / 60.0  // 20-minute steps in hours
                    ForEach(Array(day.moonAltitudeProfile.enumerated()), id: \.offset) { si, sample in
                        let yPos = hoursFromCenter(sample.time, night: night)
                        BarMark(
                            x: .value("Date", day.dateLabel),
                            yStart: .value("GlowStart", yPos),
                            yEnd: .value("GlowEnd", yPos + stepHours),
                            width: .fixed(columnWidth)
                        )
                        .foregroundStyle(moonGlowColor(altitude: sample.altitude, phase: day.moonPhase))
                    }

                    // Target visibility bars — side by side using position grouping
                    ForEach(day.targetResults, id: \.targetName) { tr in
                        if let vis = tr.visibility {
                            let visStart = hoursFromCenter(vis.riseTime, night: night)
                            let visEnd = hoursFromCenter(vis.setTime, night: night)

                            BarMark(
                                x: .value("Date", day.dateLabel),
                                yStart: .value("VisStart", visStart),
                                yEnd: .value("VisEnd", visEnd),
                                width: .fixed(subBarWidth)
                            )
                            .foregroundStyle(targetColors[tr.colorIndex])
                            .position(by: .value("Target", tr.targetName))
                        }
                    }
                }
            }

            // Hourly dashed lines (after data to preserve x-axis order)
            ForEach(hourTicks, id: \.self) { hour in
                if hour == 0 {
                    // 1 AM center line — solid
                    RuleMark(y: .value("Center", 0))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                } else {
                    RuleMark(y: .value("Hour", hour))
                        .foregroundStyle(.white.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: hourTicks.filter { Int($0) % 2 == 0 }) { value in
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(clockLabel(for: v))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
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
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        selectDay(at: location, proxy: proxy, geo: geo)
                    }
            }
        }
    }

    // MARK: - Tooltip (summary popup)

    private func tooltip(_ day: DayResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: date + dismiss
            HStack {
                Text(day.dateLabel)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation { selectedDay = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 14))
                }
            }

            // Dark hours
            if let night = day.nightWindow {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(.gray)
                        .font(.system(size: 9))
                    Text("Dark: \(formatTime(night.darknessStart)) – \(formatTime(night.darknessEnd)) (\(night.darkHours, specifier: "%.1f") hrs)")
                }
            }

            // Moon summary
            HStack(spacing: 4) {
                Circle().fill(Color(white: 0.25 + 0.75 * min(max(day.moonPhase / 100.0, 0), 1)))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                Text("Moon \(day.moonPhase, specifier: "%.0f")%")
                    .foregroundStyle(Color.yellow.opacity(0.8))
                if day.moonVisibility != nil {
                    Text("(visible)")
                        .foregroundStyle(Color.yellow.opacity(0.5))
                } else {
                    Text("(below horizon)")
                        .foregroundStyle(.secondary)
                }
            }

            Divider().background(.white.opacity(0.3))

            // Tappable target list
            Text("Tap a target for details:")
                .foregroundStyle(.secondary)
                .font(.system(size: 9))

            ForEach(day.targetResults) { tr in
                let result = moonTierConfig.evaluateMoonAwareWithReason(
                    moonPhase: day.moonPhase,
                    hoursMoonDown: tr.hoursMoonDown,
                    hoursMoonUp: tr.hoursMoonUp,
                    avgSeparationMoonUp: tr.avgSeparationMoonUp
                )
                Button {
                    selectedTarget = tr
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(targetColors[tr.colorIndex])
                                .frame(width: 8, height: 8)
                            Text(tr.targetName)
                                .foregroundStyle(targetColors[tr.colorIndex])
                            Spacer()
                            Image(systemName: result.rating.symbol)
                                .font(.system(size: 9))
                                .foregroundStyle(result.rating.color)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Text(result.reason)
                            .font(.system(size: 8))
                            .foregroundStyle(result.rating.color.opacity(0.7))
                    }
                }
            }
        }
        .font(.caption2)
        .padding(12)
        .background(Color.black.opacity(0.92))
        .cornerRadius(10)
        .frame(maxWidth: 220)
    }

    // MARK: - Target Detail Sheet

    private func targetDetailSheet(day: DayResult, target: TargetNightResult) -> some View {
        NavigationStack {
            List {
                Section("Visibility") {
                    if let vis = target.visibility {
                        let azDiff = abs(vis.riseAzimuth - vis.setAzimuth)
                        let isNarrowArc = azDiff < 5 || azDiff > 355  // handles wrap-around at 0°/360°

                        if isNarrowArc {
                            // Azimuths nearly identical — collapse to single line
                            let avgAz = vis.riseAzimuth
                            LabeledContent(
                                "Visible near \(Int(avgAz))\u{00B0} (\(cardinalLabel(avgAz))) above \(Int(vis.riseMinAlt))\u{00B0}",
                                value: "\(formatTime(vis.riseTime)) – \(formatTime(vis.setTime))"
                            )
                        } else {
                            // Rise label
                            if vis.alreadyUpAtStart {
                                LabeledContent(
                                    "Already up at \(Int(vis.riseAzimuth))\u{00B0} (\(cardinalLabel(vis.riseAzimuth)))",
                                    value: formatTime(vis.riseTime)
                                )
                            } else {
                                LabeledContent(
                                    "Rises above \(Int(vis.riseMinAlt))\u{00B0} at \(Int(vis.riseAzimuth))\u{00B0} (\(cardinalLabel(vis.riseAzimuth)))",
                                    value: formatTime(vis.riseTime)
                                )
                            }

                            // Set label
                            if vis.stillUpAtEnd {
                                LabeledContent(
                                    "Still up at \(Int(vis.setAzimuth))\u{00B0} (\(cardinalLabel(vis.setAzimuth)))",
                                    value: formatTime(vis.setTime)
                                )
                            } else {
                                LabeledContent(
                                    "Sets below \(Int(vis.setMinAlt))\u{00B0} at \(Int(vis.setAzimuth))\u{00B0} (\(cardinalLabel(vis.setAzimuth)))",
                                    value: formatTime(vis.setTime)
                                )
                            }
                        }
                        LabeledContent("Duration", value: String(format: "%.1f hrs", vis.durationHours))
                    } else {
                        Text("Not visible this night")
                            .foregroundStyle(.red)
                    }
                }

                Section("Moon Interaction") {
                    LabeledContent("Moon Phase", value: String(format: "%.0f%%", day.moonPhase))

                    if let moonVis = day.moonVisibility {
                        LabeledContent("Moon Up", value: "\(formatTime(moonVis.riseTime)) – \(formatTime(moonVis.setTime))")
                    } else {
                        LabeledContent("Moon", value: "Below horizon all night")
                    }

                    LabeledContent("Angular Separation", value: String(format: "%.0f\u{00B0}", target.angularSeparation))

                    let ratingResult = moonTierConfig.evaluateMoonAwareWithReason(
                        moonPhase: day.moonPhase,
                        hoursMoonDown: target.hoursMoonDown,
                        hoursMoonUp: target.hoursMoonUp,
                        avgSeparationMoonUp: target.avgSeparationMoonUp
                    )
                    HStack {
                        Text("Imaging Rating")
                        Spacer()
                        Image(systemName: ratingResult.rating.symbol)
                            .foregroundStyle(ratingResult.rating.color)
                        Text(ratingResult.rating.label)
                            .foregroundStyle(ratingResult.rating.color)
                    }
                    Text(ratingResult.reason)
                        .font(.caption)
                        .foregroundStyle(ratingResult.rating.color.opacity(0.8))
                }

                Section("Moon-Free Imaging") {
                    if target.hoursMoonDown > 0 {
                        LabeledContent("Moon-free hours", value: String(format: "%.1f hrs", target.hoursMoonDown))
                            .foregroundStyle(.green)
                    }
                    if target.hoursMoonUp > 0 {
                        LabeledContent("Moon-up hours", value: String(format: "%.1f hrs", target.hoursMoonUp))
                        if let sep = target.avgSeparationMoonUp {
                            LabeledContent("Avg separation (moon up)", value: String(format: "%.0f\u{00B0}", sep))
                        }
                    }
                    if target.hoursMoonDown <= 0 && target.hoursMoonUp <= 0 {
                        Text("Target not visible this night")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Position") {
                    LabeledContent("Target Altitude", value: String(format: "%.1f\u{00B0}", target.targetAlt))
                }

                if let night = day.nightWindow {
                    Section("Night") {
                        LabeledContent("Darkness Start", value: formatTime(night.darknessStart))
                        LabeledContent("Darkness End", value: formatTime(night.darknessEnd))
                        LabeledContent("Dark Hours", value: String(format: "%.1f hrs", night.darkHours))
                    }
                }
            }
            .navigationTitle("\(target.targetName) – \(day.dateLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedTarget = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// Convert azimuth degrees to cardinal direction label (e.g., 95° → "E", 225° → "SW")
    private func cardinalLabel(_ azimuth: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((azimuth + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return directions[index % 16]
    }

    private func selectDay(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotFrame = geo[proxy.plotFrame!]
        let xPos = location.x - plotFrame.origin.x

        guard let dateLabel: String = proxy.value(atX: xPos) else {
            withAnimation { selectedDay = nil }
            return
        }

        let tapped = result.days.first { $0.dateLabel == dateLabel }
        withAnimation {
            if selectedDay?.dateLabel == tapped?.dateLabel {
                selectedDay = nil  // Tap same day = dismiss
            } else {
                selectedDay = tapped
            }
        }
    }
}

// MARK: - Flow Layout (wrapping HStack)

/// A layout that flows items horizontally, wrapping to the next line when needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
