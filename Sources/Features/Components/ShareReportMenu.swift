import SwiftUI

/// Toolbar menu offering the rendered report as PDF or PNG; hidden until rendered.
struct ShareReportMenu: View {
    let files: ReportFiles?

    var body: some View {
        if let files {
            Menu {
                ShareLink("Share PDF", item: files.pdf)
                ShareLink("Share PNG", item: files.png)
            } label: {
                Label("Share report", systemImage: "square.and.arrow.up")
            }
        }
    }
}
