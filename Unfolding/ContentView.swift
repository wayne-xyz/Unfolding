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

    @State private var recordCount: Int = 0
    @State private var isBusy: Bool = false
    @State private var progressMessage: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Unfolding")
                .font(.largeTitle)
                .bold()

            // Record count display
            VStack(spacing: 8) {
                Text("Total Records")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(recordCount)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )

            // Progress message (shown during import)
            if !progressMessage.isEmpty {
                Text(progressMessage)
                    .font(.body)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    Task { await importAllPhotos() }
                } label: {
                    Label("Import All Photos", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isBusy)

                Button {
                    printRandomRecords()
                } label: {
                    Label("Print Random 10 Records", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(recordCount == 0 || isBusy)

                Button(role: .destructive) {
                    Task { await deleteAllRecords() }
                } label: {
                    Label("Delete All Records", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(recordCount == 0 || isBusy)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadRecordCount()
        }
    }

    // MARK: - Actions

    private func importAllPhotos() async {
        isBusy = true
        errorMessage = nil
        progressMessage = "Requesting photo library access..."

        // Request authorization
        let status = await PhotoLibraryService.requestAuthorization()
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                errorMessage = "Photo library access denied. Please enable in Settings."
                progressMessage = ""
                isBusy = false
            }
            return
        }

        await MainActor.run {
            progressMessage = "Scanning photo library..."
        }

        // Fetch all photos with location
        let photosWithLocation = await PhotoLibraryService.fetchAllPhotosWithLocation()

        await MainActor.run {
            progressMessage = "Found \(photosWithLocation.count) photos with geolocation. Importing..."
        }

        // Save to database
        do {
            let metadataList = photosWithLocation.map { $0.metadata }
            let savedCount = try PhotoRecordRepository.saveBulk(context: modelContext, metadataList: metadataList)

            await MainActor.run {
                progressMessage = "Successfully imported \(savedCount) photos!"
            }

            // Wait a moment to show success message
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await loadRecordCount()
            await MainActor.run {
                progressMessage = ""
                isBusy = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save photos: \(error.localizedDescription)"
                progressMessage = ""
                isBusy = false
            }
        }
    }

    private func deleteAllRecords() async {
        isBusy = true
        errorMessage = nil
        progressMessage = "Deleting all records..."

        do {
            try PhotoRecordRepository.deleteAll(context: modelContext)

            await MainActor.run {
                progressMessage = "All records deleted successfully!"
            }

            // Wait a moment to show success message
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await loadRecordCount()
            await MainActor.run {
                progressMessage = ""
                isBusy = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete records: \(error.localizedDescription)"
                progressMessage = ""
                isBusy = false
            }
        }
    }

    private func loadRecordCount() async {
        do {
            let count = try PhotoRecordRepository.count(context: modelContext)
            await MainActor.run {
                recordCount = count
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load count: \(error.localizedDescription)"
            }
        }
    }

    private func printRandomRecords() {
        errorMessage = nil
        do {
            let randomRecords = try PhotoRecordRepository.fetchRandom(count: 10, context: modelContext)
            print("====== Random 10 Records ======")
            print("Total records selected: \(randomRecords.count)")
            print("")

            for (index, record) in randomRecords.enumerated() {
                print("[\(index + 1)] Record:")
                print("  - Filename: \(record.photoFilename ?? "N/A")")
                print("  - Location: (\(record.latitude ?? 0.0), \(record.longitude ?? 0.0))")
                print("  - Creation Date: \(record.photoCreationDate?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")")
                print("  - Saved At: \(record.timestamp.formatted(date: .abbreviated, time: .shortened))")
                print("  - Asset ID: \(record.assetIdentifier ?? "N/A")")
                print("")
            }
            print("===============================")
        } catch {
            errorMessage = "Failed to fetch random records: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PhotoRecord.self, inMemory: true)
}
