import Charts
import SwiftUI

struct ExerciseReportView: View {
    @State var viewModel: ExerciseReportViewModel
    @State private var files: ReportFiles?
    @State private var exportError: String?

    var body: some View {
        List {
            ErrorBanner(message: viewModel.errorMessage)
            ErrorBanner(message: exportError)
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
                    TitleCaptionRow(
                        title: entry.sessionStart.formatted(date: .abbreviated, time: .omitted),
                        caption: viewModel.summary(of: entry.sets)
                    )
                }
            }
        }
        .themedScreen()
        .navigationTitle(viewModel.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareReportMenu(files: files)
        }
        .task { await viewModel.load(); renderReport() }
        .onDisappear {
            // Rendered reports hold client PII: sweep them once the screen is gone.
            files = nil
            ReportExporter.removeReports()
        }
    }

    private func renderReport() {
        exportError = nil
        guard viewModel.hasEnoughData else { files = nil; return }
        do {
            files = try ReportExporter.render(
                ExerciseReportPage(clientName: viewModel.client.name, exerciseName: viewModel.exercise.name,
                                   points: viewModel.points, personalBest: viewModel.personalBest, unit: viewModel.unit),
                baseName: "\(viewModel.client.name) — \(viewModel.exercise.name) Progress")
        } catch {
            Log.ui.error("report render failed: \(error.localizedDescription)")
            files = nil
            exportError = "Couldn't prepare the report for sharing."
        }
    }
}

#Preview("Exercise report") {
    let repos = PreviewFixtures.repositories()
    NavigationStack {
        ExerciseReportView(viewModel: ExerciseReportViewModel(
            reporting: repos.reporting, client: PreviewFixtures.client, exercise: PreviewFixtures.bench
        ))
    }
}
