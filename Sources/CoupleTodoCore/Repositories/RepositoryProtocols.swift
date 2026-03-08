import Foundation

public protocol PlanRepository: Sendable {
    func upsertPlan(_ plan: DailyPlan) async throws
    func fetchPlan(userId: String, dateKey: String) async throws -> DailyPlan?
}

public protocol TaskRepository: Sendable {
    func replaceTasks(for userId: String, dateKey: String, tasks: [TodoTask]) async throws
    func fetchTasks(userId: String, dateKey: String) async throws -> [TodoTask]
}
