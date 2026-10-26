import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let archive: any DataArchiving

    @AppStorage("lastExportAt") private var lastExportAt: Double = 0
    @AppStorage("defaultWeightUnit") private var defaultWeightUnit: String = Unit.lb.rawValue
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var showingModeDialog = false
    @State private var showingReplaceConfirm = false
    @State private var statusMessage: String?

    private var lastExportText: String {
        lastExportAt == 0
            ? "Never"
            : Date(timeIntervalSince1970: lastExportAt).formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weight unit for new exercises", selection: $defaultWeightUnit) {
                        Text("lb").tag(Unit.lb.rawValue)
                        Text("kg").tag(Unit.kg.rawValue)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Units")
                } footer: {
                    Text("Each exercise keeps its own unit; change it from the Exercises tab. Existing weights are never converted.")
                }

                Section {
                    Button("Export all data…", systemImage: "square.and.arrow.up") {
                        Task {
                            do {
                                exportURL = try await archive.export()
                                showingExporter = true
                            } catch {
                                Log.archive.error("Export failed: \(error.localizedDescription)")
                                statusMessage = "Export failed. Please try again."
                            }
                        }
                    }
                    Button("Import from file…", systemImage: "square.and.arrow.down") {
                        showingImporter = true
                    }
                    LabeledContent("Last export", value: lastExportText)
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Your data lives only on this iPhone. Exporting to a file is the ONLY backup — a lost or broken phone otherwise means losing everything. Export regularly and keep the file somewhere safe (iCloud Drive, email it to yourself).")
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $showingExporter,
                item: exportURL,
                contentTypes: [.json],
                defaultFilename: exportURL?.lastPathComponent
            ) { result in
                switch result {
                case .success:
                    lastExportAt = Date.now.timeIntervalSince1970
                    statusMessage = "Export saved."
                case .failure(let error):
                    Log.archive.error("Export sheet failed: \(error.localizedDescription)")
                    statusMessage = "Export wasn't saved."
                }
                // The export file holds client PII: never leave it in tmp.
                exportURL = nil
                DataArchiveActor.removeExports()
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    showingModeDialog = true
                case .failure(let error):
                    Log.archive.error("Import picker failed: \(error.localizedDescription)")
                    statusMessage = "Couldn't open that file."
                }
            }
            .confirmationDialog("How should the import be applied?", isPresented: $showingModeDialog, titleVisibility: .visible) {
                Button("Merge with existing data") {
                    Task { await runImport(mode: .merge) }
                }
                Button("Replace ALL data", role: .destructive) {
                    showingReplaceConfirm = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Replace everything?", isPresented: $showingReplaceConfirm) {
                Button("Replace", role: .destructive) {
                    Task { await runImport(mode: .replace) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All current clients, workouts, sessions and history will be deleted and replaced by the file's contents. This cannot be undone.")
            }
        }
    }

    private func runImport(mode: ImportMode) async {
        guard let url = pendingImportURL else { return }
        defer { pendingImportURL = nil }
        do {
            switch mode {
            case .merge:
                try await archive.importArchive(url: url, mode: .merge)
            case .replace:
                try await SafeImporter(archive: archive).importReplacing(url: url)
            }
            statusMessage = "Import complete."
        } catch ArchiveError.newerThanApp {
            statusMessage = "This file was exported by a newer version of TrainMe. Update the app first."
        } catch ArchiveError.unreadable {
            statusMessage = "Import failed: the file couldn't be read."
        } catch ArchiveError.decodeFailed {
            statusMessage = "Import failed: the file isn't a valid TrainMe export."
        } catch let outcome as ImportOutcome {
            switch outcome {
            case .failedAndRestored:
                statusMessage = "Import failed. Your previous data was restored."
            case .failedAndRestoreFailed:
                statusMessage = "Import failed and your data may be incomplete. Re-import your last export now."
            }
        } catch {
            Log.archive.error("Import failed: \(error.localizedDescription)")
            statusMessage = "Import failed. Please try again."
        }
    }
}
