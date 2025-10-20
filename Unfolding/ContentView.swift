//
//  ContentView.swift
//  Unfolding
//
//  Created by Rongwei Ji on 10/2/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import CloudKit
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var recordCount: Int = 0
    @State private var cloudKitPrivateCount: Int? = nil
    @State private var cloudKitPublicCount: Int? = nil
    @State private var isBusy: Bool = false
    @State private var isCheckingCloudKit: Bool = false
    @State private var progressMessage: String = ""
    @State private var errorMessage: String?
    @State private var username: String = ""
    @State private var unpublishedCount: Int = 0

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

                // CloudKit counts (if available)
                VStack(spacing: 4) {
                    if let cloudKitPrivateCount {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.icloud.fill")
                                .foregroundStyle(.blue)
                            Text("Private: \(cloudKitPrivateCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let cloudKitPublicCount {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .foregroundStyle(.green)
                            Text("Public: \(cloudKitPublicCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if unpublishedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.orange)
                            Text("Unpublished: \(unpublishedCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
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

            // Username TextField
            VStack(spacing: 8) {
                Text("Username for Publishing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Enter username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)

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
                    Task { await publishToPublicDatabase() }
                } label: {
                    Label("Publish to Public Database", systemImage: "square.and.arrow.up.on.square")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(unpublishedCount == 0 || username.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)

                Button {
                    printRandomRecords()
                } label: {
                    Label("Print Random 10 Records", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(recordCount == 0 || isBusy)

                HStack(spacing: 12) {
                    Button {
                        Task { await checkPrivateCloudKit() }
                    } label: {
                        HStack {
                            if isCheckingCloudKit {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Label(isCheckingCloudKit ? "Checking..." : "Private DB", systemImage: "lock.icloud")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isBusy || isCheckingCloudKit)

                    Button {
                        Task { await checkPublicCloudKit() }
                    } label: {
                        HStack {
                            if isCheckingCloudKit {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Label(isCheckingCloudKit ? "Checking..." : "Public DB", systemImage: "globe")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isBusy || isCheckingCloudKit)
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        Task { await deleteAllRecords() }
                    } label: {
                        Label("Delete Local", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(recordCount == 0 || isBusy)

                    Button(role: .destructive) {
                        Task { await deletePublicRecords() }
                    } label: {
                        Label("Delete Public", systemImage: "trash.slash.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(cloudKitPublicCount == nil || cloudKitPublicCount == 0 || isBusy)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadRecordCount()
            await loadUnpublishedCount()
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
            await loadUnpublishedCount()
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
            await loadUnpublishedCount()
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

    private func loadUnpublishedCount() async {
        do {
            let predicate = #Predicate<PhotoRecord> { record in
                record.isPublished == false
            }
            let descriptor = FetchDescriptor<PhotoRecord>(predicate: predicate)
            let count = try modelContext.fetchCount(descriptor)
            await MainActor.run {
                unpublishedCount = count
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load unpublished count: \(error.localizedDescription)"
            }
        }
    }

    private func publishToPublicDatabase() async {
        isBusy = true
        errorMessage = nil
        progressMessage = "Publishing records to public database..."

        do {
            print("\n========================================")
            print("📤 Publishing to Public Database...")
            print("========================================")

            let publishedCount = try await PublicDatabaseService.publishRecords(
                username: username,
                context: modelContext
            )

            await MainActor.run {
                progressMessage = "✅ Published \(publishedCount) records to public database!"
            }

            print("========================================\n")

            // Wait to show success message
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Reload counts
            await loadUnpublishedCount()
            await checkPublicCloudKit()

            await MainActor.run {
                progressMessage = ""
                isBusy = false
            }

        } catch let error as PublicDatabaseError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                progressMessage = ""
                isBusy = false
            }
            print("❌ Publish Error: \(error.localizedDescription)")

        } catch let error as CloudKitError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                progressMessage = ""
                isBusy = false
            }
            print("❌ CloudKit Error: \(error.localizedDescription)")

        } catch {
            let errorMsg: String
            if let ckError = error as? CKError {
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    errorMsg = "Network unavailable. Check connection."
                case .notAuthenticated:
                    errorMsg = "Not signed in to iCloud."
                default:
                    errorMsg = "Publish failed: \(ckError.localizedDescription)"
                }
            } else {
                errorMsg = "Publish failed: \(error.localizedDescription)"
            }

            await MainActor.run {
                errorMessage = errorMsg
                progressMessage = ""
                isBusy = false
            }
            print("❌ Error: \(errorMsg)")
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
                print("  - Published: \(record.isPublished ? "Yes" : "No")")
                print("")
            }
            print("===============================")
        } catch {
            errorMessage = "Failed to fetch random records: \(error.localizedDescription)"
        }
    }

    // MARK: - CloudKit Check

    /// Check CloudKit Private Database record count - runs in background thread
    private func checkPrivateCloudKit() async {
        // Set checking state on main thread
        await MainActor.run {
            isCheckingCloudKit = true
            errorMessage = nil
        }

        // Perform CloudKit query in background
        do {
            print("\n========================================")
            print("🔍 Checking CloudKit Private Database...")
            print("========================================")

            let count = try await CloudKitHelper.getPrivateRecordCount()

            // Update UI on main thread
            await MainActor.run {
                cloudKitPrivateCount = count
                isCheckingCloudKit = false
            }

            // Print results to console
            print("✅ Private Database Record Count: \(count)")
            print("📱 Local Record Count: \(recordCount)")
            let difference = count - recordCount
            if difference == 0 {
                print("🎉 Perfect sync! Local and Private DB match.")
            } else if difference > 0 {
                print("⬇️  Private DB has \(difference) more records (will sync down)")
            } else {
                print("⬆️  Local has \(abs(difference)) more records (will sync up)")
            }
            print("========================================\n")

        } catch let error as CloudKitError {
            // Handle CloudKit-specific errors
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCheckingCloudKit = false
                cloudKitPrivateCount = nil
            }
            print("❌ CloudKit Error: \(error.localizedDescription)")

        } catch {
            // Handle other errors (including CKError)
            let errorMsg: String
            if let ckError = error as? CKError {
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    errorMsg = "Network unavailable. Try on a real device or check network connection."
                case .notAuthenticated:
                    errorMsg = "Not signed in to iCloud. Check Settings."
                case .serverResponseLost:
                    errorMsg = "Lost connection to CloudKit. Try again."
                default:
                    errorMsg = "CloudKit error: \(ckError.localizedDescription)"
                }
            } else {
                errorMsg = "Private DB check failed: \(error.localizedDescription)"
            }

            await MainActor.run {
                errorMessage = errorMsg
                isCheckingCloudKit = false
                cloudKitPrivateCount = nil
            }
            print("❌ Error: \(errorMsg)")
        }
    }

    /// Check CloudKit Public Database record count - runs in background thread
    private func checkPublicCloudKit() async {
        // Set checking state on main thread
        await MainActor.run {
            isCheckingCloudKit = true
            errorMessage = nil
        }

        // Perform CloudKit query in background
        do {
            print("\n========================================")
            print("🌍 Checking CloudKit Public Database...")
            print("========================================")

            let count = try await CloudKitHelper.getPublicRecordCount()

            // Update UI on main thread
            await MainActor.run {
                cloudKitPublicCount = count
                isCheckingCloudKit = false
            }

            // Print results to console
            print("✅ Public Database Record Count: \(count)")
            print("🌍 These are publicly shared photo points")
            print("========================================\n")

        } catch let error as CloudKitError {
            // Handle CloudKit-specific errors
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCheckingCloudKit = false
                cloudKitPublicCount = nil
            }
            print("❌ CloudKit Error: \(error.localizedDescription)")

        } catch {
            // Handle other errors (including CKError)
            let errorMsg: String
            if let ckError = error as? CKError {
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    errorMsg = "Network unavailable. Try on a real device or check network connection."
                case .notAuthenticated:
                    errorMsg = "Not signed in to iCloud. Check Settings."
                case .serverResponseLost:
                    errorMsg = "Lost connection to CloudKit. Try again."
                default:
                    errorMsg = "CloudKit error: \(ckError.localizedDescription)"
                }
            } else {
                errorMsg = "Public DB check failed: \(error.localizedDescription)"
            }

            await MainActor.run {
                errorMessage = errorMsg
                isCheckingCloudKit = false
                cloudKitPublicCount = nil
            }
            print("❌ Error: \(errorMsg)")
        }
    }

    // MARK: - Delete Public Records

    /// Delete all public database records created by this user
    private func deletePublicRecords() async {
        isBusy = true
        errorMessage = nil
        progressMessage = "Deleting public records..."

        do {
            print("\n========================================")
            print("🗑️  Deleting Public Database Records...")
            print("========================================")

            let deletedCount = try await CloudKitHelper.deleteAllPublicRecords()

            await MainActor.run {
                progressMessage = "✅ Deleted \(deletedCount) public records!"
                cloudKitPublicCount = 0  // Reset count after deletion
            }

            print("========================================\n")

            // Wait to show success message
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                progressMessage = ""
                isBusy = false
            }

        } catch let error as CloudKitError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                progressMessage = ""
                isBusy = false
            }
            print("❌ CloudKit Error: \(error.localizedDescription)")

        } catch {
            let errorMsg: String
            if let ckError = error as? CKError {
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    errorMsg = "Network unavailable. Check connection."
                case .notAuthenticated:
                    errorMsg = "Not signed in to iCloud."
                default:
                    errorMsg = "Delete failed: \(ckError.localizedDescription)"
                }
            } else {
                errorMsg = "Delete failed: \(error.localizedDescription)"
            }

            await MainActor.run {
                errorMessage = errorMsg
                progressMessage = ""
                isBusy = false
            }
            print("❌ Error: \(errorMsg)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PhotoRecord.self, inMemory: true)
}
