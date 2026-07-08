import SwiftUI

struct ClientListView: View {
    @State var viewModel: ClientListViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.clients) { client in
                Text(client.name)
            }
            .overlay {
                if viewModel.clients.isEmpty {
                    ContentUnavailableView("No clients yet", systemImage: "person.2")
                }
            }
            .navigationTitle("Clients")
            .toolbar {
                Button("Add", systemImage: "plus") {
                    Task { await viewModel.add(name: "New Client \(viewModel.clients.count + 1)") }
                }
            }
            .task { await viewModel.load() }
        }
    }
}
