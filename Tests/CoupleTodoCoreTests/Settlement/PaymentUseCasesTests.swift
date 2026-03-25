import XCTest
@testable import CoupleTodoCore

final class PaymentUseCasesTests: XCTestCase {
    func testMarkPaymentPaidAllowsDebtorAndUpdatesTimestamp() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-10T01:00:00Z"))
        let payment = PaymentRecord(
            id: "pay_1",
            coupleId: "cpl_1",
            debtorUserId: "usr_1",
            creditorUserId: "usr_2",
            sourceSettlementId: "usr_1_2026-03-09",
            sourceDateKey: "2026-03-09",
            amount: 50,
            currency: "USD",
            status: .pending,
            updatedAt: now
        )
        let useCase = MarkPaymentPaidUseCase(paymentRepository: TestPaymentRepository(seed: [payment]))

        let updated = try await useCase.execute(
            MarkPaymentPaidRequest(
                coupleId: "cpl_1",
                recordId: "pay_1",
                debtorUserId: "usr_1",
                paidAt: now
            )
        )

        XCTAssertEqual(updated.markedByUserId, "usr_1")
        XCTAssertEqual(updated.markedPaidAt, now)
        XCTAssertEqual(updated.status, .pending)
    }

    func testMarkPaymentPaidRejectsWhenActorIsNotDebtor() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-10T01:00:00Z"))
        let payment = PaymentRecord(
            id: "pay_1",
            coupleId: "cpl_1",
            debtorUserId: "usr_1",
            creditorUserId: "usr_2",
            sourceSettlementId: "usr_1_2026-03-09",
            sourceDateKey: "2026-03-09",
            amount: 50,
            currency: "USD",
            status: .pending,
            updatedAt: now
        )
        let useCase = MarkPaymentPaidUseCase(paymentRepository: TestPaymentRepository(seed: [payment]))

        do {
            _ = try await useCase.execute(
                MarkPaymentPaidRequest(
                    coupleId: "cpl_1",
                    recordId: "pay_1",
                    debtorUserId: "usr_other",
                    paidAt: now
                )
            )
            XCTFail("Expected forbidden error")
        } catch let error as PaymentMutationError {
            XCTAssertEqual(error, .forbidden)
        }
    }

    func testResolvePaymentStatusAllowsCreditorToAcknowledgeAfterPaid() async throws {
        let paidAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-10T01:00:00Z"))
        let resolvedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-10T02:00:00Z"))
        let payment = PaymentRecord(
            id: "pay_1",
            coupleId: "cpl_1",
            debtorUserId: "usr_1",
            creditorUserId: "usr_2",
            sourceSettlementId: "usr_1_2026-03-09",
            sourceDateKey: "2026-03-09",
            amount: 50,
            currency: "USD",
            status: .pending,
            markedPaidAt: paidAt,
            markedByUserId: "usr_1",
            updatedAt: paidAt
        )
        let useCase = ResolvePaymentStatusUseCase(paymentRepository: TestPaymentRepository(seed: [payment]))

        let updated = try await useCase.execute(
            ResolvePaymentStatusRequest(
                coupleId: "cpl_1",
                recordId: "pay_1",
                creditorUserId: "usr_2",
                status: .acknowledged,
                resolvedAt: resolvedAt
            )
        )

        XCTAssertEqual(updated.status, .acknowledged)
        XCTAssertEqual(updated.acknowledgedByUserId, "usr_2")
        XCTAssertEqual(updated.acknowledgedAt, resolvedAt)
    }

    func testResolvePaymentStatusRejectsAcknowledgementBeforeDebtorMarksPaid() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-10T02:00:00Z"))
        let payment = PaymentRecord(
            id: "pay_1",
            coupleId: "cpl_1",
            debtorUserId: "usr_1",
            creditorUserId: "usr_2",
            sourceSettlementId: "usr_1_2026-03-09",
            sourceDateKey: "2026-03-09",
            amount: 50,
            currency: "USD",
            status: .pending,
            updatedAt: now
        )
        let useCase = ResolvePaymentStatusUseCase(paymentRepository: TestPaymentRepository(seed: [payment]))

        do {
            _ = try await useCase.execute(
                ResolvePaymentStatusRequest(
                    coupleId: "cpl_1",
                    recordId: "pay_1",
                    creditorUserId: "usr_2",
                    status: .acknowledged,
                    resolvedAt: now
                )
            )
            XCTFail("Expected invalid state error")
        } catch let error as PaymentMutationError {
            XCTAssertEqual(error, .invalidState)
        }
    }
}
