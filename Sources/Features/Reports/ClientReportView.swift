import Charts
import SwiftUI

struct ClientReportView: View {
    @State var viewModel: ClientReportViewModel

    var body: some View {
        List {
            if viewModel.exercisesWithData.isEmpty {
                ContentUnavailableView(
                    "No completed sessions yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Progress charts appear after recording sets in completed sessions.")
                )
            } else {
                Section {
                    Picker("Exercise", selection: $viewModel.selectedExerciseId) {
                        ForEach(viewModel.exercisesWithData) { exercise in
                            Text(exercise.name).tag(UUID?.some(exercise.id))
                        }
                    }
                }

                if let pb = viewModel.personalBest, let weight = pb.weight {
                    Section {
                        LabeledContent("Personal best") {
                            Text("\(weight.formatted()) lb")
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section("Top-set weight") {
                    ExerciseProgressChart(
                        points: viewModel.points,
                        personalBest: viewModel.personalBest,
                        metric: \.topSetWeight
                    )
                }
                Section("Estimated 1RM (Epley)") {
                    ExerciseProgressChart(
                        points: viewModel.points,
                        personalBest: nil,
                        metric: \.est1RM
                    )
                }
            }
        }
        .navigationTitle("\(viewModel.client.name) — Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pdfURL {
                ShareLink(item: pdfURL) {
                    Label("Share report", systemImage: "square.and.arrow.up")
                }
            }
        }
        .task {
            await viewModel.load()
            renderPDF()
        }
        .onChange(of: viewModel.selectedExerciseId) {
            Task {
                await viewModel.loadChart()
                renderPDF()
            }
        }
    }

    @State private var pdfURL: URL?

    private func renderPDF() {
        guard viewModel.hasEnoughData,
              let exercise = viewModel.exercisesWithData.first(where: { $0.id == viewModel.selectedExerciseId })
        else {
            pdfURL = nil
            return
        }
        pdfURL = try? ReportExporter.renderPDF(
            clientName: viewModel.client.name,
            exerciseName: exercise.name,
            points: viewModel.points,
            personalBest: viewModel.personalBest
        )
    }
}

struct ExerciseProgressChart: View {
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?
    let metric: KeyPath<ProgressPoint, Double>

    var body: some View {
        if points.count < 2 {
            ContentUnavailableView(
                "Not enough data yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Record this exercise in at least two completed sessions.")
            )
            .frame(height: 180)
        } else {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Weight", point[keyPath: metric])
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
            .chartYAxisLabel("lb")
            .frame(height: 220)
            .padding(.vertical, 4)
        }
    }
}
