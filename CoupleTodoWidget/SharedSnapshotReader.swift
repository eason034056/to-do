import Foundation
import CoupleTodoCore

struct SharedSnapshotReader {
    let appGroupIdentifier: String
    let filename: String

    init(
        appGroupIdentifier: String = "group.com.coupletodo.shared",
        filename: String = "shared_snapshot.json"
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.filename = filename
    }

    func read() -> SharedSnapshot? {
        let directoryURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
        guard let directoryURL else { return nil }
        let fileURL = directoryURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedSnapshot.self, from: data)
    }
}
