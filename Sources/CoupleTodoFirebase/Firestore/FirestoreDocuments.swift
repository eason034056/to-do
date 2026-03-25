import CoupleTodoCore
@preconcurrency import FirebaseFirestore
import Foundation

enum FirestoreDecodingError: LocalizedError {
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case let .missingField(field):
            return "Missing Firestore field: \(field)."
        case let .invalidField(field):
            return "Invalid Firestore field: \(field)."
        }
    }
}

enum FirestoreDocumentValue {
    static func requiredString(_ data: [String: Any], _ key: String) throws -> String {
        guard let value = data[key] as? String else {
            throw data[key] == nil ? FirestoreDecodingError.missingField(key) : FirestoreDecodingError.invalidField(key)
        }
        return value
    }

    static func optionalString(_ data: [String: Any], _ key: String) -> String? {
        data[key] as? String
    }

    static func requiredBool(_ data: [String: Any], _ key: String) throws -> Bool {
        guard let value = data[key] as? Bool else {
            throw data[key] == nil ? FirestoreDecodingError.missingField(key) : FirestoreDecodingError.invalidField(key)
        }
        return value
    }

    static func bool(_ data: [String: Any], _ key: String, default defaultValue: Bool) -> Bool {
        data[key] as? Bool ?? defaultValue
    }

    static func requiredInt(_ data: [String: Any], _ key: String) throws -> Int {
        if let value = data[key] as? Int {
            return value
        }
        if let value = data[key] as? Int64 {
            return Int(value)
        }
        if let value = data[key] as? NSNumber {
            return value.intValue
        }
        throw data[key] == nil ? FirestoreDecodingError.missingField(key) : FirestoreDecodingError.invalidField(key)
    }

    static func int(_ data: [String: Any], _ key: String, default defaultValue: Int) -> Int {
        (try? requiredInt(data, key)) ?? defaultValue
    }

    static func requiredDate(_ data: [String: Any], _ key: String) throws -> Date {
        guard let date = optionalDate(data, key) else {
            throw data[key] == nil ? FirestoreDecodingError.missingField(key) : FirestoreDecodingError.invalidField(key)
        }
        return date
    }

    static func optionalDate(_ data: [String: Any], _ key: String) -> Date? {
        switch data[key] {
        case let timestamp as Timestamp:
            return timestamp.dateValue()
        case let date as Date:
            return date
        case let string as String:
            return ISO8601DateFormatter().date(from: string)
        default:
            return nil
        }
    }

    static func requiredStringArray(_ data: [String: Any], _ key: String) throws -> [String] {
        guard let value = data[key] as? [String] else {
            throw data[key] == nil ? FirestoreDecodingError.missingField(key) : FirestoreDecodingError.invalidField(key)
        }
        return value
    }

    static func stringStringDictionary(_ data: [String: Any], _ key: String) -> [String: String] {
        data[key] as? [String: String] ?? [:]
    }

    static func stringBoolDictionary(_ data: [String: Any], _ key: String) -> [String: Bool] {
        data[key] as? [String: Bool] ?? [:]
    }

    static func requiredDecimal(_ data: [String: Any], _ key: String) throws -> Decimal {
        if let decimal = data[key] as? Decimal {
            return decimal
        }
        if let number = data[key] as? NSNumber {
            return number.decimalValue
        }
        if let string = data[key] as? String, let decimal = Decimal(string: string) {
            return decimal
        }
        throw data[key] == nil ? FirestoreDecodingError.missingField(key) : FirestoreDecodingError.invalidField(key)
    }
}

enum UserProfileDocument {
    static func decode(id: String, data: [String: Any]) throws -> UserProfile {
        let createdAt = try FirestoreDocumentValue.requiredDate(data, "createdAt")
        return UserProfile(
            id: id,
            displayName: try FirestoreDocumentValue.requiredString(data, "displayName"),
            photoURL: FirestoreDocumentValue.optionalString(data, "photoURL"),
            coupleId: FirestoreDocumentValue.optionalString(data, "coupleId"),
            currentTimezone: try FirestoreDocumentValue.requiredString(data, "currentTimezone"),
            currentUtcOffsetMinutes: try FirestoreDocumentValue.requiredInt(data, "currentUtcOffsetMinutes"),
            lastLocalDateKey: try FirestoreDocumentValue.requiredString(data, "lastLocalDateKey"),
            lastLocalWeekKey: try FirestoreDocumentValue.requiredString(data, "lastLocalWeekKey"),
            notificationPreferences: NotificationPreferencesDocument.decode(data["notificationPreferences"] as? [String: Any] ?? [:]),
            createdAt: createdAt,
            updatedAt: FirestoreDocumentValue.optionalDate(data, "updatedAt") ?? createdAt
        )
    }

    static func clientPayload(from user: UserProfile, includeCreatedAt: Bool = true) -> [String: Any] {
        var payload: [String: Any] = [
            "id": user.id,
            "displayName": user.displayName,
            "photoURL": nullable(user.photoURL),
            "coupleId": nullable(user.coupleId),
            "currentTimezone": user.currentTimezone,
            "currentUtcOffsetMinutes": user.currentUtcOffsetMinutes,
            "lastLocalDateKey": user.lastLocalDateKey,
            "lastLocalWeekKey": user.lastLocalWeekKey,
            "notificationPreferences": NotificationPreferencesDocument.encode(user.notificationPreferences),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if includeCreatedAt {
            payload["createdAt"] = Timestamp(date: user.createdAt)
        }
        return payload
    }
}

enum NotificationPreferencesDocument {
    static func decode(_ data: [String: Any]) -> NotificationPreferences {
        NotificationPreferences(
            planningReminderEnabled: FirestoreDocumentValue.bool(data, "planningReminderEnabled", default: true),
            settlementReminderEnabled: FirestoreDocumentValue.bool(data, "settlementReminderEnabled", default: true),
            timeSensitiveAllowed: FirestoreDocumentValue.bool(data, "timeSensitiveAllowed", default: true)
        )
    }

    static func encode(_ preferences: NotificationPreferences) -> [String: Any] {
        [
            "planningReminderEnabled": preferences.planningReminderEnabled,
            "settlementReminderEnabled": preferences.settlementReminderEnabled,
            "timeSensitiveAllowed": preferences.timeSensitiveAllowed
        ]
    }
}

enum ReminderConfigDocument {
    static func decode(_ data: [String: Any]) -> ReminderConfig {
        ReminderConfig(
            planningReminderTime: clockTime(data["planningReminderTime"] as? [String: Any], default: .init(hour: 21, minute: 30)),
            planningCutoffTime: clockTime(data["planningCutoffTime"] as? [String: Any], default: .init(hour: 23, minute: 0)),
            planningEscalationEveryMinutes: FirestoreDocumentValue.int(data, "planningEscalationEveryMinutes", default: 15),
            dailySettlementTime: clockTime(data["dailySettlementTime"] as? [String: Any], default: .init(hour: 23, minute: 59)),
            dailySettlementGraceMinutes: FirestoreDocumentValue.int(data, "dailySettlementGraceMinutes", default: 5)
        )
    }

    static func encode(_ config: ReminderConfig) -> [String: Any] {
        [
            "planningReminderTime": clockTime(config.planningReminderTime),
            "planningCutoffTime": clockTime(config.planningCutoffTime),
            "planningEscalationEveryMinutes": config.planningEscalationEveryMinutes,
            "dailySettlementTime": clockTime(config.dailySettlementTime),
            "dailySettlementGraceMinutes": config.dailySettlementGraceMinutes
        ]
    }

    private static func clockTime(_ data: [String: Any]?, default defaultValue: LocalClockTime) -> LocalClockTime {
        guard let data,
              let hour = data["hour"] as? Int,
              let minute = data["minute"] as? Int else {
            return defaultValue
        }
        return LocalClockTime(hour: hour, minute: minute)
    }

    private static func clockTime(_ time: LocalClockTime) -> [String: Any] {
        ["hour": time.hour, "minute": time.minute]
    }
}

enum PenaltyPolicyDocument {
    static func decode(_ data: [String: Any]) -> PenaltyPolicy {
        PenaltyPolicy(
            mode: PenaltyPolicy.Mode(rawValue: (data["mode"] as? String) ?? PenaltyPolicy.Mode.flatPerDay.rawValue) ?? .flatPerDay,
            amount: (try? FirestoreDocumentValue.requiredDecimal(data, "amount")) ?? 50,
            currency: (data["currency"] as? String) ?? "USD",
            enabled: FirestoreDocumentValue.bool(data, "enabled", default: true),
            planningMissPenaltyEnabled: FirestoreDocumentValue.bool(data, "planningMissPenaltyEnabled", default: false)
        )
    }

    static func encode(_ policy: PenaltyPolicy) -> [String: Any] {
        [
            "mode": policy.mode.rawValue,
            "amount": NSDecimalNumber(decimal: policy.amount),
            "currency": policy.currency,
            "enabled": policy.enabled,
            "planningMissPenaltyEnabled": policy.planningMissPenaltyEnabled
        ]
    }
}

enum CoupleDocument {
    static func decode(id: String, data: [String: Any]) throws -> Couple {
        let createdAt = try FirestoreDocumentValue.requiredDate(data, "createdAt")
        return Couple(
            id: id,
            memberIds: try FirestoreDocumentValue.requiredStringArray(data, "memberIds"),
            status: CoupleStatus(rawValue: try FirestoreDocumentValue.requiredString(data, "status")) ?? .pending,
            weekStartsOn: WeekStart(rawValue: try FirestoreDocumentValue.requiredString(data, "weekStartsOn")) ?? .monday,
            penaltyPolicy: PenaltyPolicyDocument.decode(data["penaltyPolicy"] as? [String: Any] ?? [:]),
            reminderConfig: ReminderConfigDocument.decode(data["reminderConfig"] as? [String: Any] ?? [:]),
            inviteCode: FirestoreDocumentValue.optionalString(data, "inviteCode"),
            createdAt: createdAt,
            updatedAt: FirestoreDocumentValue.optionalDate(data, "updatedAt") ?? createdAt
        )
    }

    static func clientSettingsPayload(from couple: Couple) -> [String: Any] {
        [
            "weekStartsOn": couple.weekStartsOn.rawValue,
            "penaltyPolicy": PenaltyPolicyDocument.encode(couple.penaltyPolicy),
            "reminderConfig": ReminderConfigDocument.encode(couple.reminderConfig),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

enum DeviceInstallationDocument {
    static func decode(id: String, data: [String: Any]) throws -> DeviceInstallation {
        DeviceInstallation(
            id: id,
            userId: try FirestoreDocumentValue.requiredString(data, "userId"),
            platform: DevicePlatform(rawValue: try FirestoreDocumentValue.requiredString(data, "platform")) ?? .ios,
            fcmToken: FirestoreDocumentValue.optionalString(data, "fcmToken"),
            apnsToken: FirestoreDocumentValue.optionalString(data, "apnsToken"),
            timezone: try FirestoreDocumentValue.requiredString(data, "timezone"),
            utcOffsetMinutes: try FirestoreDocumentValue.requiredInt(data, "utcOffsetMinutes"),
            lastLocalDateKey: try FirestoreDocumentValue.requiredString(data, "lastLocalDateKey"),
            supportsLiveActivities: FirestoreDocumentValue.bool(data, "supportsLiveActivities", default: false),
            supportsTimeSensitive: FirestoreDocumentValue.bool(data, "supportsTimeSensitive", default: false),
            appVersion: try FirestoreDocumentValue.requiredString(data, "appVersion"),
            buildNumber: try FirestoreDocumentValue.requiredString(data, "buildNumber"),
            updatedAt: try FirestoreDocumentValue.requiredDate(data, "updatedAt")
        )
    }

    static func clientPayload(from installation: DeviceInstallation) -> [String: Any] {
        [
            "id": installation.id,
            "userId": installation.userId,
            "platform": installation.platform.rawValue,
            "fcmToken": nullable(installation.fcmToken),
            "apnsToken": nullable(installation.apnsToken),
            "timezone": installation.timezone,
            "utcOffsetMinutes": installation.utcOffsetMinutes,
            "lastLocalDateKey": installation.lastLocalDateKey,
            "supportsLiveActivities": installation.supportsLiveActivities,
            "supportsTimeSensitive": installation.supportsTimeSensitive,
            "appVersion": installation.appVersion,
            "buildNumber": installation.buildNumber,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

enum DailyPlanDocument {
    static func decode(id: String, data: [String: Any]) throws -> DailyPlan {
        DailyPlan(
            id: id,
            userId: try FirestoreDocumentValue.requiredString(data, "userId"),
            coupleId: try FirestoreDocumentValue.requiredString(data, "coupleId"),
            dateKey: try FirestoreDocumentValue.requiredString(data, "dateKey"),
            localTimezone: try FirestoreDocumentValue.requiredString(data, "localTimezone"),
            submittedAt: FirestoreDocumentValue.optionalDate(data, "submittedAt"),
            planningMissed: FirestoreDocumentValue.bool(data, "planningMissed", default: false),
            localUtcOffsetMinutes: try? FirestoreDocumentValue.requiredInt(data, "localUtcOffsetMinutes"),
            lastEditedAt: FirestoreDocumentValue.optionalDate(data, "lastEditedAt"),
            requiredCount: FirestoreDocumentValue.int(data, "requiredCount", default: 0),
            optionalCount: FirestoreDocumentValue.int(data, "optionalCount", default: 0),
            version: FirestoreDocumentValue.int(data, "version", default: 1)
        )
    }

    static func clientPayload(from plan: DailyPlan) -> [String: Any] {
        [
            "id": plan.id,
            "userId": plan.userId,
            "coupleId": plan.coupleId,
            "dateKey": plan.dateKey,
            "localTimezone": plan.localTimezone,
            "submittedAt": timestamp(plan.submittedAt),
            "planningMissed": plan.planningMissed,
            "localUtcOffsetMinutes": nullable(plan.localUtcOffsetMinutes),
            "lastEditedAt": timestamp(plan.lastEditedAt),
            "requiredCount": plan.requiredCount,
            "optionalCount": plan.optionalCount,
            "version": plan.version
        ]
    }
}

enum TodoTaskDocument {
    static func decode(id: String, data: [String: Any]) throws -> TodoTask {
        TodoTask(
            id: id,
            ownerUserId: try FirestoreDocumentValue.requiredString(data, "ownerUserId"),
            dateKey: try FirestoreDocumentValue.requiredString(data, "dateKey"),
            localTimezone: try FirestoreDocumentValue.requiredString(data, "localTimezone"),
            title: try FirestoreDocumentValue.requiredString(data, "title"),
            notes: FirestoreDocumentValue.optionalString(data, "notes"),
            bucket: TaskBucket(rawValue: try FirestoreDocumentValue.requiredString(data, "bucket")) ?? .required,
            priority: TaskPriority(rawValue: try FirestoreDocumentValue.requiredString(data, "priority")) ?? .p0,
            status: TaskStatus(rawValue: try FirestoreDocumentValue.requiredString(data, "status")) ?? .pending,
            sortOrder: try FirestoreDocumentValue.requiredInt(data, "sortOrder"),
            completedAtServer: FirestoreDocumentValue.optionalDate(data, "completedAtServer"),
            localUtcOffsetMinutes: try? FirestoreDocumentValue.requiredInt(data, "localUtcOffsetMinutes"),
            createdAt: FirestoreDocumentValue.optionalDate(data, "createdAt"),
            updatedAt: FirestoreDocumentValue.optionalDate(data, "updatedAt"),
            completedAtClient: FirestoreDocumentValue.optionalDate(data, "completedAtClient"),
            carriedFromTaskId: FirestoreDocumentValue.optionalString(data, "carriedFromTaskId"),
            deleted: FirestoreDocumentValue.bool(data, "deleted", default: false),
            syncState: SyncState(rawValue: try FirestoreDocumentValue.requiredString(data, "syncState")) ?? .localPending
        )
    }

    static func clientPayload(from task: TodoTask, includeCreatedAt: Bool = true) -> [String: Any] {
        var payload: [String: Any] = [
            "id": task.id,
            "ownerUserId": task.ownerUserId,
            "dateKey": task.dateKey,
            "localTimezone": task.localTimezone,
            "title": task.title,
            "notes": nullable(task.notes),
            "bucket": task.bucket.rawValue,
            "priority": task.priority.rawValue,
            "status": task.status.rawValue,
            "sortOrder": task.sortOrder,
            "localUtcOffsetMinutes": nullable(task.localUtcOffsetMinutes),
            "updatedAt": FieldValue.serverTimestamp(),
            "completedAtClient": timestamp(task.completedAtClient),
            "carriedFromTaskId": nullable(task.carriedFromTaskId),
            "deleted": task.deleted,
            "syncState": task.syncState.rawValue
        ]
        if includeCreatedAt {
            payload["createdAt"] = timestampOrServerValue(task.createdAt)
        }
        return payload
    }
}

enum SettlementResultDocument {
    static func decode(_ data: [String: Any]) throws -> SettlementResult {
        SettlementResult(
            requiredTotal: try FirestoreDocumentValue.requiredInt(data, "requiredTotal"),
            requiredCompleted: try FirestoreDocumentValue.requiredInt(data, "requiredCompleted"),
            missedRequiredCount: try FirestoreDocumentValue.requiredInt(data, "missedRequiredCount"),
            outcome: SettlementOutcome(rawValue: try FirestoreDocumentValue.requiredString(data, "outcome")) ?? .fail,
            owesAmount: try FirestoreDocumentValue.requiredDecimal(data, "owesAmount")
        )
    }

    static func encode(_ result: SettlementResult) -> [String: Any] {
        [
            "requiredTotal": result.requiredTotal,
            "requiredCompleted": result.requiredCompleted,
            "missedRequiredCount": result.missedRequiredCount,
            "outcome": result.outcome.rawValue,
            "owesAmount": NSDecimalNumber(decimal: result.owesAmount)
        ]
    }
}

enum CounterpartySettlementSnapshotDocument {
    static func decode(_ data: [String: Any]) -> CounterpartySettlementSnapshot {
        CounterpartySettlementSnapshot(
            latestKnownDateKey: data["latestKnownDateKey"] as? String,
            latestKnownOutcome: (data["latestKnownOutcome"] as? String).flatMap(SettlementOutcome.init(rawValue:))
        )
    }

    static func encode(_ snapshot: CounterpartySettlementSnapshot) -> [String: Any] {
        [
            "latestKnownDateKey": nullable(snapshot.latestKnownDateKey),
            "latestKnownOutcome": nullable(snapshot.latestKnownOutcome?.rawValue)
        ]
    }
}

enum RewardImpactDocument {
    static func decode(_ data: [String: Any]) throws -> RewardImpact {
        RewardImpact(
            weekKey: try FirestoreDocumentValue.requiredString(data, "weekKey"),
            stillEligible: try FirestoreDocumentValue.requiredBool(data, "stillEligible")
        )
    }

    static func encode(_ impact: RewardImpact) -> [String: Any] {
        [
            "weekKey": impact.weekKey,
            "stillEligible": impact.stillEligible
        ]
    }
}

enum DailySettlementDocument {
    static func decode(id: String, data: [String: Any]) throws -> DailySettlement {
        DailySettlement(
            id: id,
            coupleId: try FirestoreDocumentValue.requiredString(data, "coupleId"),
            subjectUserId: try FirestoreDocumentValue.requiredString(data, "subjectUserId"),
            counterpartyUserId: try FirestoreDocumentValue.requiredString(data, "counterpartyUserId"),
            dateKey: try FirestoreDocumentValue.requiredString(data, "dateKey"),
            localTimezone: try FirestoreDocumentValue.requiredString(data, "localTimezone"),
            localWeekKey: try FirestoreDocumentValue.requiredString(data, "localWeekKey"),
            state: SettlementState(rawValue: try FirestoreDocumentValue.requiredString(data, "state")) ?? .pending,
            computedAt: try FirestoreDocumentValue.requiredDate(data, "computedAt"),
            graceAppliedUntil: FirestoreDocumentValue.optionalDate(data, "graceAppliedUntil"),
            subjectResult: try SettlementResultDocument.decode(data["subjectResult"] as? [String: Any] ?? [:]),
            counterpartySnapshot: CounterpartySettlementSnapshotDocument.decode(data["counterpartySnapshot"] as? [String: Any] ?? [:]),
            pendingAcknowledgementUserIds: try FirestoreDocumentValue.requiredStringArray(data, "pendingAcknowledgementUserIds"),
            rewardImpact: (try? RewardImpactDocument.decode(data["rewardImpact"] as? [String: Any] ?? [:]))
        )
    }

    static func encode(_ settlement: DailySettlement) -> [String: Any] {
        [
            "id": settlement.id,
            "coupleId": settlement.coupleId,
            "subjectUserId": settlement.subjectUserId,
            "counterpartyUserId": settlement.counterpartyUserId,
            "dateKey": settlement.dateKey,
            "localTimezone": settlement.localTimezone,
            "localWeekKey": settlement.localWeekKey,
            "state": settlement.state.rawValue,
            "computedAt": Timestamp(date: settlement.computedAt),
            "graceAppliedUntil": timestamp(settlement.graceAppliedUntil),
            "subjectResult": SettlementResultDocument.encode(settlement.subjectResult),
            "counterpartySnapshot": CounterpartySettlementSnapshotDocument.encode(settlement.counterpartySnapshot),
            "pendingAcknowledgementUserIds": settlement.pendingAcknowledgementUserIds,
            "rewardImpact": nullable(settlement.rewardImpact.map(RewardImpactDocument.encode))
        ]
    }

    static func acknowledgementPayload(from settlement: DailySettlement, userId: String) -> [AnyHashable: Any] {
        [
            "pendingAcknowledgementUserIds": settlement.pendingAcknowledgementUserIds.filter { $0 != userId },
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

enum RewardWeekDocument {
    static func decode(id: String, data: [String: Any]) throws -> RewardWeek {
        RewardWeek(
            id: id,
            coupleId: try FirestoreDocumentValue.requiredString(data, "coupleId"),
            weekKey: try FirestoreDocumentValue.requiredString(data, "weekKey"),
            effectiveWeekStartDate: try FirestoreDocumentValue.requiredString(data, "effectiveWeekStartDate"),
            draftedInWeekKey: try FirestoreDocumentValue.requiredString(data, "draftedInWeekKey"),
            rewardText: try FirestoreDocumentValue.requiredString(data, "rewardText"),
            status: RewardWeekStatus(rawValue: try FirestoreDocumentValue.requiredString(data, "status")) ?? .draft,
            eligibility: FirestoreDocumentValue.stringBoolDictionary(data, "eligibility"),
            memberLocalWeekKeys: FirestoreDocumentValue.stringStringDictionary(data, "memberLocalWeekKeys"),
            finalizeWhenBothMembersWeekClosed: FirestoreDocumentValue.bool(data, "finalizeWhenBothMembersWeekClosed", default: true),
            earnedAt: FirestoreDocumentValue.optionalDate(data, "earnedAt"),
            missedAt: FirestoreDocumentValue.optionalDate(data, "missedAt"),
            updatedAt: try FirestoreDocumentValue.requiredDate(data, "updatedAt")
        )
    }

    static func encode(_ rewardWeek: RewardWeek) -> [String: Any] {
        [
            "id": rewardWeek.id,
            "coupleId": rewardWeek.coupleId,
            "weekKey": rewardWeek.weekKey,
            "effectiveWeekStartDate": rewardWeek.effectiveWeekStartDate,
            "draftedInWeekKey": rewardWeek.draftedInWeekKey,
            "rewardText": rewardWeek.rewardText,
            "status": rewardWeek.status.rawValue,
            "eligibility": rewardWeek.eligibility,
            "memberLocalWeekKeys": rewardWeek.memberLocalWeekKeys,
            "finalizeWhenBothMembersWeekClosed": rewardWeek.finalizeWhenBothMembersWeekClosed,
            "earnedAt": timestamp(rewardWeek.earnedAt),
            "missedAt": timestamp(rewardWeek.missedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

enum PaymentRecordDocument {
    static func decode(id: String, data: [String: Any]) throws -> PaymentRecord {
        PaymentRecord(
            id: id,
            coupleId: try FirestoreDocumentValue.requiredString(data, "coupleId"),
            debtorUserId: try FirestoreDocumentValue.requiredString(data, "debtorUserId"),
            creditorUserId: try FirestoreDocumentValue.requiredString(data, "creditorUserId"),
            sourceSettlementId: try FirestoreDocumentValue.requiredString(data, "sourceSettlementId"),
            sourceDateKey: try FirestoreDocumentValue.requiredString(data, "sourceDateKey"),
            amount: try FirestoreDocumentValue.requiredDecimal(data, "amount"),
            currency: try FirestoreDocumentValue.requiredString(data, "currency"),
            status: PaymentStatus(rawValue: try FirestoreDocumentValue.requiredString(data, "status")) ?? .pending,
            markedPaidAt: FirestoreDocumentValue.optionalDate(data, "markedPaidAt"),
            acknowledgedAt: FirestoreDocumentValue.optionalDate(data, "acknowledgedAt"),
            disputedAt: FirestoreDocumentValue.optionalDate(data, "disputedAt"),
            markedByUserId: FirestoreDocumentValue.optionalString(data, "markedByUserId"),
            acknowledgedByUserId: FirestoreDocumentValue.optionalString(data, "acknowledgedByUserId"),
            updatedAt: try FirestoreDocumentValue.requiredDate(data, "updatedAt")
        )
    }

    static func encode(_ payment: PaymentRecord) -> [String: Any] {
        [
            "id": payment.id,
            "coupleId": payment.coupleId,
            "debtorUserId": payment.debtorUserId,
            "creditorUserId": payment.creditorUserId,
            "sourceSettlementId": payment.sourceSettlementId,
            "sourceDateKey": payment.sourceDateKey,
            "amount": NSDecimalNumber(decimal: payment.amount),
            "currency": payment.currency,
            "status": payment.status.rawValue,
            "markedPaidAt": timestamp(payment.markedPaidAt),
            "acknowledgedAt": timestamp(payment.acknowledgedAt),
            "disputedAt": timestamp(payment.disputedAt),
            "markedByUserId": nullable(payment.markedByUserId),
            "acknowledgedByUserId": nullable(payment.acknowledgedByUserId),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    static func markPaidPayload(actorUserId: String, paidAt: Date) -> [AnyHashable: Any] {
        [
            "markedPaidAt": Timestamp(date: paidAt),
            "markedByUserId": actorUserId,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    static func resolveStatusPayload(status: PaymentStatus, actorUserId: String, resolvedAt: Date) -> [AnyHashable: Any] {
        var payload: [AnyHashable: Any] = [
            "status": status.rawValue,
            "acknowledgedByUserId": actorUserId,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        switch status {
        case .pending:
            break
        case .acknowledged:
            payload["acknowledgedAt"] = Timestamp(date: resolvedAt)
            payload["disputedAt"] = FieldValue.delete()
        case .disputed:
            payload["disputedAt"] = Timestamp(date: resolvedAt)
            payload["acknowledgedAt"] = FieldValue.delete()
        }
        return payload
    }
}

enum EventLogEntryDocument {
    static func decode(id: String, data: [String: Any]) throws -> EventLogEntry {
        EventLogEntry(
            id: id,
            coupleId: try FirestoreDocumentValue.requiredString(data, "coupleId"),
            type: EventLogType(rawValue: try FirestoreDocumentValue.requiredString(data, "type")) ?? .taskUpdated,
            actorUserId: try FirestoreDocumentValue.requiredString(data, "actorUserId"),
            subjectId: FirestoreDocumentValue.optionalString(data, "subjectId"),
            payload: FirestoreDocumentValue.stringStringDictionary(data, "payload"),
            createdAt: try FirestoreDocumentValue.requiredDate(data, "createdAt")
        )
    }

    static func encode(_ event: EventLogEntry) -> [String: Any] {
        [
            "id": event.id,
            "coupleId": event.coupleId,
            "type": event.type.rawValue,
            "actorUserId": event.actorUserId,
            "subjectId": nullable(event.subjectId),
            "payload": event.payload,
            "createdAt": Timestamp(date: event.createdAt)
        ]
    }
}

func timestamp(_ date: Date?) -> Any {
    guard let date else { return NSNull() }
    return Timestamp(date: date)
}

func timestampOrServerValue(_ date: Date?) -> Any {
    guard let date else { return FieldValue.serverTimestamp() }
    return Timestamp(date: date)
}

func nullable(_ value: Any?) -> Any {
    value ?? NSNull()
}
