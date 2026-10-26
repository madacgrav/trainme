import SwiftUI
import UIKit

/// Renders a client progress report to a shareable PDF.
enum ReportExporter {
    @MainActor
    static func renderPDF(
        clientName: String,
        exerciseName: String,
        points: [ProgressPoint],
        personalBest: SetRecordDTO?,
        unit: Unit
    ) throws -> URL {
        let content = ReportPage(
            clientName: clientName,
            exerciseName: exerciseName,
            points: points,
            personalBest: personalBest,
            unit: unit
        )
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = .init(width: 612, height: 792) // US Letter @72dpi

        // Reports hold client PII: keep them in their own tmp folder so the view
        // can sweep them on disappear, and protect the file like the data store.
        let fm = FileManager.default
        removeReports()
        try fm.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        let url = reportsDirectory
            .appending(path: "\(sanitized(clientName)) — \(sanitized(exerciseName)) Progress.pdf")

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
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        return url
    }

    static let reportsDirectory = FileManager.default.temporaryDirectory
        .appending(path: "Reports", directoryHint: .isDirectory)

    /// Deletes every rendered report. Call when the report screen goes away.
    static func removeReports() {
        try? FileManager.default.removeItem(at: reportsDirectory)
    }

    /// Names come from user input; path separators and colons would otherwise
    /// make CGContext fail to create the file.
    private static func sanitized(_ name: String) -> String {
        let cleaned = name.map { "/:".contains($0) ? "-" : $0 }
        return String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The printable report page (also reused by the in-app share preview).
struct ReportPage: View {
    let clientName: String
    let exerciseName: String
    let points: [ProgressPoint]
    let personalBest: SetRecordDTO?
    let unit: Unit

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
                Text("Personal best: \(WeightFormatter.string(weight, unit: unit)) on \(pb.performedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
            }

            ExerciseProgressChart(
                points: points,
                personalBest: personalBest,
                metric: \.topSetWeight,
                unitLabel: WeightFormatter.label(unit)
            )

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
