import SwiftUI

struct ExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    private let repo: any ExerciseRepository
    private let onSaved: () -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var trackWeight = true
    @State private var trackReps = true
    @State private var trackSets = true
    @State private var trackDuration = false
    @State private var trackDistance = false
    @State private var defaultUnit: Unit = .lb

    init(repo: any ExerciseRepository, onSaved: @escaping () -> Void) {
        self.repo = repo
        self.onSaved = onSaved
    }

    private var metrics: MetricSet {
        var set = MetricSet()
        if trackWeight { set.insert(.weight) }
        if trackReps { set.insert(.reps) }
        if trackSets { set.insert(.sets) }
        if trackDuration { set.insert(.duration) }
        if trackDistance { set.insert(.distance) }
        return set
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !metrics.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                }
                Section("Tracked metrics") {
                    Toggle("Weight", isOn: $trackWeight)
                    Toggle("Reps", isOn: $trackReps)
                    Toggle("Sets", isOn: $trackSets)
                    Toggle("Duration", isOn: $trackDuration)
                    Toggle("Distance", isOn: $trackDistance)
                }
                Section("Default unit") {
                    Picker("Unit", selection: $defaultUnit) {
                        ForEach(Unit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let dto = ExerciseDTO(
                                id: UUID(),
                                name: name.trimmingCharacters(in: .whitespaces),
                                category: category,
                                metrics: metrics,
                                defaultUnit: defaultUnit,
                                isCustom: true,
                                createdAt: .now,
                                updatedAt: .now
                            )
                            _ = try? await repo.create(dto)
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
