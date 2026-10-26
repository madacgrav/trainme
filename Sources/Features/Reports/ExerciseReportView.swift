import Charts
import SwiftUI

struct ExerciseReportView: View {
    @State var viewModel: ExerciseReportViewModel
    @State private var pdfURL: URL?

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
            if let pb = viewModel.personalBest, let weight = pb.weight {
                Section {
                    LabeledContent("Personal best") {
                        Text(WeightFormatter.string(weight, unit: viewModel.unit)).fontWeight(.semibold)
                    }
                }
            }
            Section("Top-set weight") {
                ExerciseProgressChart(points: viewModel.points, personalBest: viewModel.personalBest,
                                      metric: \.topSetWeight, unitLabel: WeightFormatter.label(viewModel.unit))
            }
            Section("Estimated 1RM (Epley)") {
                ExerciseProgressChart(points: viewModel.points, personalBest: nil,
                                      metric: \.est1RM, unitLabel: WeightFormatter.label(viewModel.unit))
            }
            Section("Total reps") {
                ExerciseProgressChart(points: viewModel.points, personalBest: nil,
                                      metric: \.totalRepsMetric, unitLabel: "reps")
            }
            Section("History") {
                if viewModel.history.isEmpty {
                    Text("No sets recorded yet").foregroundStyle(.secondary)
                }
                ForEach(viewModel.history) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.sessionStart.formatted(date: .abbreviated, time: .omitted))
                        Text(viewModel.summary(of: entry.sets))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(viewModel.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pdfURL {
                ShareLink(item: pdfURL) { Label("Share report", systemImage: "square.and.arrow.up") }
            }
        }
        .task { await viewModel.load(); renderPDF() }
        .onDisappear {
            // Rendered reports hold client PII: sweep them once the screen is gone.
            pdfURL = nil
            ReportExporter.removeReports()
        }
    }

    private func renderPDF() {
        guard viewModel.hasEnoughData else { pdfURL = nil; return }
        pdfURL = try? ReportExporter.renderPDF(
            clientName: viewModel.client.name, exerciseName: viewModel.exercise.name,
            points: viewModel.points, personalBest: viewModel.personalBest, unit: viewModel.unit
        )
    }
}
