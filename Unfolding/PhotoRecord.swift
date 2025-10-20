//
//  PhotoRecord.swift
//  Unfolding
//
//  Created by Rongwei Ji on 10/2/25.
//

import Foundation
import SwiftData

@Model
final class PhotoRecord {
    // When the record was saved into SwiftData
    var timestamp: Date = Date()

    // The Photos asset identifier of the picked photo (if any)
    var assetIdentifier: String?

    // Unique hash: assetIdentifier + filename (without extension)
    // This is used to prevent duplicates across all devices
    // NOTE: CloudKit does not support @Attribute(.unique), so we check manually in code
    var uniqueHash: String?

    // Location extracted from the photo metadata (if available)
    var latitude: Double?
    var longitude: Double?

    // Original creation date of the photo (if available)
    var photoCreationDate: Date?

    // The photo's filename (from PHAssetResource if available)
    var photoFilename: String?

    // Whether this record has been published to public database
    var isPublished: Bool = false

    init(
        timestamp: Date = Date(),
        assetIdentifier: String? = nil,
        uniqueHash: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        photoCreationDate: Date? = nil,
        photoFilename: String? = nil,
        isPublished: Bool = false
    ) {
        self.timestamp = timestamp
        self.assetIdentifier = assetIdentifier
        self.uniqueHash = uniqueHash
        self.latitude = latitude
        self.longitude = longitude
        self.photoCreationDate = photoCreationDate
        self.photoFilename = photoFilename
        self.isPublished = isPublished
    }
}

