import Foundation

public struct FirestoreStoredDocument<DTO: Sendable>: Sendable {
    public let path: String
    public let documentID: String
    public let document: DTO

    public init(path: String, documentID: String, document: DTO) {
        self.path = path
        self.documentID = documentID
        self.document = document
    }
}

public protocol FirestoreDocumentStore: Sendable {
    func fetchDocument<DTO: Decodable & Sendable>(
        at path: String,
        as type: DTO.Type
    ) async throws -> FirestoreStoredDocument<DTO>?

    func writeDocument<DTO: Encodable & Sendable>(
        _ document: DTO,
        at path: String
    ) async throws

    func deleteDocument(at path: String) async throws

    func listDocuments<DTO: Decodable & Sendable>(
        in collectionPath: String,
        as type: DTO.Type
    ) async throws -> [FirestoreStoredDocument<DTO>]

    func listCollectionGroup<DTO: Decodable & Sendable>(
        _ collection: FirestoreCollection,
        as type: DTO.Type
    ) async throws -> [FirestoreStoredDocument<DTO>]
}

public actor InMemoryFirestoreDocumentStore: FirestoreDocumentStore {
    private var storage: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func fetchDocument<DTO: Decodable & Sendable>(
        at path: String,
        as type: DTO.Type
    ) async throws -> FirestoreStoredDocument<DTO>? {
        guard let data = storage[path] else {
            return nil
        }
        let document = try decoder.decode(DTO.self, from: data)
        return FirestoreStoredDocument(
            path: path,
            documentID: documentID(for: path),
            document: document
        )
    }

    public func writeDocument<DTO: Encodable & Sendable>(
        _ document: DTO,
        at path: String
    ) async throws {
        storage[path] = try encoder.encode(document)
    }

    public func deleteDocument(at path: String) async throws {
        storage[path] = nil
    }

    public func listDocuments<DTO: Decodable & Sendable>(
        in collectionPath: String,
        as type: DTO.Type
    ) async throws -> [FirestoreStoredDocument<DTO>] {
        let collectionComponents = pathComponents(for: collectionPath)
        return try storage.keys
            .filter { path in
                let components = pathComponents(for: path)
                return components.count == collectionComponents.count + 1 &&
                    Array(components.dropLast()) == collectionComponents
            }
            .sorted()
            .compactMap { path in
                guard let data = storage[path] else {
                    return nil
                }
                let document = try decoder.decode(DTO.self, from: data)
                return FirestoreStoredDocument(
                    path: path,
                    documentID: documentID(for: path),
                    document: document
                )
            }
    }

    public func listCollectionGroup<DTO: Decodable & Sendable>(
        _ collection: FirestoreCollection,
        as type: DTO.Type
    ) async throws -> [FirestoreStoredDocument<DTO>] {
        try storage.keys
            .filter { path in
                let components = pathComponents(for: path)
                guard components.count >= 2 else {
                    return false
                }
                return components[components.count - 2] == collection.rawValue
            }
            .sorted()
            .compactMap { path in
                guard let data = storage[path] else {
                    return nil
                }
                let document = try decoder.decode(DTO.self, from: data)
                return FirestoreStoredDocument(
                    path: path,
                    documentID: documentID(for: path),
                    document: document
                )
            }
    }

    public func storedDocumentPaths() async -> [String] {
        storage.keys.sorted()
    }

    private func documentID(for path: String) -> String {
        pathComponents(for: path).last ?? path
    }

    private func pathComponents(for path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }
}
