// PhotoLibraryService.swift
// Unfolding

import Foundation
import Photos
import ImageIO
import UniformTypeIdentifiers

#if os(iOS)
import SwiftUI
import PhotosUI
#elseif os(macOS)
import PhotosUI
import AppKit
#endif

struct PhotoMetadata {
    var assetIdentifier: String?
    var latitude: Double?
    var longitude: Double?
    var creationDate: Date?
    var filename: String?
}

enum PhotoLibraryService {
    #if os(iOS)
    @available(iOS 16.0, *)
    static func extractMetadata(from item: PhotosPickerItem) async throws -> PhotoMetadata {
        var meta = PhotoMetadata()

        // Prefer PHAsset path if available (lets us get filename and location reliably)
        if let localID = item.itemIdentifier {
            meta.assetIdentifier = localID

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
            if let asset = fetchResult.firstObject {
                if let coord = asset.location?.coordinate {
                    meta.latitude = coord.latitude
                    meta.longitude = coord.longitude
                }
                meta.creationDate = asset.creationDate

                if let res = PHAssetResource.assetResources(for: asset).first {
                    meta.filename = res.originalFilename
                }
                return meta
            }
        }

        // Fallback: Load image data and parse EXIF GPS and date
        if let data = try await item.loadTransferable(type: Data.self) {
            let exif = exifInfo(fromImageData: data)
            meta.latitude = exif.latitude
            meta.longitude = exif.longitude
            meta.creationDate = exif.date
            // No reliable filename from raw data; leave nil
            return meta
        }

        return meta
    }
    #endif

    #if os(macOS)
    @available(macOS 13.0, *)
    static func extractMetadata(from result: PHPickerResult) async throws -> PhotoMetadata {
        var meta = PhotoMetadata()

        // Try to get asset identifier from PHPickerResult
        if let assetID = result.assetIdentifier {
            meta.assetIdentifier = assetID

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            if let asset = fetchResult.firstObject {
                if let coord = asset.location?.coordinate {
                    meta.latitude = coord.latitude
                    meta.longitude = coord.longitude
                }
                meta.creationDate = asset.creationDate

                if let res = PHAssetResource.assetResources(for: asset).first {
                    meta.filename = res.originalFilename
                }
                return meta
            }
        }

        // Fallback: Load from itemProvider and parse EXIF
        let itemProvider = result.itemProvider
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PhotoLibraryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data available"]))
                    }
                }
            }

            let exif = exifInfo(fromImageData: data)
            meta.latitude = exif.latitude
            meta.longitude = exif.longitude
            meta.creationDate = exif.date
        }

        return meta
    }
    #endif

    private static func exifInfo(fromImageData data: Data) -> (latitude: Double?, longitude: Double?, date: Date?) {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return (nil, nil, nil)
        }

        var latitude: Double?
        var longitude: Double?

        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude] as? Double {
                let ref = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
                latitude = (ref == "S") ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
                let ref = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()
                longitude = (ref == "W") ? -lon : lon
            }
        }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy:MM:dd HH:mm:ss"
            date = df.date(from: dateString)
        }

        return (latitude, longitude, date)
    }
}
