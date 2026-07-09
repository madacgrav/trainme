import SwiftUI

struct ClientEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ClientEditViewModel
    private let onSaved: () -> Void

    init(repo: any ClientRepository, existing: ClientDTO?, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: ClientEditViewModel(repo: repo, existing: existing))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Mobile phone", text: $viewModel.phoneRaw)
                        .keyboardType(.phonePad)
                    if !viewModel.phoneRaw.isEmpty && !viewModel.phoneValid {
                        Text("Enter a valid phone number")
                            .font(.caption)
                            .foregroundStyle(.red)
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
            }
            .navigationTitle(viewModel.isEditing ? "Edit Client" : "New Client")
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
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}
