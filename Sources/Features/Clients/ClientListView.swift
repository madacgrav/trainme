import SwiftUI

struct ClientListView: View {
    @State var viewModel: ClientListViewModel
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List(viewModel.clients) { client in
                NavigationLink {
                    ClientDetailView(viewModel: ClientDetailViewModel(
                        repo: viewModel.repository,
                        exerciseRepo: viewModel.exerciseRepo,
                        sessionRepo: viewModel.sessionRepo,
                        reporting: viewModel.reporting,
                        reminders: viewModel.reminders,
                        client: client
                    ))
                } label: {
                    TitleCaptionRow(title: client.name, caption: client.goal)
                }
                .themedRows()
            }
            .overlay {
                if viewModel.isLoading && viewModel.clients.isEmpty {
                    ProgressView()
                } else if viewModel.clients.isEmpty {
                    EmptyState(
                        title: viewModel.query.isEmpty ? "No clients yet" : "No matches",
                        systemImage: "person.2.fill"
                    )
                }
            }
            .themedScreen()
            .searchable(text: $viewModel.query, prompt: "Search clients")
            .navigationTitle("Clients")
            .toolbar {
                Button("Add", systemImage: "plus") { showingAdd = true }
            }
            .sheet(isPresented: $showingAdd) {
                ClientEditView(repo: viewModel.repository, existing: nil) {
                    Task { await viewModel.load() }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.query) {
                Task { await viewModel.load() }
            }
        }
    }
}

#Preview("Clients") {
    let repos = PreviewFixtures.repositories()
    ClientListView(viewModel: ClientListViewModel(
        repo: repos.clients,
        exerciseRepo: repos.exercises,
        sessionRepo: repos.sessions,
        reporting: repos.reporting,
        reminders: repos.reminders
    ))
}
