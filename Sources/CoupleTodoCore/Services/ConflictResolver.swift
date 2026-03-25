import Foundation

public enum ConflictResolutionStrategy: String, Sendable {
    case serverWins
    case clientWins
    case latestTimestamp
}

public enum ConflictResolver {
    public static func resolve(
        local: TodoTask,
        server: TodoTask,
        strategy: ConflictResolutionStrategy = .serverWins
    ) -> TodoTask {
        switch strategy {
        case .serverWins:
            if server.syncState == .serverFinal {
                return server
            }
            let serverUpdated = server.updatedAt ?? .distantPast
            let localUpdated = local.updatedAt ?? .distantPast
            return serverUpdated >= localUpdated ? server : local

        case .clientWins:
            if server.syncState == .serverFinal {
                return server
            }
            return local

        case .latestTimestamp:
            if server.syncState == .serverFinal {
                return server
            }
            let serverUpdated = server.updatedAt ?? .distantPast
            let localUpdated = local.updatedAt ?? .distantPast
            return serverUpdated >= localUpdated ? server : local
        }
    }

    public static func resolveBatch(
        localTasks: [TodoTask],
        serverTasks: [TodoTask],
        strategy: ConflictResolutionStrategy = .serverWins
    ) -> [TodoTask] {
        let serverMap = Dictionary(uniqueKeysWithValues: serverTasks.map { ($0.id, $0) })
        let localMap = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        var merged: [String: TodoTask] = [:]

        for (id, serverTask) in serverMap {
            if let localTask = localMap[id] {
                merged[id] = resolve(local: localTask, server: serverTask, strategy: strategy)
            } else {
                merged[id] = serverTask
            }
        }

        for (id, localTask) in localMap where merged[id] == nil {
            merged[id] = localTask
        }

        return Array(merged.values).sorted { $0.sortOrder < $1.sortOrder }
    }

    public static func isClockSkewAcceptable(
        clientTime: Date,
        serverTime: Date,
        toleranceSeconds: TimeInterval = 300
    ) -> Bool {
        abs(clientTime.timeIntervalSince(serverTime)) <= toleranceSeconds
    }
}
