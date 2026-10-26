import SwiftUI

struct ClientEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ClientEditViewModel
    private let onSaved: () -> Void

    init(repo: any ClientRepository, existing: ClientDTO?, isSelf: Bool = false, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: ClientEditViewModel(repo: repo, existing: existing, isSelf: isSelf))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(viewModel.isSelf ? "Your profile" : "Contact") {
                    TextField("Name", text: $viewModel.name)
                    if !viewModel.isSelf {
                        TextField("Mobile phone", text: $viewModel.phoneRaw)
                            .keyboardType(.phonePad)
                        if !viewModel.phoneRaw.isEmpty && !viewModel.phoneValid {
                            Text("Enter a valid phone number")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.danger)
                        }
                    }
                }
                Section("Training") {
                    TextField("Primary goal", text: $viewModel.goal)
                    TextField("Injuries / limitations", text: $viewModel.injuries, axis: .vertical)
                }
                Section("Notes") {
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                ErrorBanner(message: viewModel.errorMessage)
            }
            .navigationTitle(viewModel.isSelf ? "About You" : (viewModel.isEditing ? "Edit Client" : "New Client"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}

#Preview("Edit client") {
    let repos = PreviewFixtures.repositories()
    ClientEditView(repo: repos.clients, existing: PreviewFixtures.client) {}
}

#Preview("About you") {
    let repos = PreviewFixtures.repositories()
    ClientEditView(repo: repos.clients, existing: nil, isSelf: true) {}
}
