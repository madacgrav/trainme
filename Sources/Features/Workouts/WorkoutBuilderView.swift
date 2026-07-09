import SwiftUI

struct WorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WorkoutBuilderViewModel
    @State private var showingPicker = false
    @State private var editingEntryIndex: Int?
    private let onSaved: () -> Void

    init(
        workoutRepo: any WorkoutRepository,
        exerciseRepo: any ExerciseRepository,
        existing: WorkoutDTO?,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: WorkoutBuilderViewModel(
            workoutRepo: workoutRepo, exerciseRepo: exerciseRepo, existing: existing
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout name", text: $viewModel.name)
                }
                Section("Exercises") {
                    ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            editingEntryIndex = index
                        } label: {
                            VStack(alignment: .leading) {
                                Text(viewModel.exerciseNames[entry.exerciseId] ?? "Exercise")
                                    .foregroundStyle(.primary)
                                Text(targetSummary(entry))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove { viewModel.move(from: $0, to: $1) }
                    .onDelete { viewModel.remove(at: $0) }

                    Button("Add exercise", systemImage: "plus") { showingPicker = true }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Workout" : "New Workout")
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
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(repo: viewModel.exerciseRepo) { exercise in
                    viewModel.addExercise(exercise)
                }
            }
            .sheet(item: Binding(
                get: { editingEntryIndex.map { EntryIndex(value: $0) } },
                set: { editingEntryIndex = $0?.value }
            )) { wrapper in
                EntryTargetEditView(entry: $viewModel.entries[wrapper.value])
                    .presentationDetents([.medium])
            }
            .task { await viewModel.loadExerciseNames() }
        }
    }

    private func targetSummary(_ entry: WorkoutEntryDTO) -> String {
        var parts: [String] = []
        if let sets = entry.targetSets, let reps = entry.targetReps {
            parts.append("\(sets)×\(reps)")
        } else if let sets = entry.targetSets {
            parts.append("\(sets) sets")
        } else if let reps = entry.targetReps {
            parts.append("\(reps) reps")
        }
        if let weight = entry.targetWeight {
            parts.append("@ \(weight.formatted()) lb")
        }
        if let duration = entry.targetDuration {
            parts.append("\(duration)s")
        }
        return parts.isEmpty ? "No targets" : parts.joined(separator: " ")
    }
}

private struct EntryIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let repo: any ExerciseRepository
    let onPick: (ExerciseDTO) -> Void

    @State private var query = ""
    @State private var results: [ExerciseDTO] = []

    var body: some View {
        NavigationStack {
            List(results) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name).foregroundStyle(.primary)
                        Text(exercise.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { results = (try? await repo.search(prefix: "")) ?? [] }
            .onChange(of: query) {
                Task { results = (try? await repo.search(prefix: query)) ?? [] }
            }
        }
    }
}

struct EntryTargetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var entry: WorkoutEntryDTO

    var body: some View {
        NavigationStack {
            Form {
                Section("Targets") {
                    OptionalStepper(label: "Sets", value: $entry.targetSets, range: 1...20, defaultValue: 3)
                    OptionalStepper(label: "Reps", value: $entry.targetReps, range: 1...100, defaultValue: 10)
                    HStack {
                        Text("Weight (lb)")
                        Spacer()
                        TextField("—", value: $entry.targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    OptionalStepper(label: "Duration (sec)", value: $entry.targetDuration, range: 5...7200, defaultValue: 60, step: 5)
                }
            }
            .navigationTitle("Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct OptionalStepper: View {
    let label: String
    @Binding var value: Int?
    let range: ClosedRange<Int>
    let defaultValue: Int
    var step: Int = 1

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if let current = value {
                Stepper("\(current)", value: Binding(
                    get: { current },
                    set: { value = $0 }
                ), in: range, step: step)
                .fixedSize()
                Button("Clear", systemImage: "xmark.circle.fill") { value = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            } else {
                Button("Set") { value = defaultValue }
            }
        }
    }
}
