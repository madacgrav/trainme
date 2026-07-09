import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let archive: any DataArchiving

    @AppStorage("lastExportAt") private var lastExportAt: Double = 0
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
                    Button("Export all data…", systemImage: "square.and.arrow.up") {
                        Task {
                            exportURL = try? await archive.export()
                            showingExporter = exportURL != nil
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
                if case .success = result {
                    lastExportAt = Date.now.timeIntervalSince1970
                    statusMessage = "Export saved."
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    pendingImportURL = url
                    showingModeDialog = true
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
        do {
            try await archive.importArchive(url: url, mode: mode)
            statusMessage = "Import complete."
        } catch ArchiveError.newerThanApp {
            statusMessage = "This file was exported by a newer version of TrainMe. Update the app first."
        } catch {
            statusMessage = "Import failed: the file couldn't be read."
        }
        pendingImportURL = nil
    }
}
