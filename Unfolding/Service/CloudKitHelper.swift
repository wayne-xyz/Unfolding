// CloudKitHelper.swift
// Unfolding

import Foundation
import CloudKit

/// Helper for querying CloudKit private database
enum CloudKitHelper {

    // CloudKit container and database
    private static let container = CKContainer(identifier: "iCloud.com.aequatione.unfolding")
    private static let privateDatabase = container.privateCloudDatabase
    private static let publicDatabase = container.publicCloudDatabase

    // Record types
    private static let privateRecordType = "CD_PhotoRecord"  // SwiftData creates CloudKit records with "CD_" prefix
    private static let publicRecordType = "PublicPhotoPoint"

    // MARK: - Account Status

    /// Check if user is signed in to iCloud
    static func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }

    // MARK: - Query Private Database

    /// Get count of records in CloudKit private database
    /// Uses query with CD_latitude field (which is indexed/queryable)
    static func getPrivateRecordCount() async throws -> Int {
        // Check account status first
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw CloudKitError.notSignedIn
        }

        var totalCount = 0
        var cursor: CKQueryOperation.Cursor?

        do {
            // Query with CD_latitude > 1 (this field is queryable based on your console query)
            let predicate = NSPredicate(format: "CD_latitude > %f", 1.0)
            let query = CKQuery(recordType: privateRecordType, predicate: predicate)

            print("🔍 Querying CloudKit with predicate: CD_latitude > 1")

            // Initial query - fetch only one field to minimize data transfer
            let (results, nextCursor) = try await privateDatabase.records(
                matching: query,
                desiredKeys: ["CD_latitude"]  // Only fetch latitude field
            )

            // Count successful records
            for (_, result) in results {
                if case .success = result {
                    totalCount += 1
                }
            }

            cursor = nextCursor
            print("  First batch: \(totalCount) records")

            // Continue fetching if there are more results
            while let queryCursor = cursor {
                let (moreResults, moreCursor) = try await privateDatabase.records(
                    continuingMatchFrom: queryCursor,
                    desiredKeys: ["CD_latitude"]
                )

                var batchCount = 0
                for (_, result) in moreResults {
                    if case .success = result {
                        totalCount += 1
                        batchCount += 1
                    }
                }

                print("  Next batch: \(batchCount) records (total so far: \(totalCount))")
                cursor = moreCursor
            }

            return totalCount

        } catch {
            throw error
        }
    }

    // MARK: - Query Public Database

    /// Get count of records in CloudKit public database
    /// Queries PublicPhotoPoint records with latitude > 1
    static func getPublicRecordCount() async throws -> Int {
        // Check account status first
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw CloudKitError.notSignedIn
        }

        var totalCount = 0
        var cursor: CKQueryOperation.Cursor?

        do {
            // Query with latitude > 1 (public database uses 'latitude' not 'CD_latitude')
            let predicate = NSPredicate(format: "latitude > %f", 1.0)
            let query = CKQuery(recordType: publicRecordType, predicate: predicate)

            print("🌍 Querying Public Database with predicate: latitude > 1")

            // Initial query - fetch only one field to minimize data transfer
            let (results, nextCursor) = try await publicDatabase.records(
                matching: query,
                desiredKeys: ["latitude"]  // Only fetch latitude field
            )

            // Count successful records
            for (_, result) in results {
                if case .success = result {
                    totalCount += 1
                }
            }

            cursor = nextCursor
            print("  First batch: \(totalCount) records")

            // Continue fetching if there are more results
            while let queryCursor = cursor {
                let (moreResults, moreCursor) = try await publicDatabase.records(
                    continuingMatchFrom: queryCursor,
                    desiredKeys: ["latitude"]
                )

                var batchCount = 0
                for (_, result) in moreResults {
                    if case .success = result {
                        totalCount += 1
                        batchCount += 1
                    }
                }

                print("  Next batch: \(batchCount) records (total so far: \(totalCount))")
                cursor = moreCursor
            }

            return totalCount

        } catch {
            throw error
        }
    }

    // MARK: - Delete Public Database Records

    /// Delete all PublicPhotoPoint records created by current user
    /// Only deletes records where createdBy matches current user (CloudKit enforces this)
    static func deleteAllPublicRecords() async throws -> Int {
        // Check account status first
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw CloudKitError.notSignedIn
        }

        var deletedCount = 0

        do {
            print("🗑️  Fetching public records to delete...")

            // First, fetch all record IDs created by this user
            // Query with latitude > 1 to get all records
            let predicate = NSPredicate(format: "latitude > %f", 1.0)
            let query = CKQuery(recordType: publicRecordType, predicate: predicate)

            var recordIDsToDelete: [CKRecord.ID] = []
            var cursor: CKQueryOperation.Cursor?

            // Fetch all records (need IDs to delete)
            let (results, nextCursor) = try await publicDatabase.records(
                matching: query,
                desiredKeys: []  // Only need record IDs
            )

            for (recordID, result) in results {
                if case .success = result {
                    recordIDsToDelete.append(recordID)
                }
            }

            cursor = nextCursor
            print("  Found \(recordIDsToDelete.count) records to delete (first batch)")

            // Continue fetching if there are more results
            while let queryCursor = cursor {
                let (moreResults, moreCursor) = try await publicDatabase.records(
                    continuingMatchFrom: queryCursor,
                    desiredKeys: []
                )

                for (recordID, result) in moreResults {
                    if case .success = result {
                        recordIDsToDelete.append(recordID)
                    }
                }

                cursor = moreCursor
                print("  Found \(recordIDsToDelete.count) total records to delete")
            }

            guard !recordIDsToDelete.isEmpty else {
                print("✅ No records to delete")
                return 0
            }

            print("🗑️  Deleting \(recordIDsToDelete.count) records from public database...")

            // Delete in batches of 400 (CloudKit limit per operation)
            let batchSize = 400
            for batchStart in stride(from: 0, to: recordIDsToDelete.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, recordIDsToDelete.count)
                let batch = Array(recordIDsToDelete[batchStart..<batchEnd])

                let (_, deleteResults) = try await publicDatabase.modifyRecords(
                    saving: [],
                    deleting: batch
                )

                // Count successful deletions
                for (_, result) in deleteResults {
                    if case .success = result {
                        deletedCount += 1
                    } else if case .failure(let error) = result {
                        // Log individual deletion failures
                        print("  ⚠️  Failed to delete record: \(error.localizedDescription)")
                    }
                }

                print("  Deleted batch: \(deletedCount)/\(recordIDsToDelete.count)")
            }

            print("✅ Successfully deleted \(deletedCount) public records")
            return deletedCount

        } catch {
            print("❌ Error deleting public records: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case notSignedIn
    case networkUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in to iCloud. Please sign in to your iCloud account in Settings."
        case .networkUnavailable:
            return "Network connection unavailable. Please check your internet connection."
        case .permissionDenied:
            return "CloudKit access denied. Please check your iCloud settings."
        }
    }
}
