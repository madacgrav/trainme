import SwiftUI

struct SessionEditView: View {
    @Environment(\.dismiss) private var dismiss
    private let sessionRepo: any SessionRepository
    private let onSaved: () -> Void

    @State private var clients: [ClientDTO] = []
    @State private var workouts: [WorkoutDTO] = []
    @State private var selectedClientId: UUID?
    @State private var startAt: Date
    @State private var durationMinutes = 60
    @State private var selectedWorkoutIds: Set<UUID> = []
    @State private var notes = ""

    @State private var repeats = false
    @State private var repeatWeekdays: Set<Int> = []
    @State private var repeatWeeks = 8
    @State private var addToCalendar = false

    private let clientRepo: any ClientRepository
    private let workoutRepo: any WorkoutRepository
    private let calendar: any CalendarSyncing

    init(
        sessionRepo: any SessionRepository,
        clientRepo: any ClientRepository,
        workoutRepo: any WorkoutRepository,
        calendar: any CalendarSyncing = EventKitCalendarService(),
        initialDate: Date,
        onSaved: @escaping () -> Void
    ) {
        self.sessionRepo = sessionRepo
        self.clientRepo = clientRepo
        self.workoutRepo = workoutRepo
        self.calendar = calendar
        self.onSaved = onSaved
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: initialDate)
        _startAt = State(initialValue: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? initialDate)
    }

    private var canSave: Bool { selectedClientId != nil }

    private static let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    Picker("Client", selection: $selectedClientId) {
                        Text("Select…").tag(UUID?.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(UUID?.some(client.id))
                        }
                    }
                }
                Section("When") {
                    DatePicker("Starts", selection: $startAt)
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 15...240, step: 15)
                }
                Section("Workouts") {
                    if workouts.isEmpty {
                        Text("No workout templates yet").foregroundStyle(.secondary)
                    }
                    ForEach(workouts) { workout in
                        Button {
                            if selectedWorkoutIds.contains(workout.id) {
                                selectedWorkoutIds.remove(workout.id)
                            } else {
                                selectedWorkoutIds.insert(workout.id)
                            }
                        } label: {
                            HStack {
                                Text(workout.name).foregroundStyle(.primary)
                                Spacer()
                                if selectedWorkoutIds.contains(workout.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Section("Repeat") {
                    Toggle("Repeats weekly", isOn: $repeats)
                    if repeats {
                        HStack {
                            ForEach(1...7, id: \.self) { weekday in
                                let symbol = Self.weekdaySymbols[weekday - 1]
                                Button(symbol) {
                                    if repeatWeekdays.contains(weekday) {
                                        repeatWeekdays.remove(weekday)
                                    } else {
                                        repeatWeekdays.insert(weekday)
                                    }
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                                .tint(repeatWeekdays.contains(weekday) ? .accentColor : .gray)
                            }
                        }
                        Stepper("For \(repeatWeeks) weeks", value: $repeatWeeks, in: 1...26)
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                Section {
                    Toggle("Add to iPhone calendar", isOn: $addToCalendar)
                } footer: {
                    Text("Pushes the session to your default calendar (syncs to Google Calendar if that's your default account).")
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .task {
                clients = (try? await clientRepo.all()) ?? []
                workouts = (try? await workoutRepo.all()) ?? []
            }
        }
    }

    private func save() async {
        guard let clientId = selectedClientId else { return }
        let dto = SessionDTO(
            id: UUID(),
            clientId: clientId,
            startAt: startAt,
            endAt: startAt.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            status: .scheduled,
            notes: notes.isEmpty ? nil : notes,
            instances: [],
            seriesId: nil,
            recurrence: nil,
            eventIdentifier: nil,
            createdAt: .now,
            updatedAt: .now
        )
        let workoutIds = Array(selectedWorkoutIds)
        let clientName = clients.first { $0.id == clientId }?.name ?? "Client"
        if repeats {
            let rule = AppRecurrence(
                frequency: .weekly,
                interval: 1,
                weekdays: repeatWeekdays.sorted(),
                endDate: nil,
                occurrenceCount: nil
            )
            let seriesId = try? await sessionRepo.scheduleSeries(dto, recurrence: rule, attaching: workoutIds, horizonWeeks: repeatWeeks)
            if addToCalendar, let seriesId, await calendar.requestAccess() {
                var boundedRule = rule
                boundedRule.occurrenceCount = repeatWeeks * max(1, rule.weekdays.count)
                if let eventId = try? await calendar.push(dto, clientName: clientName, recurrence: boundedRule) {
                    try? await sessionRepo.setEventIdentifierForSeries(seriesId, eventId)
                }
            }
        } else {
            try? await sessionRepo.schedule(dto, attaching: workoutIds)
            if addToCalendar, await calendar.requestAccess(),
               let eventId = try? await calendar.push(dto, clientName: clientName, recurrence: nil) {
                try? await sessionRepo.setEventIdentifier(id: dto.id, eventId)
            }
        }
    }
}
