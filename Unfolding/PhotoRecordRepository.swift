// PhotoRecordRepository.swift
// Unfolding

import Foundation
import SwiftData

enum PhotoRecordRepository {
    static func fetchAll(context: ModelContext) throws -> [PhotoRecord] {
        var descriptor = FetchDescriptor<PhotoRecord>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        return try context.fetch(descriptor)
    }

    static func count(context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<PhotoRecord>()
        return try context.fetchCount(descriptor)
    }

    static func saveRecord(context: ModelContext, metadata: PhotoMetadata) throws {
        // Only save if geolocation data exists
        guard metadata.latitude != nil && metadata.longitude != nil else {
            throw NSError(domain: "PhotoRecordRepository", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Photo has no geolocation data"])
        }

        // Generate unique hash from assetIdentifier + filename (without extension)
        let uniqueHash = generateUniqueHash(assetIdentifier: metadata.assetIdentifier, filename: metadata.filename)

        // Check if record already exists by uniqueHash (prevent duplicates)
        if let hash = uniqueHash {
            let predicate = #Predicate<PhotoRecord> { record in
                record.uniqueHash == hash
            }
            var descriptor = FetchDescriptor<PhotoRecord>(predicate: predicate)
            descriptor.fetchLimit = 1

            if try context.fetch(descriptor).first != nil {
                // Record already exists - skip it (don't update, don't insert)
                return
            }
        }

        // Create new record if doesn't exist
        let record = PhotoRecord(
            timestamp: Date(),
            assetIdentifier: metadata.assetIdentifier,
            uniqueHash: uniqueHash,
            latitude: metadata.latitude,
            longitude: metadata.longitude,
            photoCreationDate: metadata.creationDate,
            photoFilename: metadata.filename
        )
        context.insert(record)
        try context.save()
    }

    /// Generate unique hash from assetIdentifier + filename (without extension)
    private static func generateUniqueHash(assetIdentifier: String?, filename: String?) -> String? {
        guard let assetID = assetIdentifier, let filename = filename else {
            return nil
        }

        // Remove file extension from filename
        let filenameWithoutExtension = (filename as NSString).deletingPathExtension

        // Combine assetIdentifier + filename (without extension)
        return "\(assetID)_\(filenameWithoutExtension)"
    }

    static func saveBulk(context: ModelContext, metadataList: [PhotoMetadata]) throws -> Int {
        var savedCount = 0
        for metadata in metadataList {
            // Skip photos without geolocation
            guard metadata.latitude != nil && metadata.longitude != nil else {
                continue
            }

            // Generate unique hash from assetIdentifier + filename (without extension)
            let uniqueHash = generateUniqueHash(assetIdentifier: metadata.assetIdentifier, filename: metadata.filename)

            // Check if record already exists by uniqueHash (prevent duplicates)
            if let hash = uniqueHash {
                let predicate = #Predicate<PhotoRecord> { record in
                    record.uniqueHash == hash
                }
                var descriptor = FetchDescriptor<PhotoRecord>(predicate: predicate)
                descriptor.fetchLimit = 1

                if try context.fetch(descriptor).first != nil {
                    // Record already exists - skip it (don't update, don't insert)
                    continue
                }
            }

            // Create new record if doesn't exist
            let record = PhotoRecord(
                timestamp: Date(),
                assetIdentifier: metadata.assetIdentifier,
                uniqueHash: uniqueHash,
                latitude: metadata.latitude,
                longitude: metadata.longitude,
                photoCreationDate: metadata.creationDate,
                photoFilename: metadata.filename
            )
            context.insert(record)
            savedCount += 1
        }
        try context.save()
        return savedCount
    }

    static func deleteAll(context: ModelContext) throws {
        let all = try fetchAll(context: context)
        for item in all {
            context.delete(item)
        }
        try context.save()
    }

    static func delete(records: [PhotoRecord], at offsets: IndexSet, context: ModelContext) throws {
        for index in offsets {
            context.delete(records[index])
        }
        try context.save()
    }

    static func fetchRandom(count: Int, context: ModelContext) throws -> [PhotoRecord] {
        let allRecords = try fetchAll(context: context)
        let sampleCount = min(count, allRecords.count)
        return Array(allRecords.shuffled().prefix(sampleCount))
    }
}

