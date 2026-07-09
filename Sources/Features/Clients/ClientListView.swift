import SwiftUI

struct ClientListView: View {
    @State var viewModel: ClientListViewModel
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List(viewModel.clients) { client in
                NavigationLink {
                    ClientDetailView(viewModel: ClientDetailViewModel(repo: viewModel.repository, client: client))
                } label: {
                    VStack(alignment: .leading) {
                        Text(client.name)
                        if let goal = client.goal, !goal.isEmpty {
                            Text(goal)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.clients.isEmpty {
                    ContentUnavailableView(
                        viewModel.query.isEmpty ? "No clients yet" : "No matches",
                        systemImage: "person.2"
                    )
                }
            }
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
