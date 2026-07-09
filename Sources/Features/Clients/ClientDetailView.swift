import SwiftUI

struct ClientDetailView: View {
    @State var viewModel: ClientDetailViewModel
    @State private var showingEdit = false

    var body: some View {
        List {
            Section("Contact") {
                LabeledContent("Phone", value: viewModel.client.phoneE164)
                if let goal = viewModel.client.goal {
                    LabeledContent("Goal", value: goal)
                }
                if let injuries = viewModel.client.injuries {
                    LabeledContent("Injuries", value: injuries)
                }
                if let notes = viewModel.client.notes {
                    LabeledContent("Notes", value: notes)
                }
            }
            Section("Upcoming Sessions") {
                Text("Scheduling arrives in a later phase")
                    .foregroundStyle(.secondary)
            }
            Section("Recent Sessions") {
                Text("Session history arrives in a later phase")
                    .foregroundStyle(.secondary)
            }
            Section("Progress Reports") {
                Text("Reports arrive in a later phase")
                    .foregroundStyle(.secondary)
            }
            if viewModel.client.isArchived {
                Section {
                    Label("This client is archived", systemImage: "archivebox")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(viewModel.client.name)
        .toolbar {
            Menu {
                Button("Edit") { showingEdit = true }
                Button(
                    viewModel.client.isArchived ? "Unarchive" : "Archive",
                    systemImage: "archivebox"
                ) {
                    Task { await viewModel.toggleArchived() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .sheet(isPresented: $showingEdit) {
            ClientEditView(repo: viewModel.repository, existing: viewModel.client) {
                Task { await viewModel.reload() }
            }
        }
    }
}
