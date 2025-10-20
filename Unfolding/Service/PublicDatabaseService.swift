// PublicDatabaseService.swift
// Unfolding

import Foundation
import CloudKit
import SwiftData

/// Service for publishing local photo records to CloudKit public database
enum PublicDatabaseService {

    private static let container = CKContainer(identifier: "iCloud.com.aequatione.unfolding")
    private static let publicDatabase = container.publicCloudDatabase
    private static let publicRecordType = "PublicPhotoPoint"

    // MARK: - Publish Records

    /// Publish unpublished local records to public database
    /// Only publishes records where isPublished = false
    /// Returns count of successfully published records
    static func publishRecords(username: String, context: ModelContext) async throws -> Int {
        // Validate username
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PublicDatabaseError.invalidUsername
        }

        // Check account status
        let status = try await container.accountStatus()
        guard status == .available else {
            throw CloudKitError.notSignedIn
        }

        // Fetch unpublished records (isPublished = false)
        let predicate = #Predicate<PhotoRecord> { record in
            record.isPublished == false
        }
        var descriptor = FetchDescriptor<PhotoRecord>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        let unpublishedRecords = try context.fetch(descriptor)

        guard !unpublishedRecords.isEmpty else {
            print("📭 No unpublished records to publish")
            return 0
        }

        print("📤 Publishing \(unpublishedRecords.count) records to public database...")

        var publishedCount = 0
        var recordsToUpdate: [PhotoRecord] = []

        // Create CloudKit records from local data
        var ckRecordsToSave: [CKRecord] = []

        for record in unpublishedRecords {
            // Skip records without required data
            guard let uniqueHash = record.uniqueHash,
                  let latitude = record.latitude,
                  let longitude = record.longitude else {
                continue
            }

            // Create CloudKit record
            let recordID = CKRecord.ID(recordName: uniqueHash) // Use uniqueHash as record ID
            let ckRecord = CKRecord(recordType: publicRecordType, recordID: recordID)

            // Set fields
            ckRecord["username"] = username as CKRecordValue
            ckRecord["uniqueHash"] = uniqueHash as CKRecordValue
            ckRecord["latitude"] = latitude as CKRecordValue
            ckRecord["longitude"] = longitude as CKRecordValue

            if let creationDate = record.photoCreationDate {
                ckRecord["photoCreationDate"] = creationDate as CKRecordValue
            }

            ckRecordsToSave.append(ckRecord)
            recordsToUpdate.append(record)
        }

        guard !ckRecordsToSave.isEmpty else {
            print("⚠️  No valid records to publish")
            return 0
        }

        print("📦 Prepared \(ckRecordsToSave.count) records for publishing")

        // Save to CloudKit in batches of 400 (CloudKit limit)
        let batchSize = 400
        var successfulRecordNames: Set<String> = []

        for batchStart in stride(from: 0, to: ckRecordsToSave.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, ckRecordsToSave.count)
            let batch = Array(ckRecordsToSave[batchStart..<batchEnd])

            do {
                let (saveResults, _) = try await publicDatabase.modifyRecords(
                    saving: batch,
                    deleting: []
                )

                // Track successful saves
                for (recordID, result) in saveResults {
                    switch result {
                    case .success:
                        successfulRecordNames.insert(recordID.recordName)
                        publishedCount += 1
                    case .failure(let error):
                        print("  ⚠️  Failed to publish record \(recordID.recordName): \(error.localizedDescription)")
                    }
                }

                print("  ✅ Published batch: \(publishedCount)/\(ckRecordsToSave.count)")

            } catch {
                print("  ❌ Batch save failed: \(error.localizedDescription)")
                throw error
            }
        }

        // Update local records: mark successfully published records as isPublished = true
        for record in recordsToUpdate {
            if let hash = record.uniqueHash, successfulRecordNames.contains(hash) {
                record.isPublished = true
            }
        }

        // Save context to persist isPublished updates
        try context.save()

        print("✅ Successfully published \(publishedCount) records")
        print("📝 Updated \(publishedCount) local records (isPublished = true)")

        return publishedCount
    }
}

// MARK: - Errors

enum PublicDatabaseError: LocalizedError {
    case invalidUsername

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Username cannot be empty. Please enter a valid username."
        }
    }
}
