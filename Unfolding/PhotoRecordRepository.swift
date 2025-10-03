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
        // For iOS 17, fetch and count; replace with fetchCount when available
        return try fetchAll(context: context).count
    }

    static func saveRecord(context: ModelContext, metadata: PhotoMetadata) throws {
        let record = PhotoRecord(
            timestamp: Date(),
            assetIdentifier: metadata.assetIdentifier,
            latitude: metadata.latitude,
            longitude: metadata.longitude,
            photoCreationDate: metadata.creationDate,
            photoFilename: metadata.filename
        )
        context.insert(record)
        try context.save()
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
}

