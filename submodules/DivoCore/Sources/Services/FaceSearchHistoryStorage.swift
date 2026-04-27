import Foundation
import UIKit

public final class FaceSearchHistoryStorage {
    public static let shared = FaceSearchHistoryStorage()

    private let userDefaultsKey = "divo.faceSearchHistory"
    private let maxStoredItems = 30

    private init() {}

    // MARK: - Public

    @discardableResult
    public func save(
        faceImage: UIImage,
        sourceImageData: Data,
        resultsCount: Int,
        faceIndex: Int,
        faceBBox: FRBoundingBox?,
        similarityPercent: Int = 30,
        filterParts: [String] = [],
        searchFields: [String: String] = [:]
    ) -> String {
        let faceFileName = UUID().uuidString + ".jpg"
        if let data = faceImage.jpegData(compressionQuality: 0.85) {
            let url = imageDirectory.appendingPathComponent(faceFileName)
            try? data.write(to: url)
        }

        let sourceFileName = UUID().uuidString + "_src.jpg"
        let sourceURL = imageDirectory.appendingPathComponent(sourceFileName)
        try? sourceImageData.write(to: sourceURL)

        let item = FaceSearchHistoryItem(
            resultsCount: resultsCount,
            date: Date(),
            faceImageFileName: faceFileName,
            sourceImageFileName: sourceFileName,
            faceIndex: faceIndex,
            faceBBox: faceBBox,
            similarityPercent: similarityPercent,
            filterParts: filterParts,
            searchFields: searchFields
        )

        var items = loadAll()
        items.insert(item, at: 0)

        if items.count > maxStoredItems {
            let removed = Array(items[maxStoredItems...])
            for r in removed {
                removeFiles(for: r)
            }
            items = Array(items.prefix(maxStoredItems))
        }

        persist(items)
        return item.id
    }

    public func update(
        id: String,
        resultsCount: Int,
        similarityPercent: Int,
        filterParts: [String],
        searchFields: [String: String]
    ) {
        var items = loadAll()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let old = items[index]
        let updated = FaceSearchHistoryItem(
            id: old.id,
            resultsCount: resultsCount,
            date: Date(),
            faceImageFileName: old.faceImageFileName,
            sourceImageFileName: old.sourceImageFileName,
            faceIndex: old.faceIndex,
            faceBBox: old.faceBBox,
            similarityPercent: similarityPercent,
            filterParts: filterParts,
            searchFields: searchFields
        )
        items[index] = updated
        items.insert(items.remove(at: index), at: 0)
        persist(items)
    }

    public func loadAll() -> [FaceSearchHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([FaceSearchHistoryItem].self, from: data)) ?? []
    }

    public func loadRecent(_ limit: Int = 3) -> [FaceSearchHistoryItem] {
        Array(loadAll().prefix(limit))
    }

    public func faceImage(for item: FaceSearchHistoryItem) -> UIImage? {
        let url = imageDirectory.appendingPathComponent(item.faceImageFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    public func sourceImageData(for item: FaceSearchHistoryItem) -> Data? {
        guard !item.sourceImageFileName.isEmpty else { return nil }
        let url = imageDirectory.appendingPathComponent(item.sourceImageFileName)
        return try? Data(contentsOf: url)
    }

    public func clearAll() {
        let items = loadAll()
        for item in items {
            removeFiles(for: item)
        }
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Private

    private func persist(_ items: [FaceSearchHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func removeFiles(for item: FaceSearchHistoryItem) {
        removeFile(item.faceImageFileName)
        if !item.sourceImageFileName.isEmpty {
            removeFile(item.sourceImageFileName)
        }
    }

    private func removeFile(_ fileName: String) {
        let url = imageDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    private lazy var imageDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("divo_face_history", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
}
