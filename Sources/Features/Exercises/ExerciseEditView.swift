import SwiftUI

/// Creates a custom exercise, or edits an existing one (seeded or custom).
struct ExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    private let repo: any ExerciseRepository
    private let existing: ExerciseDTO?
    private let onSaved: () -> Void

    @State private var name: String
    @State private var category: ExerciseCategory
    @State private var trackWeight: Bool
    @State private var trackReps: Bool
    @State private var trackSets: Bool
    @State private var trackDuration: Bool
    @State private var trackDistance: Bool
    @State private var defaultUnit: Unit
    @State private var errorMessage: String?

    init(repo: any ExerciseRepository, existing: ExerciseDTO? = nil, onSaved: @escaping () -> Void) {
        self.repo = repo
        self.existing = existing
        self.onSaved = onSaved
        let metrics = existing?.metrics ?? [.weight, .reps, .sets]
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? .strength)
        _trackWeight = State(initialValue: metrics.contains(.weight))
        _trackReps = State(initialValue: metrics.contains(.reps))
        _trackSets = State(initialValue: metrics.contains(.sets))
        _trackDuration = State(initialValue: metrics.contains(.duration))
        _trackDistance = State(initialValue: metrics.contains(.distance))
        let globalDefault = Unit(rawValue: UserDefaults.standard.string(forKey: "defaultWeightUnit") ?? "") ?? .lb
        _defaultUnit = State(initialValue: existing?.defaultUnit ?? globalDefault)
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
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(existing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async -> Bool {
        errorMessage = nil
        let dto = ExerciseDTO(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            metrics: metrics,
            defaultUnit: defaultUnit,
            isCustom: existing?.isCustom ?? true,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
        do {
            if existing == nil {
                _ = try await repo.create(dto)
            } else {
                try await repo.update(dto)
            }
            return true
        } catch {
            errorMessage = "Couldn't save the exercise. Please try again."
            return false
        }
    }
}
