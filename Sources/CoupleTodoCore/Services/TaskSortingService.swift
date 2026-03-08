import Foundation

public enum TaskSortingService {
    public static func sort(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { lhs, rhs in
            if lhs.bucket != rhs.bucket {
                return lhs.bucket == .required
            }
            if lhs.priority != rhs.priority {
                return priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private static func priorityRank(_ priority: TaskPriority) -> Int {
        switch priority {
        case .p0: return 0
        case .p1: return 1
        case .p2: return 2
        case .p3: return 3
        }
    }
}
