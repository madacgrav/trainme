import SwiftUI
import UIKit

/// Renders a client progress report to a shareable PDF.
enum ReportExporter {
    @MainActor
    static func renderPDF(
        clientName: String,
        exerciseName: String,
        points: [ProgressPoint],
        personalBest: SetRecordDTO?
    ) throws -> URL {
        let content = ReportPage(
            clientName: clientName,
            exerciseName: exerciseName,
            points: points,
            personalBest: personalBest
        )
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = .init(width: 612, height: 792) // US Letter @72dpi

        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(clientName) — \(exerciseName) Progress.pdf")

        var renderError: Error?
        renderer.render { size, renderIn in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
                renderError = CocoaError(.fileWriteUnknown)
                return
            }
            context.beginPDFPage(nil)
            renderIn(context)
            context.endPDFPage()
            context.closePDF()
        }
        if let renderError { throw renderError }
        return url
    }
}

/// The printable report page (also reused by the in-app share preview).
struct ReportPage: View {
    let clientName: String
    let exerciseName: String
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TrainMe Progress Report")
                .font(.title.bold())
            Text(clientName)
                .font(.title2)
            Text(exerciseName)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let pb = personalBest, let weight = pb.weight {
                Text("Personal best: \(weight.formatted()) lb on \(pb.performedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
            }

            ExerciseProgressChart(points: points, personalBest: personalBest, metric: \.topSetWeight)

            Text("Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(32)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(.white)
    }
}
