//
//  ContentView.swift
//  Unfolding
//
//  Created by Rongwei Ji on 10/2/25.
//

import SwiftUI
import SwiftData
import PhotosUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Keep UI state minimal; data is loaded via repository
    @State private var records: [PhotoRecord] = []
    #if os(iOS)
    @State private var pickedItem: PhotosPickerItem?
    #else
    @State private var showPicker = false
    #endif
    @State private var isBusy: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                // Label: current record count
                Text("Records: \(records.count)")
                    .font(.headline)

                // Two buttons: Pick Photo and Delete All
                HStack(spacing: 12) {
                    #if os(iOS)
                    PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isBusy)
                    #else
                    Button {
                        showPicker = true
                    } label: {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isBusy)
                    #endif

                    Button(role: .destructive) {
                        Task { await deleteAll() }
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(records.isEmpty || isBusy)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("errorMessage")
                }

                // List of saved records
                List {
                    ForEach(records) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = item.photoFilename, !name.isEmpty {
                                Text("Name: \(name)")
                                    .font(.body)
                            }

                            if let lat = item.latitude, let lon = item.longitude {
                                Text("Location: \(lat), \(lon)")
                                    .font(.body)
                            } else {
                                Text("Location: Not available")
                                    .font(.body)
                            }

                            if let date = item.photoCreationDate {
                                Text("Photo date: \(date, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Saved: \(item.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let id = item.assetIdentifier {
                                Text("Asset ID: \(id)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
#if os(macOS)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            }
            .padding()
            .navigationTitle("Unfolding")
        } detail: {
            Text("Select a record")
        }
        // When a photo is picked, process and save it
        #if os(iOS)
        .onChange(of: pickedItem) { _, newValue in
            Task { await handlePickedItem(newValue) }
        }
        #endif
        .task {
            await reload()
        }
        #if os(macOS)
        .sheet(isPresented: $showPicker) {
            PhotoPickerView { result in
                Task {
                    await handlePickerResult(result)
                }
            }
        }
        #endif
    }

    // MARK: - Actions

    #if os(iOS)
    private func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isBusy = true
        errorMessage = nil

        defer {
            Task { @MainActor in
                pickedItem = nil
                isBusy = false
            }
        }

        do {
            let meta = try await PhotoLibraryService.extractMetadata(from: item)
            try PhotoRecordRepository.saveRecord(context: modelContext, metadata: meta)
            await reload()
        } catch {
            await setError("Failed to save: \(error.localizedDescription)")
        }
    }
    #endif

    #if os(macOS)
    private func handlePickerResult(_ result: PHPickerResult) async {
        isBusy = true
        errorMessage = nil
        defer {
            Task { @MainActor in
                showPicker = false
                isBusy = false
            }
        }

        do {
            let meta = try await PhotoLibraryService.extractMetadata(from: result)
            try PhotoRecordRepository.saveRecord(context: modelContext, metadata: meta)
            await reload()
        } catch {
            await setError("Failed to save: \(error.localizedDescription)")
        }
    }
    #endif

    private func deleteAll() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try PhotoRecordRepository.deleteAll(context: modelContext)
            await reload()
        } catch {
            await setError("Failed to delete all: \(error.localizedDescription)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        errorMessage = nil
        do {
            try PhotoRecordRepository.delete(records: records, at: offsets, context: modelContext)
            Task { await reload() }
        } catch {
            Task { await setError("Failed to delete: \(error.localizedDescription)") }
        }
    }

    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }

    // MARK: - Loading

    private func reload() async {
        do {
            records = try PhotoRecordRepository.fetchAll(context: modelContext)
        } catch {
            await setError("Failed to load: \(error.localizedDescription)")
        }
    }
}

#if os(macOS)
@available(macOS 13.0, *)
struct PhotoPickerView: NSViewControllerRepresentable {
    let onSelection: (PHPickerResult) -> Void

    func makeNSViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateNSViewController(_ nsViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelection: (PHPickerResult) -> Void

        init(onSelection: @escaping (PHPickerResult) -> Void) {
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if let result = results.first {
                onSelection(result)
            }
        }
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: PhotoRecord.self, inMemory: true)
}

