import SwiftUI
import Charts

struct NightBarChartView: View {
    let result: CalculationResult
    var title: String = "Nightly Target Visibility"
    var chartHeight: CGFloat = 320
    var moonTierConfig: MoonTierConfig = .defaults

    @State private var selectedDay: DayResult?
    @State private var showHelp = false

    private let barSpacing: CGFloat = 4

    private let moonColor: Color = .yellow.opacity(0.8)

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

    /// Total sub-bars per column: moon + targets
    private var barCount: Int {
        targetCount + 1
    }

    /// Width of the full column (gray background bar) for one night
    private var columnWidth: CGFloat {
        switch barCount {
        case 0, 1: return 24
        case 2: return 28
        case 3, 4: return 34
        case 5, 6: return 40
        default: return 46
        }
    }

    /// Width of each individual sub-bar (moon or target) within a column
    private var subBarWidth: CGFloat {
        if barCount <= 1 { return columnWidth }
        return (columnWidth - CGFloat(barCount - 1) * 1) / CGFloat(barCount)
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
                    Rectangle().fill(moonColor).frame(width: 10, height: 10)
                    Text("Moon")
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
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .padding(8)
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

                    // Background bar: color represents moon brightness
                    BarMark(
                        x: .value("Date", day.dateLabel),
                        yStart: .value("Start", darkStart),
                        yEnd: .value("End", darkEnd),
                        width: .fixed(columnWidth)
                    )
                    .foregroundStyle(moonBarColor(day.moonPhase))

                    // Moon visibility bar (first sub-bar, yellow)
                    if let moonVis = day.moonVisibility {
                        let moonStart = hoursFromCenter(moonVis.riseTime, night: night)
                        let moonEnd = hoursFromCenter(moonVis.setTime, night: night)

                        BarMark(
                            x: .value("Date", day.dateLabel),
                            yStart: .value("VisStart", moonStart),
                            yEnd: .value("VisEnd", moonEnd),
                            width: .fixed(subBarWidth)
                        )
                        .foregroundStyle(moonColor)
                        .position(by: .value("Target", "Moon"))
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

    // MARK: - Tooltip

    private func tooltip(_ day: DayResult) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day.dateLabel)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            if let night = day.nightWindow {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.gray)
                        .font(.system(size: 8))
                    Text("Dark: \(formatTime(night.darknessStart)) – \(formatTime(night.darknessEnd))")
                }

                Text("(\(night.darkHours, specifier: "%.1f") hrs)")
                    .foregroundStyle(.secondary)
            }

            // Per-target visibility + imaging rating
            ForEach(day.targetResults, id: \.targetName) { tr in
                if let vis = tr.visibility {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(targetColors[tr.colorIndex])
                            .frame(width: 6, height: 6)
                        Text("\(tr.targetName): \(formatTime(vis.riseTime)) \u{2013} \(formatTime(vis.setTime))")
                            .foregroundStyle(targetColors[tr.colorIndex])
                    }
                    Text("  \(vis.durationHours, specifier: "%.1f") hrs  Sep: \(tr.angularSeparation, specifier: "%.0f")\u{00B0}")
                        .foregroundStyle(targetColors[tr.colorIndex])

                    let rating = moonTierConfig.evaluate(
                        moonPhase: day.moonPhase,
                        angularSeparation: tr.angularSeparation
                    )
                    HStack(spacing: 3) {
                        Image(systemName: rating.symbol)
                            .font(.system(size: 7))
                            .foregroundStyle(rating.color)
                        Text(rating.label)
                            .foregroundStyle(rating.color)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(targetColors[tr.colorIndex])
                            .frame(width: 6, height: 6)
                        Text("\(tr.targetName): not visible")
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack(spacing: 4) {
                Circle().fill(moonColor).frame(width: 6, height: 6)
                if let moonVis = day.moonVisibility {
                    Text("Moon (\(day.moonPhase, specifier: "%.0f")%): \(formatTime(moonVis.riseTime)) \u{2013} \(formatTime(moonVis.setTime))")
                        .foregroundStyle(moonColor)
                } else {
                    Text("Moon (\(day.moonPhase, specifier: "%.0f")%): below horizon")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption2)
        .padding(10)
        .background(Color.black.opacity(0.9))
        .cornerRadius(8)
        .padding(8)
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// Background bar color: grayscale from near-black (new moon) to subdued gray (full moon)
    private func moonBarColor(_ phase: Double) -> Color {
        let t = min(max(phase / 100.0, 0), 1)
        // 0% moon → 0.03 (blacker), 100% moon → 0.55 (brighter)
        let w = 0.03 + 0.52 * t
        return Color(white: w)
    }

    private func moonPhaseColor(_ phase: Double) -> Color {
        let t = phase / 100.0
        return Color(
            red: 0.2 + 0.8 * t,
            green: 0.2 + 0.6 * t,
            blue: 0.3 * (1 - t)
        )
    }

    private func selectDay(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        if selectedDay != nil {
            // Second tap dismisses
            withAnimation { selectedDay = nil }
            return
        }

        let plotFrame = geo[proxy.plotFrame!]
        let xPos = location.x - plotFrame.origin.x

        guard let dateLabel: String = proxy.value(atX: xPos) else { return }
        withAnimation { selectedDay = result.days.first { $0.dateLabel == dateLabel } }
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
