import SwiftUI

struct ScheduleView: View {
    @State var viewModel: ScheduleViewModel
    /// Switches the root tab to Settings (used by the export reminder banner).
    var openSettings: () -> Void = {}
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isExportReminderDue {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.exclamationmark")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Back up your data").font(.subheadline.bold())
                            Text("Export is the only backup on this phone.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Export") { openSettings() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Button("Dismiss", systemImage: "xmark") { viewModel.dismissExportReminder() }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.12))
                }

                DatePicker("Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                List(viewModel.sessionsForDay) { session in
                    NavigationLink {
                        SessionRunView(viewModel: SessionRunViewModel(
                            sessionRepo: viewModel.sessionRepo,
                            exerciseRepo: viewModel.exerciseRepo,
                            clientRepo: viewModel.clientRepo,
                            session: session,
                            clientName: viewModel.clientNames[session.clientId] ?? "Client",
                            clientPhone: viewModel.clientPhones[session.clientId],
                            clientInjuries: viewModel.clientInjuries[session.clientId] ?? nil,
                            onStatusChanged: { await viewModel.load() }
                        ), workoutRepo: viewModel.workoutRepo)
                    } label: {
                        SessionRow(session: session, clientName: viewModel.clientNames[session.clientId] ?? "Client")
                    }
                }
                .overlay {
                    if viewModel.sessionsForDay.isEmpty {
                        ContentUnavailableView("No sessions this day", systemImage: "calendar")
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                Button("Add", systemImage: "plus") { showingNew = true }
            }
            .sheet(isPresented: $showingNew) {
                SessionEditView(
                    sessionRepo: viewModel.sessionRepo,
                    clientRepo: viewModel.clientRepo,
                    workoutRepo: viewModel.workoutRepo,
                    initialDate: viewModel.selectedDate
                ) {
                    Task { await viewModel.load() }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.selectedDate) {
                Task { await viewModel.load() }
            }
        }
    }
}

struct SessionRow: View {
    let session: SessionDTO
    let clientName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(clientName)
                Text(session.startAt.formatted(date: .omitted, time: .shortened) + " – "
                     + session.endAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !session.instances.isEmpty {
                    Text(session.instances.map(\.name).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch session.status {
        case .scheduled:
            EmptyView()
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .cancelled:
            Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        case .noShow:
            Image(systemName: "person.fill.xmark").foregroundStyle(.orange)
        }
    }
}
