/**
 * Firestore Security Rules Integration Tests
 *
 * These tests are designed to run against the Firebase Emulator Suite.
 * To run:
 *   1. Install firebase-tools: npm install -g firebase-tools
 *   2. Start emulators: firebase emulators:start --only firestore
 *   3. Run tests: npx jest test/firestore-rules.test.ts
 *
 * Or use the combined command:
 *   firebase emulators:exec --only firestore "npx jest test/firestore-rules.test.ts"
 */

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import * as fs from "fs";

let testEnv: RulesTestEnvironment;

const PROJECT_ID = "coupletodo-test";
const COUPLE_ID = "couple_1";
const USER_A = "user_a";
const USER_B = "user_b";
const OUTSIDER = "user_outsider";

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc(`users/${USER_A}`).set({
      id: USER_A,
      coupleId: COUPLE_ID,
      displayName: "User A",
      currentTimezone: "America/New_York",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await db.doc(`users/${USER_B}`).set({
      id: USER_B,
      coupleId: COUPLE_ID,
      displayName: "User B",
      currentTimezone: "Asia/Tokyo",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await db.doc(`couples/${COUPLE_ID}`).set({
      id: COUPLE_ID,
      memberIds: [USER_A, USER_B],
      status: "active",
      weekStartsOn: "monday",
      penaltyPolicy: { mode: "flat_per_day", amount: 50, currency: "USD", enabled: true },
      reminderConfig: {},
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
});

describe("User profile rules", () => {
  test("user can read own profile", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(db.doc(`users/${USER_A}`).get());
  });

  test("partner can read profile via coupleId membership", async () => {
    const db = testEnv.authenticatedContext(USER_B).firestore();
    await assertSucceeds(db.doc(`users/${USER_A}`).get());
  });

  test("outsider cannot read profile", async () => {
    const db = testEnv.authenticatedContext(OUTSIDER).firestore();
    await assertFails(db.doc(`users/${USER_A}`).get());
  });

  test("user cannot mutate coupleId", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`users/${USER_A}`).update({ coupleId: "hijack" })
    );
  });
});

describe("Couple rules", () => {
  test("member can read couple", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(db.doc(`couples/${COUPLE_ID}`).get());
  });

  test("outsider cannot read couple", async () => {
    const db = testEnv.authenticatedContext(OUTSIDER).firestore();
    await assertFails(db.doc(`couples/${COUPLE_ID}`).get());
  });

  test("member can update settings", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}`).update({
        weekStartsOn: "sunday",
        updatedAt: new Date(),
      })
    );
  });

  test("member cannot update memberIds", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}`).update({
        memberIds: [USER_A],
        updatedAt: new Date(),
      })
    );
  });

  test("nobody can create couple directly", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/new_couple`).set({
        id: "new_couple",
        memberIds: [USER_A],
        status: "pending",
      })
    );
  });
});

describe("Settlement rules - immutability", () => {
  const SETTLEMENT_ID = `${USER_A}_2026-03-25`;

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`couples/${COUPLE_ID}/settlements/${SETTLEMENT_ID}`).set({
        id: SETTLEMENT_ID,
        coupleId: COUPLE_ID,
        subjectUserId: USER_A,
        counterpartyUserId: USER_B,
        dateKey: "2026-03-25",
        localTimezone: "America/New_York",
        localWeekKey: "2026-W13",
        state: "finalized",
        computedAt: new Date(),
        subjectResult: { outcome: "fail", owesAmount: 50 },
        pendingAcknowledgementUserIds: [USER_A, USER_B],
        updatedAt: new Date(),
      });
    });
  });

  test("member can update acknowledgement", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/settlements/${SETTLEMENT_ID}`).update({
        pendingAcknowledgementUserIds: [USER_B],
        updatedAt: new Date(),
      })
    );
  });

  test("member cannot change outcome or state", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/settlements/${SETTLEMENT_ID}`).update({
        state: "pending",
        updatedAt: new Date(),
      })
    );
  });

  test("member cannot change subjectResult", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/settlements/${SETTLEMENT_ID}`).update({
        subjectResult: { outcome: "pass", owesAmount: 0 },
        updatedAt: new Date(),
      })
    );
  });
});

describe("Payment rules", () => {
  const PAYMENT_ID = "payment_1";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`couples/${COUPLE_ID}/payments/${PAYMENT_ID}`).set({
        id: PAYMENT_ID,
        coupleId: COUPLE_ID,
        debtorUserId: USER_A,
        creditorUserId: USER_B,
        sourceSettlementId: "settle_1",
        sourceDateKey: "2026-03-25",
        amount: 50,
        currency: "USD",
        status: "pending",
        updatedAt: new Date(),
      });
    });
  });

  test("debtor can mark paid", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/payments/${PAYMENT_ID}`).update({
        markedPaidAt: new Date(),
        markedByUserId: USER_A,
        updatedAt: new Date(),
      })
    );
  });

  test("non-debtor cannot mark paid", async () => {
    const db = testEnv.authenticatedContext(USER_B).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/payments/${PAYMENT_ID}`).update({
        markedPaidAt: new Date(),
        markedByUserId: USER_B,
        updatedAt: new Date(),
      })
    );
  });

  test("creditor can acknowledge", async () => {
    const db = testEnv.authenticatedContext(USER_B).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/payments/${PAYMENT_ID}`).update({
        status: "acknowledged",
        acknowledgedAt: new Date(),
        acknowledgedByUserId: USER_B,
        updatedAt: new Date(),
      })
    );
  });

  test("creditor can dispute", async () => {
    const db = testEnv.authenticatedContext(USER_B).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/payments/${PAYMENT_ID}`).update({
        status: "disputed",
        disputedAt: new Date(),
        acknowledgedByUserId: USER_B,
        updatedAt: new Date(),
      })
    );
  });

  test("nobody can create payment directly", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/payments/new_payment`).set({
        id: "new_payment",
        coupleId: COUPLE_ID,
        debtorUserId: USER_A,
        creditorUserId: USER_B,
        amount: 100,
        status: "pending",
      })
    );
  });
});

describe("RewardWeek rules - create", () => {
  test("member can create draft reward with full client payload", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W15`).set({
        id: `${COUPLE_ID}_2026-W15`,
        coupleId: COUPLE_ID,
        weekKey: "2026-W15",
        effectiveWeekStartDate: "2026-04-08",
        draftedInWeekKey: "2026-W14",
        rewardText: "吃飯",
        status: "draft",
        eligibility: { [USER_A]: true, [USER_B]: true },
        memberLocalWeekKeys: {},
        finalizeWhenBothMembersWeekClosed: true,
        earnedAt: null,
        missedAt: null,
        updatedAt: new Date(),
      })
    );
  });

  test("outsider cannot create reward", async () => {
    const db = testEnv.authenticatedContext(OUTSIDER).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W15`).set({
        id: `${COUPLE_ID}_2026-W15`,
        coupleId: COUPLE_ID,
        weekKey: "2026-W15",
        effectiveWeekStartDate: "2026-04-08",
        draftedInWeekKey: "2026-W14",
        rewardText: "Unauthorized",
        status: "draft",
        eligibility: { [USER_A]: true, [USER_B]: true },
        memberLocalWeekKeys: {},
        finalizeWhenBothMembersWeekClosed: true,
        earnedAt: null,
        missedAt: null,
        updatedAt: new Date(),
      })
    );
  });

  test("member cannot create reward with non-draft status", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W15`).set({
        id: `${COUPLE_ID}_2026-W15`,
        coupleId: COUPLE_ID,
        weekKey: "2026-W15",
        effectiveWeekStartDate: "2026-04-08",
        draftedInWeekKey: "2026-W14",
        rewardText: "Cheat",
        status: "earned",
        eligibility: { [USER_A]: true, [USER_B]: true },
        memberLocalWeekKeys: {},
        finalizeWhenBothMembersWeekClosed: true,
        updatedAt: new Date(),
      })
    );
  });

  test("member cannot create reward with mismatched coupleId", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W15`).set({
        id: `${COUPLE_ID}_2026-W15`,
        coupleId: "wrong_couple",
        weekKey: "2026-W15",
        effectiveWeekStartDate: "2026-04-08",
        draftedInWeekKey: "2026-W14",
        rewardText: "Mismatch",
        status: "draft",
        eligibility: {},
        memberLocalWeekKeys: {},
        finalizeWhenBothMembersWeekClosed: true,
        updatedAt: new Date(),
      })
    );
  });
});

describe("RewardWeek rules - lock guard", () => {
  test("member can update draft reward using only client-allowed fields", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W15`).set({
        id: "rw_draft",
        coupleId: COUPLE_ID,
        weekKey: "2026-W15",
        effectiveWeekStartDate: "2026-04-08",
        draftedInWeekKey: "2026-W14",
        rewardText: "Old text",
        status: "draft",
        eligibility: { [USER_A]: true, [USER_B]: true },
        memberLocalWeekKeys: {},
        finalizeWhenBothMembersWeekClosed: true,
        updatedAt: new Date(),
      });
    });

    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W15`).update({
        rewardText: "吃飯",
        draftedInWeekKey: "2026-W14",
        effectiveWeekStartDate: "2026-04-08",
        updatedAt: new Date(),
      })
    );
  });

  test("cannot update non-draft reward", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W14`).set({
        id: "rw_1",
        coupleId: COUPLE_ID,
        weekKey: "2026-W14",
        status: "active",
        rewardText: "Dinner",
        updatedAt: new Date(),
      });
    });

    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/rewardWeeks/2026-W14`).update({
        rewardText: "Hijacked",
        updatedAt: new Date(),
      })
    );
  });
});

describe("ReadModels - server only", () => {
  test("member can read readModels", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`couples/${COUPLE_ID}/readModels/paymentNetSummary`).set({
        id: "paymentNetSummary",
        pendingCount: 1,
      });
    });

    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertSucceeds(
      db.doc(`couples/${COUPLE_ID}/readModels/paymentNetSummary`).get()
    );
  });

  test("member cannot write readModels", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`couples/${COUPLE_ID}/readModels/paymentNetSummary`).set({
        id: "paymentNetSummary",
        pendingCount: 0,
      })
    );
  });
});

describe("_jobDedupe - server only", () => {
  test("nobody can read jobDedupe", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(db.doc(`_jobDedupe/some_key`).get());
  });

  test("nobody can write jobDedupe", async () => {
    const db = testEnv.authenticatedContext(USER_A).firestore();
    await assertFails(
      db.doc(`_jobDedupe/some_key`).set({ key: "some_key" })
    );
  });
});
