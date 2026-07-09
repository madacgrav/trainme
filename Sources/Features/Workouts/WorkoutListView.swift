import SwiftUI

struct WorkoutListView: View {
    @State var viewModel: WorkoutListViewModel
    @State private var editingWorkout: WorkoutDTO?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.workouts) { workout in
                    Button {
                        editingWorkout = workout
                    } label: {
                        VStack(alignment: .leading) {
                            Text(workout.name)
                                .foregroundStyle(.primary)
                            Text("\(workout.entries.count) exercise\(workout.entries.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task { await viewModel.delete(id: workout.id) }
                        }
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            Task { await viewModel.duplicate(id: workout.id) }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.workouts.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "list.clipboard")
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                Button("Add", systemImage: "plus") { showingNew = true }
            }
            .sheet(isPresented: $showingNew) {
                WorkoutBuilderView(
                    workoutRepo: viewModel.workoutRepo,
                    exerciseRepo: viewModel.exerciseRepo,
                    existing: nil
                ) {
                    Task { await viewModel.load() }
                }
            }
            .sheet(item: $editingWorkout) { workout in
                WorkoutBuilderView(
                    workoutRepo: viewModel.workoutRepo,
                    exerciseRepo: viewModel.exerciseRepo,
                    existing: workout
                ) {
                    Task { await viewModel.load() }
                }
            }
            .task { await viewModel.load() }
        }
    }
}
