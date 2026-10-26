import SwiftUI

/// Standardizes the copy and symbol of a `ContentUnavailableView` overlay.
struct EmptyState: View {
    let title: String
    let systemImage: String
    var description: String? = nil
    var action: (title: String, run: () -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description { Text(description) }
        } actions: {
            if let action {
                Button(action.title, action: action.run).buttonStyle(.borderedProminent)
            }
        }
    }
}
