import Charts
import SwiftUI

struct ClientReportView: View {
    @State var viewModel: ClientReportViewModel

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
            if viewModel.exercisesWithData.isEmpty {
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
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                Section("Exercises") {
                    ForEach(viewModel.exercisesWithData) { exercise in
                        NavigationLink(exercise.name) {
                            ExerciseReportView(viewModel: ExerciseReportViewModel(
                                reporting: viewModel.reporting, client: viewModel.client, exercise: exercise
                            ))
                        }
                    }
                }
            }
        }
        .navigationTitle("\(viewModel.client.name) — Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: viewModel.window) { Task { await viewModel.reloadWindow() } }
    }
}

struct ExerciseProgressChart: View {
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?
    let metric: KeyPath<ProgressPoint, Double?>
    let unitLabel: String

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
            .frame(height: 180)
        } else {
            Chart {
                ForEach(plotted, id: \.point.id) { entry in
                    LineMark(
                        x: .value("Date", entry.point.date, unit: .day),
                        y: .value(unitLabel, entry.value)
                    )
                    .interpolationMethod(.monotone)
                    .symbol(.circle)
                }
                if let pb = personalBest, let weight = pb.weight {
                    PointMark(
                        x: .value("Date", Calendar.current.startOfDay(for: pb.performedAt), unit: .day),
                        y: .value("Weight", weight)
                    )
                    .foregroundStyle(.orange)
                    .annotation(position: .top, alignment: .center) {
                        Text("PB")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            .chartYAxisLabel(unitLabel)
            .frame(height: 220)
            .padding(.vertical, 4)
        }
    }
}
