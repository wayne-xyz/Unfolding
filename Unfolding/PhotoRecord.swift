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

    // Location extracted from the photo metadata (if available)
    var latitude: Double?
    var longitude: Double?

    // Original creation date of the photo (if available)
    var photoCreationDate: Date?

    // The photo's filename (from PHAssetResource if available)
    var photoFilename: String?

    init(
        timestamp: Date = Date(),
        assetIdentifier: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        photoCreationDate: Date? = nil,
        photoFilename: String? = nil
    ) {
        self.timestamp = timestamp
        self.assetIdentifier = assetIdentifier
        self.latitude = latitude
        self.longitude = longitude
        self.photoCreationDate = photoCreationDate
        self.photoFilename = photoFilename
    }
}

