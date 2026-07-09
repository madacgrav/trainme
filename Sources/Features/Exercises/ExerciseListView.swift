import SwiftUI

struct ExerciseListView: View {
    @State var viewModel: ExerciseListViewModel
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List(viewModel.filtered) { exercise in
                HStack {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                        Text(exercise.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if exercise.isCustom {
                        Text("Custom")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
            .overlay {
                if viewModel.filtered.isEmpty {
                    ContentUnavailableView("No exercises", systemImage: "dumbbell")
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Category", selection: $viewModel.categoryFilter) {
                        Text("All").tag(ExerciseCategory?.none)
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(ExerciseCategory?.some(category))
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ExerciseEditView(repo: viewModel.repository) {
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
