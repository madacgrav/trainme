import Charts
import SwiftUI

struct ClientReportView: View {
    @State var viewModel: ClientReportViewModel
    @State private var files: ReportFiles?
    @State private var exportError: String?

    var body: some View {
        List {
            ErrorBanner(message: viewModel.errorMessage)
            ErrorBanner(message: exportError)
            if viewModel.topExercises.isEmpty {
                ContentUnavailableView(
                    "No completed sessions yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Progress charts appear after recording sets in completed sessions.")
                )
            } else {
                Section {
                    Picker("Window", selection: $viewModel.window) {
                        ForEach(ReportWindow.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if let c = viewModel.consistency {
                    Section("Consistency") {
                        if let rate = c.rate {
                            LabeledContent("Completed") {
                                Text(rate.formatted(.percent.precision(.fractionLength(0)))).fontWeight(.semibold)
                            }
                            Text("\(c.completed) completed · \(c.cancelled) cancelled · \(c.noShow) no-show")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("No resolved sessions in this window").foregroundStyle(.secondary)
                        }
                        if c.unresolved > 0 {
                            Text("\(c.unresolved) past \(c.unresolved == 1 ? "session" : "sessions") still marked scheduled")
                                .font(.caption).foregroundStyle(Theme.Colors.warning)
                        }
                    }
                }
                Section("Weekly volume") {
                    VolumeChart(weeks: viewModel.weeklyVolumes)
                }
                Section("Sessions") {
                    if viewModel.sessionVolumes.isEmpty {
                        Text("No completed sessions in this window").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.sessionVolumes) { session in
                        LabeledContent(session.start.formatted(date: .abbreviated, time: .omitted)) {
                            Text(WeightFormatter.volumeString(session.totals))
                        }
                    }
                }
                Section("Top exercises") {
                    ForEach(viewModel.topExercises) { item in
                        NavigationLink {
                            ExerciseReportView(viewModel: ExerciseReportViewModel(
                                reporting: viewModel.reporting, client: viewModel.client, exercise: item.exercise))
                        } label: {
                            TitleCaptionRow(title: item.exercise.name, caption: ClientReportViewModel.detail(for: item))
                        }
                    }
                }
            }
        }
        .themedScreen()
        .navigationTitle("\(viewModel.client.name) — Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareReportMenu(files: files)
        }
        .task { await viewModel.load(); renderReport() }
        .onChange(of: viewModel.window) { Task { await viewModel.reloadWindow(); renderReport() } }
        .onDisappear {
            // Rendered reports hold client PII: sweep them once the screen is gone.
            files = nil
            ReportExporter.removeReports()
        }
    }

    private func renderReport() {
        exportError = nil
        guard !viewModel.topExercises.isEmpty else { files = nil; return }
        do {
            files = try ReportExporter.render(
                ClientOverviewPage(clientName: viewModel.client.name, window: viewModel.window,
                                   consistency: viewModel.consistency, weeks: viewModel.weeklyVolumes,
                                   topExercises: viewModel.topExercises.map { ($0.exercise.name, ClientReportViewModel.detail(for: $0)) }),
                baseName: "\(viewModel.client.name) — Overview")
        } catch {
            Log.ui.error("report render failed: \(error.localizedDescription)")
            files = nil
            exportError = "Couldn't prepare the report for sharing."
        }
    }
}

struct ExerciseProgressChart: View {
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?
    let metric: KeyPath<ProgressPoint, Double?>
    let unitLabel: String
    var height: CGFloat = 220

    /// Only days that have this metric are plotted and counted.
    private var plotted: [(point: ProgressPoint, value: Double)] {
        points.compactMap { point in point[keyPath: metric].map { (point, $0) } }
    }

    var body: some View {
        if plotted.count < ProgressPoint.minimumPoints {
            ContentUnavailableView(
                "Not enough data yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Record this exercise in at least two completed sessions.")
            )
            .frame(height: height - 40)
        } else {
            Chart {
                ForEach(plotted, id: \.point.id) { entry in
                    LineMark(
                        x: .value("Date", entry.point.date, unit: .day),
                        y: .value(unitLabel, entry.value)
                    )
                    .interpolationMethod(.monotone)
                    .symbol(.circle)
                    .foregroundStyle(Theme.Colors.brandPrimary)
                }
                if let pb = personalBest, let weight = pb.weight {
                    PointMark(
                        x: .value("Date", Calendar.current.startOfDay(for: pb.performedAt), unit: .day),
                        y: .value("Weight", weight)
                    )
                    .foregroundStyle(Theme.Colors.personalBest)
                    .annotation(position: .top, alignment: .center) {
                        Text("PB")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.Colors.personalBest)
                    }
                }
            }
            .chartYAxisLabel(unitLabel)
            .accessibilityLabel("\(unitLabel) over time, \(plotted.count) points, latest \(plotted.last?.value.formatted() ?? "none")")
            .frame(height: height)
            .padding(.vertical, 4)
        }
    }
}

struct VolumeChart: View {
    let weeks: [WeeklyVolume]
    var height: CGFloat = 220

    private struct Bar: Identifiable {
        let id: String
        let week: Date
        let unit: String
        let amount: Double
    }

    private var bars: [Bar] {
        weeks.flatMap { week in
            [Unit.lb, .kg].compactMap { unit in
                guard let amount = week.totals.byUnit[unit], amount > 0 else { return nil }
                return Bar(id: "\(week.id.timeIntervalSince1970)-\(unit.rawValue)", week: week.id,
                           unit: WeightFormatter.label(unit), amount: amount)
            }
        }
    }

    var body: some View {
        if weeks.count < ProgressPoint.minimumPoints {
            ContentUnavailableView("Not enough data yet", systemImage: "chart.bar",
                                   description: Text("Volume appears after two weeks of completed sessions."))
            .frame(height: height - 40)
        } else {
            Chart(bars) { bar in
                BarMark(x: .value("Week", bar.week, unit: .weekOfYear), y: .value("Volume", bar.amount))
                    .foregroundStyle(by: .value("Unit", bar.unit))
            }
            .chartYAxisLabel("weight × reps")
            .chartForegroundStyleScale(["lb": Theme.Colors.brandPrimary, "kg": Theme.Colors.brandSecondary])
            .accessibilityLabel("Weekly volume, \(weeks.count) weeks")
            .frame(height: height)
            .padding(.vertical, 4)
        }
    }
}

#Preview("Client report") {
    let repos = PreviewFixtures.repositories()
    NavigationStack {
        ClientReportView(viewModel: ClientReportViewModel(
            reporting: repos.reporting, exerciseRepo: repos.exercises, client: PreviewFixtures.client
        ))
    }
}
