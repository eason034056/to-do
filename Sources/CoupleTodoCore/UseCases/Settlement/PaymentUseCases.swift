import Foundation

public enum PaymentMutationError: Error, Equatable {
    case paymentNotFound
    case forbidden
    case invalidState
}

public struct MarkPaymentPaidRequest: Sendable {
    public let coupleId: String
    public let recordId: String
    public let debtorUserId: String
    public let paidAt: Date

    public init(coupleId: String, recordId: String, debtorUserId: String, paidAt: Date) {
        self.coupleId = coupleId
        self.recordId = recordId
        self.debtorUserId = debtorUserId
        self.paidAt = paidAt
    }
}

public struct MarkPaymentPaidUseCase: Sendable {
    private let paymentRepository: PaymentRepository

    public init(paymentRepository: PaymentRepository) {
        self.paymentRepository = paymentRepository
    }

    @discardableResult
    public func execute(_ request: MarkPaymentPaidRequest) async throws -> PaymentRecord {
        guard let payment = try await paymentRepository.fetchPayment(coupleId: request.coupleId, recordId: request.recordId) else {
            throw PaymentMutationError.paymentNotFound
        }
        guard payment.debtorUserId == request.debtorUserId else {
            throw PaymentMutationError.forbidden
        }

        try await paymentRepository.markPaymentPaid(
            coupleId: request.coupleId,
            recordId: request.recordId,
            debtorUserId: request.debtorUserId,
            paidAt: request.paidAt
        )

        guard let updated = try await paymentRepository.fetchPayment(coupleId: request.coupleId, recordId: request.recordId) else {
            throw PaymentMutationError.paymentNotFound
        }
        return updated
    }
}

public struct ResolvePaymentStatusRequest: Sendable {
    public let coupleId: String
    public let recordId: String
    public let creditorUserId: String
    public let status: PaymentStatus
    public let resolvedAt: Date

    public init(
        coupleId: String,
        recordId: String,
        creditorUserId: String,
        status: PaymentStatus,
        resolvedAt: Date
    ) {
        self.coupleId = coupleId
        self.recordId = recordId
        self.creditorUserId = creditorUserId
        self.status = status
        self.resolvedAt = resolvedAt
    }
}

public struct ResolvePaymentStatusUseCase: Sendable {
    private let paymentRepository: PaymentRepository

    public init(paymentRepository: PaymentRepository) {
        self.paymentRepository = paymentRepository
    }

    @discardableResult
    public func execute(_ request: ResolvePaymentStatusRequest) async throws -> PaymentRecord {
        guard let payment = try await paymentRepository.fetchPayment(coupleId: request.coupleId, recordId: request.recordId) else {
            throw PaymentMutationError.paymentNotFound
        }
        guard payment.creditorUserId == request.creditorUserId else {
            throw PaymentMutationError.forbidden
        }
        guard request.status == .acknowledged || request.status == .disputed else {
            throw PaymentMutationError.invalidState
        }
        guard payment.markedPaidAt != nil else {
            throw PaymentMutationError.invalidState
        }

        try await paymentRepository.resolvePaymentStatus(
            coupleId: request.coupleId,
            recordId: request.recordId,
            creditorUserId: request.creditorUserId,
            status: request.status,
            resolvedAt: request.resolvedAt
        )

        guard let updated = try await paymentRepository.fetchPayment(coupleId: request.coupleId, recordId: request.recordId) else {
            throw PaymentMutationError.paymentNotFound
        }
        return updated
    }
}
