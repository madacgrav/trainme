import SwiftUI

struct SessionRunView: View {
    @State var viewModel: SessionRunViewModel
    /// Only needed by the edit sheet's "new session" mode; presenters without a
    /// workout repository (client detail) pass nothing.
    var workoutRepo: (any WorkoutRepository)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showingTextReminder = false
    @State private var pendingStatus: SessionStatus?
    @State private var showingEdit = false
    @State private var confirmingDelete = false
    @State private var calendarWarning: String?

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            if let injuries = viewModel.clientInjuries, !injuries.isEmpty {
                Section {
                    Label(injuries, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                } header: {
                    Text("Injuries / limitations")
                }
            }

            Section {
                LabeledContent("Time", value: viewModel.session.startAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Status", value: statusLabel)
            }

            Section("Notes") {
                TextField("Session notes", text: $viewModel.notesDraft, axis: .vertical)
                    .lineLimit(2...6)
                    .onSubmit { Task { await viewModel.saveNotes() } }
                if viewModel.notesDraft != (viewModel.session.notes ?? "") {
                    Button("Save notes") { Task { await viewModel.saveNotes() } }
                }
            }

            ForEach(viewModel.session.instances) { instance in
                Section(instance.name) {
                    ForEach(instance.plannedEntries) { entry in
                        PlannedEntryRow(
                            entry: entry,
                            exercise: viewModel.exercises[entry.exerciseId],
                            sets: viewModel.sets(instanceId: instance.id, exerciseId: entry.exerciseId),
                            viewModel: viewModel,
                            instanceId: instance.id
                        )
                    }
                }
            }

            if viewModel.session.status == .scheduled {
                Section {
                    Button("Mark Completed", systemImage: "checkmark.circle") {
                        Task { await viewModel.setStatus(.completed) }
                    }
                    Button("Cancelled", systemImage: "xmark.circle", role: .destructive) {
                        pendingStatus = .cancelled
                    }
                    Button("No-show", systemImage: "person.fill.xmark", role: .destructive) {
                        pendingStatus = .noShow
                    }
                }
            }

            if !viewModel.canEdit {
                Section {
                    Text("Part of a repeating series — editing individual occurrences isn't available yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(viewModel.clientName)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let phone = viewModel.clientPhone, !phone.isEmpty, MessagingService.canSendText {
                    Button("Text reminder", systemImage: "message") {
                        showingTextReminder = true
                    }
                }
                Menu {
                    if viewModel.canEdit {
                        Button("Edit session", systemImage: "pencil") { showingEdit = true }
                    }
                    Button("Delete session", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            SessionEditView(
                sessionRepo: viewModel.sessionRepo,
                clientRepo: viewModel.clientRepo,
                workoutRepo: workoutRepo,
                existing: viewModel.session,
                initialDate: viewModel.session.startAt
            ) { warning in
                calendarWarning = warning
                Task { await viewModel.reloadAfterEdit() }
            }
        }
        .alert(
            "Calendar",
            isPresented: Binding(get: { calendarWarning != nil }, set: { if !$0 { calendarWarning = nil } })
        ) {
            Button("OK") { calendarWarning = nil }
        } message: {
            Text(calendarWarning ?? "")
        }
        .alert("Delete this session?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.canEdit
                 ? "Logged sets for this session are deleted too. This cannot be undone."
                 : "Only this occurrence is deleted; the rest of the series stays.")
        }
        .sheet(isPresented: $showingTextReminder) {
            if let phone = viewModel.clientPhone {
                MessageComposeView(
                    recipient: phone,
                    body: MessagingService.reminderBody(
                        clientName: viewModel.clientName,
                        sessionDate: viewModel.session.startAt
                    )
                )
                .ignoresSafeArea()
            }
        }
        .alert(
            pendingStatus == .noShow ? "Mark as no-show?" : "Cancel this session?",
            isPresented: Binding(get: { pendingStatus != nil }, set: { if !$0 { pendingStatus = nil } })
        ) {
            Button(pendingStatus == .noShow ? "Mark no-show" : "Cancel session", role: .destructive) {
                if let status = pendingStatus { Task { await viewModel.setStatus(status) } }
                pendingStatus = nil
            }
            Button("Keep", role: .cancel) { pendingStatus = nil }
        } message: {
            Text("This can't be changed back from the app.")
        }
        .task { await viewModel.load() }
    }

    private var statusLabel: String {
        switch viewModel.session.status {
        case .scheduled: "Scheduled"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        case .noShow: "No-show"
        }
    }
}

private struct PlannedEntryRow: View {
    let entry: PlannedEntryDTO
    let exercise: ExerciseDTO?
    let sets: [SetRecordDTO]
    let viewModel: SessionRunViewModel
    let instanceId: UUID

    @State private var showingEntry = false
    @State private var pendingDeleteSet: SetRecordDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise?.name ?? "Exercise")
                    if let target = targetText {
                        Text("Target: \(target)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Log set", systemImage: "plus.circle.fill") { showingEntry = true }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            }
            ForEach(sets) { set in
                HStack {
                    Text("Set \(set.setIndex + 1): \(setSummary(set))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Delete set", systemImage: "minus.circle", role: .destructive) {
                        pendingDeleteSet = set
                    }
                    .labelStyle(.iconOnly)
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingEntry) {
            SetEntryView(
                exercise: exercise,
                plannedEntry: entry,
                instanceId: instanceId,
                viewModel: viewModel
            )
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Delete this set?",
            isPresented: Binding(get: { pendingDeleteSet != nil }, set: { if !$0 { pendingDeleteSet = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete set", role: .destructive) {
                if let set = pendingDeleteSet { Task { await viewModel.deleteSet(set) } }
                pendingDeleteSet = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteSet = nil }
        }
    }

    private var targetText: String? {
        var parts: [String] = []
        if let sets = entry.targetSets, let reps = entry.targetReps { parts.append("\(sets)×\(reps)") }
        if let weight = entry.targetWeight {
            parts.append("@ \(WeightFormatter.string(weight, unit: exercise?.defaultUnit ?? .lb))")
        }
        if let duration = entry.targetDuration { parts.append("\(duration)s") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func setSummary(_ set: SetRecordDTO) -> String {
        var parts: [String] = []
        if let weight = set.weight { parts.append(WeightFormatter.string(weight, unit: exercise?.defaultUnit ?? .lb)) }
        if let reps = set.reps { parts.append("×\(reps)") }
        if let duration = set.duration { parts.append("\(duration)s") }
        if let distance = set.distance { parts.append("\(distance.formatted()) \(exercise?.defaultUnit.rawValue ?? "")") }
        return parts.joined(separator: " ")
    }
}

struct SetEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: ExerciseDTO?
    let plannedEntry: PlannedEntryDTO
    let instanceId: UUID
    let viewModel: SessionRunViewModel

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var duration: Int = 0
    @State private var distance: Double = 0

    private var metrics: MetricSet { exercise?.metrics ?? [.weight, .reps] }
    private var weightUnit: Unit { exercise?.defaultUnit ?? .lb }
    private var step: Double { WeightFormatter.stepIncrement(for: weightUnit) }

    var body: some View {
        NavigationStack {
            Form {
                if metrics.contains(.weight) {
                    HStack {
                        Text("Weight (\(WeightFormatter.label(weightUnit)))")
                        Spacer()
                        Button("−\(step.formatted())") { weight = max(0, weight - step) }.buttonStyle(.bordered)
                        Text(weight.formatted()).frame(minWidth: 56)
                        Button("+\(step.formatted())") { weight += step }.buttonStyle(.bordered)
                    }
                }
                if metrics.contains(.reps) {
                    HStack {
                        Text("Reps")
                        Spacer()
                        Button("−1") { reps = max(0, reps - 1) }.buttonStyle(.bordered)
                        Text("\(reps)").frame(minWidth: 44)
                        Button("+1") { reps += 1 }.buttonStyle(.bordered)
                    }
                }
                if metrics.contains(.duration) {
                    HStack {
                        Text("Duration (sec)")
                        Spacer()
                        Button("−15") { duration = max(0, duration - 15) }.buttonStyle(.bordered)
                        Text("\(duration)").frame(minWidth: 52)
                        Button("+15") { duration += 15 }.buttonStyle(.bordered)
                    }
                }
                if metrics.contains(.distance) {
                    HStack {
                        Text("Distance (\(exercise?.defaultUnit.rawValue ?? "mi"))")
                        Spacer()
                        TextField("0", value: $distance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Button("Repeat last set", systemImage: "arrow.counterclockwise") {
                    Task {
                        if let last = await viewModel.lastSet(exerciseId: plannedEntry.exerciseId) {
                            weight = last.weight ?? weight
                            reps = last.reps ?? reps
                            duration = last.duration ?? duration
                            distance = last.distance ?? distance
                        }
                    }
                }
            }
            .navigationTitle(exercise?.name ?? "Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        Task {
                            await viewModel.record(
                                instanceId: instanceId,
                                exerciseId: plannedEntry.exerciseId,
                                weight: metrics.contains(.weight) ? weight : nil,
                                reps: metrics.contains(.reps) ? reps : nil,
                                duration: metrics.contains(.duration) ? duration : nil,
                                distance: metrics.contains(.distance) ? (distance > 0 ? distance : nil) : nil
                            )
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                weight = plannedEntry.targetWeight ?? 0
                reps = plannedEntry.targetReps ?? 0
                duration = plannedEntry.targetDuration ?? 0
            }
        }
    }
}
